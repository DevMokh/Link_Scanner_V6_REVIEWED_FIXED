import os
import sys
from pathlib import Path

# The module validates the API key at import time.
os.environ.setdefault("LINK_SCANNER_API_KEY", "test-key-that-is-long-enough-for-unit-testing-123456")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.main import (
    assess_snapshot, parse_public_http_url, _ip_is_public, request_policy,
    validate_api_key, is_main_frame_navigation, _record_block, session_slots,
    MAX_BLOCKED_RECORDS, app, MAX_API_BODY_BYTES, rate_bucket,
    RequestBodyLimitMiddleware,
)


def test_rejects_non_http_and_userinfo():
    for url in ("file:///etc/passwd", "javascript:alert(1)", "https://user:pass@example.org/"):
        try:
            parse_public_http_url(url)
            assert False, f"expected reject: {url}"
        except ValueError:
            pass


def test_rejects_unusual_ports():
    try:
        parse_public_http_url("https://example.org:4444/")
        assert False
    except ValueError:
        pass


def test_private_and_reserved_ips_are_not_public():
    for value in ("127.0.0.1", "10.1.2.3", "192.168.1.1", "169.254.169.254", "::1", "fc00::1"):
        assert _ip_is_public(value) is False
    assert _ip_is_public("1.1.1.1") is True


def test_dynamic_detector_finds_external_password_form_without_submitting_it():
    findings, signals = assess_snapshot({
        "final_url": "https://landing.example/",
        "forms": [{"action": "https://collector.example/collect", "method": "post", "password_fields": 1}],
        "iframes": [], "script_text": "", "body_text": "Sign in", "title": "Sign in"
    }, "https://landing.example/")
    assert signals["password_fields"] == 1
    assert any(x["code"] == "dynamic_external_credential_form" for x in findings)


def test_dynamic_detector_reports_hidden_external_iframe_and_captcha():
    findings, signals = assess_snapshot({
        "final_url": "https://example.org/", "forms": [],
        "iframes": [{"hidden": True, "external": True}], "script_text": "",
        "body_text": "Please verify you are human", "title": "Security check"
    }, "https://example.org/")
    codes = {x["code"] for x in findings}
    assert "dynamic_hidden_external_iframe" in codes
    assert "dynamic_anti_automation_challenge" in codes
    assert signals["challenge_detected"] is True


def test_request_policy_blocks_form_posts_and_active_resources():
    assert request_policy("GET", "document")[0] is True
    assert request_policy("GET", "script")[0] is True
    assert request_policy("POST", "fetch")[0] is False
    assert request_policy("DELETE", "xhr")[0] is False
    assert request_policy("GET", "image")[0] is False
    assert request_policy("GET", "websocket")[0] is False



def test_rejects_common_api_key_placeholders():
    for value in (
        "",
        "short",
        "REPLACE_WITH_AT_LEAST_48_RANDOM_BYTES",
        "change_me_but_make_this_string_long_enough_123456",
        "YOUR_API_KEY_012345678901234567890123456789",
    ):
        try:
            validate_api_key(value)
            assert False, f"expected reject: {value!r}"
        except RuntimeError:
            pass


def test_accepts_long_non_template_api_key():
    key = "a" * 48
    assert validate_api_key(f"  {key}  ") == key


def test_only_main_frame_navigation_is_added_to_redirect_chain():
    class FakeRequest:
        def __init__(self, frame, is_navigation=True):
            self.frame = frame
            self._is_navigation = is_navigation

        def is_navigation_request(self):
            return self._is_navigation

    main = object()
    iframe = object()
    assert is_main_frame_navigation(FakeRequest(main), main) is True
    assert is_main_frame_navigation(FakeRequest(iframe), main) is False
    assert is_main_frame_navigation(FakeRequest(main, False), main) is False


def test_blocked_request_diagnostics_are_bounded():
    state = {"blocked": []}
    for i in range(MAX_BLOCKED_RECORDS + 25):
        _record_block(state, f"reason-{i}", "document")
    assert len(state["blocked"]) == MAX_BLOCKED_RECORDS


def test_browser_session_slots_reject_excess_concurrent_work():
    acquired = 0
    try:
        while session_slots.acquire(blocking=False):
            acquired += 1
        assert acquired == 2
        assert session_slots.acquire(blocking=False) is False
    finally:
        for _ in range(acquired):
            session_slots.release()



def test_dynamic_detector_flags_https_password_form_submitted_to_http_on_same_host():
    findings, signals = assess_snapshot({
        "final_url": "https://login.example.org/",
        "forms": [{"action": "http://login.example.org/submit", "method": "post", "password_fields": 1}],
        "iframes": [], "script_text": "", "body_text": "Sign in", "title": "Sign in"
    }, "https://login.example.org/")
    codes = {item["code"] for item in findings}
    assert "dynamic_external_credential_form" in codes
    assert "dynamic_insecure_credential_form" in codes
    assert signals["external_password_forms"] == 1



def test_api_rejects_oversized_request_body_before_url_validation():
    from fastapi.testclient import TestClient

    client = TestClient(app)
    response = client.post(
        "/v1/analyze",
        headers={"Authorization": f"Bearer {os.environ['LINK_SCANNER_API_KEY']}"},
        json={"url": "https://example.org/" + ("a" * MAX_API_BODY_BYTES)},
    )
    assert response.status_code == 413
    assert response.json()["detail"] == "Request body too large"



def test_api_body_middleware_replays_small_json_body():
    from fastapi.testclient import TestClient

    client = TestClient(app)
    response = client.post(
        "/v1/analyze",
        headers={"Authorization": "Bearer invalid-token"},
        json={"url": "https://example.org/"},
    )
    assert response.status_code == 401



def test_api_schema_is_not_exposed():
    from fastapi.testclient import TestClient

    response = TestClient(app).get("/openapi.json")
    assert response.status_code == 404



def test_api_rate_limit_is_shared_per_deployment_key_not_proxy_ip():
    from fastapi.testclient import TestClient

    rate_bucket.clear()
    client = TestClient(app)
    headers = {"Authorization": f"Bearer {os.environ['LINK_SCANNER_API_KEY']}"}
    for _ in range(12):
        response = client.post("/v1/analyze", headers=headers, json={"url": "file:///not-allowed"})
        assert response.status_code == 400
    limited = client.post("/v1/analyze", headers=headers, json={"url": "file:///not-allowed"})
    assert limited.status_code == 429
    rate_bucket.clear()



def test_api_body_limit_also_catches_chunked_requests_without_content_length():
    import asyncio

    sent = []
    messages = [{"type": "http.request", "body": b"x" * (MAX_API_BODY_BYTES + 1), "more_body": False}]

    async def receive():
        return messages.pop(0)

    async def send(message):
        sent.append(message)

    async def run():
        middleware = RequestBodyLimitMiddleware(lambda *_: None)
        scope = {"type": "http", "method": "POST", "path": "/v1/analyze", "headers": []}
        await middleware(scope, receive, send)

    asyncio.run(run())
    start = next(item for item in sent if item["type"] == "http.response.start")
    assert start["status"] == 413
