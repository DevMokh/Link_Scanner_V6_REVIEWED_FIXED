from __future__ import annotations

import asyncio
import hmac
import ipaddress
import os
import re
import socket
import time
from threading import BoundedSemaphore
from collections import deque
from typing import Any
from urllib.parse import urlsplit

from fastapi import FastAPI, Header, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field
from starlette.responses import JSONResponse
from playwright.async_api import Browser, Error as PlaywrightError, async_playwright

APP_VERSION = "1.1.1"
MAX_URL_LENGTH = 2048
MAX_API_BODY_BYTES = 4096
MAX_REQUESTS = 60
MAX_DOCUMENT_SECONDS = 12
MAX_SESSION_SECONDS = 24
MAX_SCRIPT_TEXT = 64_000
MAX_BLOCKED_RECORDS = 100
MAX_CONCURRENT_SESSIONS = 2
ALLOWED_PORTS = {80, 443, 8080, 8443}
ALLOWED_RESOURCE_TYPES = {"document", "script", "stylesheet", "xhr", "fetch"}
CHALLENGE_RE = re.compile(
    r"captcha|verify\s+you\s+are\s+human|just\s+a\s+moment|cf-chl-|challenge-platform|"
    r"bot\s+check|automated\s+access|access\s+denied|datadome|imperva|perimeterx",
    re.I,
)

def validate_api_key(value: str) -> str:
    """Reject empty, short, and common template values before the API starts."""
    key = value.strip()
    template_prefixes = ("REPLACE_", "CHANGE_ME", "YOUR_", "SET_ME")
    if len(key) < 32 or key.upper().startswith(template_prefixes):
        raise RuntimeError(
            "LINK_SCANNER_API_KEY must be a non-placeholder random value of at least 32 characters"
        )
    return key


api_key = validate_api_key(os.environ.get("LINK_SCANNER_API_KEY", ""))

app = FastAPI(
    title="Link Scanner Isolated Chromium Sandbox",
    version=APP_VERSION,
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)
session_slots = BoundedSemaphore(MAX_CONCURRENT_SESSIONS)
# One API key is configured per deployment, so the limit is global per key.
# This avoids treating every caller as the reverse proxy's shared IP address.
rate_bucket: deque[float] = deque()


class AnalyzeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    url: str = Field(min_length=8, max_length=MAX_URL_LENGTH)


class RequestBodyLimitMiddleware:
    """Bound API body memory use, including requests without Content-Length."""

    def __init__(self, app: Any, max_bytes: int = MAX_API_BODY_BYTES) -> None:
        self.app = app
        self.max_bytes = max_bytes

    async def __call__(self, scope: dict[str, Any], receive: Any, send: Any) -> None:
        if (
            scope.get("type") != "http"
            or scope.get("method") != "POST"
            or scope.get("path") != "/v1/analyze"
        ):
            await self.app(scope, receive, send)
            return

        headers = {key.lower(): value for key, value in scope.get("headers", [])}
        content_length = headers.get(b"content-length")
        if content_length is not None:
            try:
                declared_length = int(content_length)
            except ValueError:
                response = JSONResponse({"detail": "Invalid Content-Length"}, status_code=400)
                await response(scope, receive, send)
                return
            if declared_length < 0 or declared_length > self.max_bytes:
                response = JSONResponse({"detail": "Request body too large"}, status_code=413)
                await response(scope, receive, send)
                return

        chunks = bytearray()
        while True:
            message = await receive()
            if message["type"] == "http.disconnect":
                return
            chunk = message.get("body", b"")
            if len(chunks) + len(chunk) > self.max_bytes:
                response = JSONResponse({"detail": "Request body too large"}, status_code=413)
                await response(scope, receive, send)
                return
            chunks.extend(chunk)
            if not message.get("more_body", False):
                break

        replayed = False

        async def replay_receive() -> dict[str, Any]:
            nonlocal replayed
            if not replayed:
                replayed = True
                return {"type": "http.request", "body": bytes(chunks), "more_body": False}
            return {"type": "http.disconnect"}

        await self.app(scope, replay_receive, send)


app.add_middleware(RequestBodyLimitMiddleware)


def parse_public_http_url(raw: str) -> tuple[str, str, int]:
    """Validate syntax before any network access. DNS/IP safety is checked separately."""
    value = raw.strip()
    if len(value) > MAX_URL_LENGTH:
        raise ValueError("URL exceeds the configured length limit")
    parsed = urlsplit(value)
    if parsed.scheme.lower() not in {"http", "https"}:
        raise ValueError("Only HTTP and HTTPS URLs are allowed")
    if not parsed.hostname or parsed.username or parsed.password:
        raise ValueError("URL must contain a public hostname and no embedded credentials")
    if parsed.port not in (None, *ALLOWED_PORTS):
        raise ValueError("Target port is not allowed by this scanner")
    if parsed.hostname.endswith((".localhost", ".local", ".internal", ".lan", ".home")):
        raise ValueError("Local hostnames are not allowed")
    host = parsed.hostname.rstrip(".").lower()
    port = parsed.port or (443 if parsed.scheme.lower() == "https" else 80)
    return value, host, port


def _ip_is_public(value: str) -> bool:
    try:
        ip = ipaddress.ip_address(value.split("%", 1)[0])
    except ValueError:
        return False
    return bool(ip.is_global and not ip.is_multicast and not ip.is_unspecified)


async def resolve_public_host(host: str) -> list[str]:
    """Reject a hostname if any answer is non-public (including mixed public/private DNS)."""
    try:
        literal = ipaddress.ip_address(host)
    except ValueError:
        literal = None
    if literal is not None:
        if not _ip_is_public(str(literal)):
            raise ValueError("Target resolves to a non-public IP address")
        return [str(literal)]

    loop = asyncio.get_running_loop()
    answers = await asyncio.wait_for(
        loop.getaddrinfo(host, None, type=socket.SOCK_STREAM), timeout=3.0
    )
    ips = sorted({item[4][0].split("%", 1)[0] for item in answers})
    if not ips or any(not _ip_is_public(ip) for ip in ips):
        raise ValueError("Hostname has no public IP or includes a private/reserved address")
    return ips


def assess_snapshot(snapshot: dict[str, Any], requested_url: str) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    forms = snapshot.get("forms") if isinstance(snapshot.get("forms"), list) else []
    iframes = snapshot.get("iframes") if isinstance(snapshot.get("iframes"), list) else []
    scripts = snapshot.get("script_text", "")
    body = snapshot.get("body_text", "")
    final_url = snapshot.get("final_url", requested_url)

    def add(code: str, severity: str, title: str, detail: str, points: int) -> None:
        findings.append({"code": code, "severity": severity, "title": title, "detail": detail, "points": points})

    requested = urlsplit(requested_url)
    final = urlsplit(final_url)

    def origin(parts: Any) -> tuple[str, str, int | None]:
        scheme = parts.scheme.lower()
        hostname = (parts.hostname or "").rstrip(".").lower()
        try:
            port = parts.port
        except ValueError:
            return (scheme, hostname, None)
        if port is None:
            port = 443 if scheme == "https" else 80 if scheme == "http" else None
        return (scheme, hostname, port)

    password_fields = 0
    external_password_forms = 0
    for form in forms[:20]:
        count = int(form.get("password_fields", 0) or 0)
        password_fields += max(0, min(count, 20))
        action = urlsplit(form.get("action", final_url))
        method = str(form.get("method", "get")).lower()
        if count and action.hostname and origin(action) != origin(final):
            external_password_forms += 1
            add(
                "dynamic_external_credential_form", "danger",
                "نموذج بيانات اعتماد يرسل إلى أصل مختلف",
                "رصد Chromium حقول كلمة مرور في نموذج يرسل إلى بروتوكول أو مضيف أو منفذ مختلف عن الصفحة. لم يتم إرسال النموذج.", 28,
            )
        if count and final.scheme.lower() == "https" and action.scheme.lower() == "http":
            add(
                "dynamic_insecure_credential_form", "danger",
                "نموذج يرسل كلمة المرور عبر اتصال غير مشفّر",
                "الصفحة تستخدم HTTPS لكن نموذج كلمة المرور يشير إلى HTTP. لم يتم إرسال النموذج.", 30,
            )
        if count and method not in {"get", "post"}:
            add("dynamic_unusual_form_method", "warn", "نموذج تسجيل دخول بطريقة إرسال غير معتادة", "تم رصد طريقة إرسال غير معتادة في نموذج يحتوي على حقل كلمة مرور. لم يتم إرسال النموذج.", 8)

    hidden_iframes = 0
    for frame in iframes[:30]:
        if frame.get("hidden") and frame.get("external"):
            hidden_iframes += 1
    if hidden_iframes:
        add("dynamic_hidden_external_iframe", "warn", "إطار خارجي مخفي أثناء العرض", f"رصد Chromium عدد {hidden_iframes} من الإطارات الخارجية المخفية. قد تكون لها استخدامات مشروعة؛ يلزم مراجعة الوجهة.", 10)

    js = str(scripts)[:MAX_SCRIPT_TEXT]
    if re.search(r"\b(eval|Function)\s*\(", js) and re.search(r"\b(atob|fromCharCode|TextDecoder)\b", js):
        add("dynamic_obfuscated_runtime_js", "warn", "JavaScript يجمع بين فك الترميز والتنفيذ الديناميكي", "ظهر نمط يجمع بين فك ترميز بيانات وتنفيذ JavaScript وقت التشغيل. هذا مؤشر يستحق المراجعة وليس إثباتاً منفرداً للضرر.", 9)

    challenge = bool(CHALLENGE_RE.search(f"{snapshot.get('title', '')} {body}"))
    if challenge:
        add("dynamic_anti_automation_challenge", "info", "ظهرت صفحة تحدٍّ أو مكافحة أتمتة", "قد تمنع CAPTCHA أو حماية WAF عرض المحتوى الكامل للمحلل. عدم ظهور صفحة التصيّد لا يعني أن الرابط آمن.", 2)

    if requested.hostname and final.hostname and requested.hostname.lower() != final.hostname.lower():
        add("dynamic_cross_host_navigation", "info", "تغيّر المضيف أثناء العرض الديناميكي", f"انتقل المتصفح من {requested.hostname} إلى {final.hostname}. راجع سلسلة التحويلات والسياق قبل الحكم.", 3)

    meta = snapshot.get("meta_refresh")
    if meta:
        add("dynamic_meta_refresh", "info", "تنقل تلقائي بواسطة Meta Refresh", "رصد Chromium توجيهاً تلقائياً من نوع meta refresh.", 2)

    signals = {
        "password_fields": min(password_fields, 100),
        "external_password_forms": min(external_password_forms, 20),
        "hidden_iframes": min(hidden_iframes, 100),
        "challenge_detected": challenge,
        "script_text_truncated": bool(snapshot.get("script_text_truncated")),
    }
    return findings[:30], signals


def request_policy(method: str, resource_type: str) -> tuple[bool, str]:
    if method.upper() not in {"GET", "HEAD"}:
        return False, "non_read_method"
    if resource_type not in ALLOWED_RESOURCE_TYPES:
        return False, "resource_type"
    return True, ""


def is_main_frame_navigation(request: Any, main_frame: Any) -> bool:
    """Exclude iframe documents from the user-visible main-frame redirect chain."""
    try:
        return request.is_navigation_request() and request.frame == main_frame
    except PlaywrightError:
        return False


def _record_block(state: dict[str, Any], reason: str, resource_type: str) -> None:
    """Keep diagnostics bounded even when a page creates many blocked requests."""
    blocked = state["blocked"]
    if len(blocked) < MAX_BLOCKED_RECORDS:
        blocked.append({"reason": reason[:160], "resource_type": resource_type[:32]})


async def _guarded_request(route: Any, state: dict[str, Any]) -> None:
    request = route.request
    state["request_count"] += 1
    if state["request_count"] > MAX_REQUESTS:
        _record_block(state, "request_limit", request.resource_type)
        await route.abort("blockedbyclient")
        return
    allowed, reason = request_policy(request.method, request.resource_type)
    if not allowed:
        _record_block(state, reason, request.resource_type)
        await route.abort("blockedbyclient")
        return
    try:
        _, host, _ = parse_public_http_url(request.url)
        await resolve_public_host(host)
    except Exception as exc:
        _record_block(state, str(exc), request.resource_type)
        await route.abort("blockedbyclient")
        return

    if request.resource_type == "document" and is_main_frame_navigation(
        request, state.get("main_frame")
    ):
        state["navigation_urls"].append(request.url[:MAX_URL_LENGTH])
        if len(state["navigation_urls"]) > 12:
            _record_block(state, "navigation_limit", "document")
            await route.abort("blockedbyclient")
            return
    await route.continue_()


async def _run_chromium(url: str) -> dict[str, Any]:
    started = time.monotonic()
    state: dict[str, Any] = {
        "request_count": 0,
        "blocked": [],
        "navigation_urls": [],
        "statuses": [],
        "main_frame": None,
        "websocket_count": 0,
    }
    async with async_playwright() as playwright:
        browser: Browser = await playwright.chromium.launch(
            headless=True,
            chromium_sandbox=True,
            args=[
                "--disable-background-networking", "--disable-component-update",
                "--disable-sync", "--no-first-run", "--no-default-browser-check",
                "--disable-extensions", "--disable-cache", "--disk-cache-size=1",
                "--disable-webrtc", "--disable-features=MediaRouter,OptimizationHints,WebRtcHideLocalIpsWithMdns",
            ],
        )
        try:
            context = await browser.new_context(
                java_script_enabled=True,
                accept_downloads=False,
                service_workers="block",
                ignore_https_errors=False,
                viewport={"width": 1280, "height": 800},
                device_scale_factor=1,
                locale="en-US",
                timezone_id="UTC",
            )
            # Block form submission even when page JavaScript calls form.submit()
            # directly. Network routing separately rejects all non-GET/HEAD methods.
            await context.add_init_script("""(() => {
              document.addEventListener('submit', event => event.preventDefault(), true);
              try { Object.defineProperty(HTMLFormElement.prototype, 'submit', { value: function () {}, writable: false }); } catch (_) {}
              try { Object.defineProperty(HTMLFormElement.prototype, 'requestSubmit', { value: function () {}, writable: false }); } catch (_) {}
            })();""")
            page = await context.new_page()
            state["main_frame"] = page.main_frame
            await context.route("**/*", lambda route: _guarded_request(route, state))
            async def block_websocket(route: Any) -> None:
                state["websocket_count"] += 1
                _record_block(state, "websocket_disabled", "websocket")
                await route.close(code=1008, reason="WebSockets are disabled in the analysis sandbox")
            await context.route_web_socket("**/*", block_websocket)
            page.on("popup", lambda popup: asyncio.create_task(popup.close()))
            try:
                response = await page.goto(url, wait_until="domcontentloaded", timeout=MAX_DOCUMENT_SECONDS * 1000)
                if response is not None:
                    state["statuses"].append(response.status)
            except PlaywrightError as exc:
                state["navigation_error"] = str(exc)[:240]

            # Short observation window catches immediate JS redirects and DOM-created forms.
            try:
                await page.wait_for_timeout(1800)
            except PlaywrightError:
                pass

            snapshot: dict[str, Any] = {"final_url": page.url, "title": "", "body_text": "", "forms": [], "iframes": [], "script_text": ""}
            try:
                snapshot = await page.evaluate("""() => {
                  const origin = location.origin;
                  const forms = Array.from(document.forms).slice(0, 20).map(f => ({
                    action: f.action || location.href,
                    method: (f.method || 'get').toLowerCase(),
                    password_fields: f.querySelectorAll('input[type=password]').length
                  }));
                  const iframes = Array.from(document.querySelectorAll('iframe')).slice(0, 30).map(f => {
                    const r = f.getBoundingClientRect();
                    const style = getComputedStyle(f);
                    const hidden = style.display === 'none' || style.visibility === 'hidden' || r.width < 2 || r.height < 2;
                    let external = false;
                    try { external = new URL(f.src || location.href, location.href).origin !== origin; } catch (_) {}
                    return { hidden, external };
                  });
                  const scripts = Array.from(document.scripts).slice(0, 60).map(s => s.textContent || '').join('\\n').slice(0, 64000);
                  const body = document.body ? (document.body.innerText || '').slice(0, 12000) : '';
                  const refresh = document.querySelector('meta[http-equiv="refresh" i]');
                  return { final_url: location.href, title: document.title || '', body_text: body,
                    forms, iframes, script_text: scripts, script_text_truncated: scripts.length >= 64000,
                    meta_refresh: refresh ? refresh.content : null };
                }""")
            except PlaywrightError as exc:
                snapshot["snapshot_error"] = str(exc)[:160]
            findings, signals = assess_snapshot(snapshot, url)
            chain = []
            for candidate in state["navigation_urls"] + [snapshot.get("final_url", page.url)]:
                if candidate and (not chain or chain[-1] != candidate):
                    chain.append(candidate[:MAX_URL_LENGTH])
            return {
                "schema_version": "1",
                "analysis_status": "partial" if state.get("navigation_error") or snapshot.get("snapshot_error") else "completed",
                "sandbox_version": APP_VERSION,
                "requested_url": url,
                "final_url": str(snapshot.get("final_url", page.url))[:MAX_URL_LENGTH],
                "page_title": str(snapshot.get("title", ""))[:180],
                "http_status": state["statuses"][-1] if state["statuses"] else None,
                "duration_ms": min(120000, int((time.monotonic() - started) * 1000)),
                "request_count": min(200, state["request_count"]),
                "blocked_request_count": min(200, len(state["blocked"])),
                "redirect_chain": chain[:12],
                "signals": signals,
                "findings": findings,
                "limitations": [
                    "A new ephemeral browser context was used; no cookies or login state were imported.",
                    "Only GET/HEAD requests and selected resource types were allowed; form submissions and downloads were blocked.",
                    "The page ran JavaScript inside the container sandbox. This is not a guarantee against every browser exploit or cloaking technique.",
                    "Private/reserved IP ranges are checked before each request and should also be blocked by the host firewall.",
                ],
                "error": state.get("navigation_error") or snapshot.get("snapshot_error"),
            }
        finally:
            await browser.close()


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "link-scanner-chromium-sandbox", "version": APP_VERSION}


@app.post("/v1/analyze")
async def analyze(payload: AnalyzeRequest, request: Request, authorization: str | None = Header(default=None)) -> dict[str, Any]:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Unauthorized")
    supplied = authorization[7:].strip()
    if not hmac.compare_digest(supplied, api_key):
        raise HTTPException(status_code=401, detail="Unauthorized")

    now = time.monotonic()
    while rate_bucket and now - rate_bucket[0] > 60:
        rate_bucket.popleft()
    if len(rate_bucket) >= 12:
        raise HTTPException(status_code=429, detail="Rate limit exceeded")
    rate_bucket.append(now)

    try:
        url, host, _ = parse_public_http_url(payload.url)
        await resolve_public_host(host)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Target rejected: {str(exc)[:180]}") from exc

    # Reserve a slot atomically instead of checking Semaphore.locked() and then
    # awaiting it; the old check could queue an unbounded number of requests.
    if not session_slots.acquire(blocking=False):
        raise HTTPException(status_code=429, detail="Sandbox is busy; retry later")
    try:
        return await asyncio.wait_for(_run_chromium(url), timeout=MAX_SESSION_SECONDS)
    except asyncio.TimeoutError as exc:
        raise HTTPException(status_code=504, detail="Dynamic browser analysis timed out") from exc
    except Exception as exc:
        # Do not disclose stack traces, container paths, or browser internals.
        raise HTTPException(status_code=502, detail="Isolated browser analysis failed") from exc
    finally:
        session_slots.release()
