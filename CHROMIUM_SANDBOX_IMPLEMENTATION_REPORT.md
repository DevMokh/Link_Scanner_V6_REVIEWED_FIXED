# Link Scanner V6 — Remote Chromium Sandbox Integration Report

Date: 2026-11-14

## Implemented

- Added `lib/services/dynamic_sandbox_client.dart` to call a user-configured HTTPS service, enforce a bounded JSON response, parse versioned findings, and report unavailable/partial analysis explicitly.
- Added endpoint/token/enabled/consent settings. The endpoint and bearer token are held through the app's secure-storage abstraction rather than SharedPreferences. Changing the endpoint resets the separate Chromium consent.
- Added a separate consent prompt before the full URL is sent to the user's remote analysis service. The prompt and `PRIVACY.md` disclose the full URL/query string and remote JavaScript execution.
- Connected the returned report to `AdvancedScanner`, aggregate findings, partial status, and `ScanReport`.
- Added `sandbox_service/`, a FastAPI worker that opens a fresh context and browser process, runs JavaScript only on the remote worker, does not import browser cookies/session data, and never clicks UI or submits forms.
- The worker blocks non-GET/HEAD methods, WebSockets, downloads, service workers, non-allowlisted resource types, non-public/reserved IP targets, excessive requests and excessive navigation. The worker also has bearer authentication, rate limits, concurrent-session limits, and bounded timeouts.
- Enabled Chromium's own sandbox explicitly and configured a non-root `pwuser` container. The Playwright Python package and Docker image are pinned to matching v1.65.0 versions. A helper fetches the official version-matched Docker seccomp profile with structural validation.
- Added host egress blocking script and Caddy HTTPS reverse-proxy example.
- Added Arabic deployment guide `DYNAMIC_CHROMIUM_SETUP_AR.md`, worker README, Python tests, and Flutter tests.

## Security limits (important)

This is a bounded dynamic page observer, not a certified malware-detonation lab or a guarantee against browser/kernel zero-days, CAPTCHA-gated pages, all cloaking or DNS-rebinding races. The Playwright documentation itself says its standard Docker image is intended for testing/development and is not recommended as a standalone environment for visiting untrusted sites. Therefore deploy only on a dedicated disposable VM with no secrets or private network access, preserve the default Docker seccomp restrictions, keep Chromium's own sandbox enabled, and apply host-level IPv4/IPv6 egress controls. A stronger per-job micro-VM boundary is still recommended before production use.

The target website runs JavaScript in the remote browser. Page images, fonts, media, WebSockets, service workers, and non-GET/HEAD methods are blocked; some sites will render incompletely. CAPTCHA is detected as a limitation signal, not bypassed. The system does not type credentials or submit forms.

## Verification performed in this environment

- Python syntax compilation: passed.
- Python unit tests: 6 passed.
- Shell syntax check for host egress and seccomp fetch scripts: passed.
- Original project file preservation: all 133 files from the previous V6 report-upgraded archive remain present; the current tree contains 155 files.
- Dart relative import/export/part inspection: 0 unresolved paths across `lib/` and `test/`.
- Duplicate-consent regression check: one consent persistence test remains (no duplicate test definition).
- Docker Compose YAML and security settings: parsed and checked successfully.
- Final ZIP CRC/structure check: passed.

## Not verified here

- Flutter `dart format`, `flutter analyze`, `flutter test`, or APK build: Flutter/Dart SDK is not installed in this environment.
- Docker image build, service startup, Chromium launch, user-namespace/seccomp operation, real site navigation, reverse proxy TLS, and host firewall behavior: Docker daemon/CLI is not available here. The worker is packaged but is not running yet; it must be deployed to a dedicated Linux VM and configured in the app before dynamic results can be produced.
