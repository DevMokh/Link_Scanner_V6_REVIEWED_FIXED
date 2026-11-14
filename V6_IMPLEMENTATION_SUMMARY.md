# Link Scanner V5 — V6 Advanced Analysis Implementation

## Delivered in this source package

- **Redirect path:** retains the existing guarded redirect expansion (up to 8 hops, with GET fallback where HEAD is rejected) and adds context findings for HTTPS downgrade, multiple registered domains, origin changes, and many redirect hosts.
- **Static page / JavaScript inspection:** reads bounded HTML (up to 512 KiB) and at most three external HTTPS scripts (up to 128 KiB each). It checks cross-host credential forms, hidden external iframes, external meta refresh, suspicious decode-plus-dynamic-execution combinations, dynamic navigation, and browser-fingerprinting indicators.
- **Anti-automation / cloaking signals:** compares a page response requested with an Android-browser-like User-Agent against a scanner User-Agent; status, content type, size, and challenge markers are compared. Differences are informational, not proof of malicious cloaking.
- **Network intelligence:** checks DNS answers and rejects the whole set if any address is private/reserved; inspects TLS certificate subject, issuer and validity over a socket connected to the checked IP; queries RIPEstat for ASN, prefix, network holder and country.
- **Campaign correlation:** locally correlates the current host with high-risk URL hosts from the device's scan history over the previous 45 days. Nothing from history is uploaded.
- **IDN / homograph context:** adds script classification for Arabic, Hebrew, Devanagari, Han, Hiragana, Katakana and Hangul while preserving higher risk for confusable Latin/Greek/Cyrillic/Armenian mixing. Other script mixing is a low-weight context signal.
- **Multi-source reputation:** preserves the existing local engine, RDAP, optional Google Safe Browsing and optional VirusTotal; RIPEstat adds network-registration context, not a threat verdict.
- **Privacy disclosure:** updates the advanced-scan consent dialog and `PRIVACY.md` to disclose HTML/script retrieval, User-Agent comparison, DNS/TLS and RIPEstat IP lookups.

## Important technical boundaries

This build does **not** run JavaScript, submit forms, reuse cookies, access authenticated browser sessions, or run a real Chromium/headless browser. The User-Agent comparison is two bounded HTTP requests, not a browser simulation. Therefore it cannot reliably expose every location-, time-, cookie-, session-, or JavaScript-runtime-dependent cloaking decision. IDN confusable coverage remains a curated subset rather than the full Unicode confusables database. Campaign correlation is local history correlation, not global threat-actor attribution.

## Preservation

All original files from the V5 Deep Analysis source ZIP remain in the project. New service and test files were added; existing URL-analysis weights and the existing reputation providers were retained. OpenPhish was not reintroduced.

## Validation status

- Source ZIP integrity was checked before editing.
- Original archive inventory comparison: no original file missing.
- Relative Dart import resolution: passed.
- Dart delimiter/string structural scan: passed.
- `pubspec.yaml` parsing: passed.
- `dart format`, `flutter analyze`, `flutter test`, and Android APK build: **not run** because the Flutter/Dart SDK is unavailable in this environment. The added tests are included but not yet confirmed passing.


## Scan Report UI enhancement (2026-11-14)

The URL scan report now presents the advanced analysis as an expandable dossier: redirect timeline, static HTML/JavaScript findings, DNS/TLS/ASN, local campaign correlation, reputation provider status, and consolidated findings. The sections bind to the existing `AdvancedReport` and related result objects; no mock results were introduced. Partial checks and unavailable sources are explicitly disclosed. See `V6_REPORT_UI_UPDATE.md`.

The UI enhancement is source-reviewed but not runtime-verified: Flutter/Dart SDK is unavailable, so formatting, analyzer, widget tests, full tests, and APK build have not been run.
