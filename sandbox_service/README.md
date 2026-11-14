# Link Scanner Isolated Chromium Sandbox

This folder contains an **optional remote dynamic-analysis worker** for Link Scanner V6. The Android app sends a scanned URL only to the HTTPS endpoint explicitly configured by the user. The target is opened in a new Chromium process and fresh, short-lived browser context on a dedicated server—not on the Android phone.

## Security boundary and deployment status

This is a **bounded analysis worker, not a certified malware detonation environment**. Playwright's own Docker documentation cautions that its standard browser images are intended for testing/development and are not recommended as a standalone way to visit untrusted sites. Use this package only on a dedicated, disposable Linux VM with no personal files, credentials, cloud metadata access, internal routes, or production secrets. For production threat research, place each job behind a stronger VM/micro-VM boundary and a separately enforced egress firewall. A browser sandbox does not guarantee protection from browser or kernel zero-days.

The container runs as the non-root `pwuser`; Chromium's own sandbox is explicitly enabled (`chromium_sandbox=True`). The host Docker seccomp profile must permit the user-namespace `clone`, `setns`, and `unshare` calls required by Chromium while retaining the rest of Docker's default restrictions. Do **not** use `--no-sandbox`, run the browser as root, or replace seccomp with `unconfined`. Follow the official Playwright Docker guidance when merging the user-namespace rule into the host's default profile: https://playwright.dev/docs/docker.

The host egress firewall is mandatory. Application DNS checks are defense-in-depth only and cannot alone eliminate a DNS-rebinding time-of-check/time-of-use race.

## What it does

- Executes page JavaScript in a fresh browser context with no imported cookies, credentials, login state, local storage, or device permissions.
- Observes the final URL, main-frame navigations, HTTP status, rendered title, password forms, hidden external iframes, challenge markers, and selected runtime DOM/script indicators.
- Blocks non-HTTP(S) targets, hostnames resolving to non-public/reserved IPs, non-GET/HEAD methods, downloads, service workers, WebSockets, and resource types outside document/script/stylesheet/XHR/fetch.
- Installs a page-init guard against form submission. The network guard independently blocks non-GET/HEAD methods.
- Uses bounded navigation/session timeouts, request count, main-frame navigation count, observation window, response fields, a 4 KB API request-body limit, a 100-entry blocked-request log, and a bounded report size.
- Limits the API key to bearer authentication, 12 requests/minute total for the deployment key, and two concurrent browser sessions. The global key limit avoids accidentally counting every caller as the same reverse-proxy IP; new sessions are rejected immediately when both slots are occupied rather than being queued.
- The host egress helper blocks private/reserved IPv4 and IPv6 ranges, including the well-known NAT64 prefix and 6to4 ranges; this remains defense in depth, not a substitute for an isolated host network policy.

## Important limitations

- This does not guarantee detection of every cloaking method, CAPTCHA-gated threat, browser exploit, malicious download, or zero-day. It does not click buttons, solve CAPTCHA, type credentials, submit forms, or run downloaded files.
- Images, fonts, media, WebSockets, service workers, and non-read HTTP methods are blocked. Some pages therefore render incompletely; a blocked resource is not a safety verdict.
- JavaScript executes inside the remote browser. The analyzer inspects a bounded DOM snapshot and selected inline script text; it does not perform full source decompilation or memory forensics.
- Host firewall rules must be installed and re-applied whenever the container is recreated. Disable IPv6 on the Docker network/host or apply equivalent IPv6 egress policy. Do not expose the API directly to the public internet without TLS and authentication.
- The API receives the full URL, including its query string. Do not submit private, one-time, signed, password-reset, or session-bearing URLs. The Flutter app asks for separate consent before enabling this remote analysis.

## Deploy on a dedicated Linux VM

1. Install Docker Engine and Docker Compose on a disposable VM, and configure the host's default Docker seccomp profile to allow Chromium user namespaces as described above. Keep the default deny rules; never use `seccomp=unconfined`.
2. Install Caddy or another reverse proxy with a valid HTTPS certificate.
3. Configure a long random API key:

   ```bash
   cp .env.example .env
   python3 -c 'import secrets; print(secrets.token_urlsafe(48))'
   ```

   Place the generated value after `LINK_SCANNER_API_KEY=` in `.env`. Protect `.env` (`chmod 600 .env`) and never commit it.
4. Fetch the official, version-matched Docker seccomp profile and then build/start:

   ```bash
   ./deploy/fetch-seccomp-profile.sh
   docker compose up -d --build
   ```

   The profile must retain Docker's default restrictions and allow only the Chromium user-namespace calls documented by Playwright. If the fetch/validation step fails, do not replace it with `seccomp=unconfined`.
5. Install host-level private/reserved egress rules:

   ```bash
   sudo ./deploy/block-private-egress.sh
   ```

   Repeat this after container recreation. If Docker IPv6 is enabled, verify that equivalent IPv6 rules are active; otherwise disable IPv6 for this worker.
6. Configure the reverse proxy using `deploy/Caddyfile.example`; replace the sample domain with a domain you control. Caddy should proxy to `127.0.0.1:8787`.
7. Verify `https://YOUR_DOMAIN/health` returns `status: ok`. The endpoint is health-only; it does not prove the browser is usable. Confirm the container logs show the API ready and run a controlled benign test URL after deployment.
8. In Link Scanner > More > Advanced Scan Settings, enter `https://YOUR_DOMAIN/v1/analyze`, the same API key, enable isolated Chromium, and save. The endpoint/token are saved using Android secure storage. The app asks for separate consent before sending a target URL.

The service binds to `127.0.0.1:8787` on the VM by default; only the TLS reverse proxy should be public. Rotate the API key if exposed.

## API

`POST /v1/analyze` with `Authorization: Bearer <LINK_SCANNER_API_KEY>` and JSON body `{"url":"https://example.org"}`. The response schema is versioned (`schema_version: "1"`). `/health` reports API process health only and requires no key.

## Tests

```bash
python -m pip install -r requirements-dev.txt
pytest -q
```

The Python unit tests validate API-key configuration, request-body bounds, session-slot limits, URL policy, reserved-address rejection, request-method/resource filtering, main-frame navigation filtering, bounded diagnostics, and selected findings. CI runs these tests alongside Flutter checks. They do not prove the Docker image starts, Chromium sandbox activates on a particular host, or all host firewall rules are correct.
