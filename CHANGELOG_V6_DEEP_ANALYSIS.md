# V6 Deep Analysis Engine — Change Log

- Added bounded, static HTML and JavaScript inspection, including up to three external HTTPS scripts.
- Added browser-vs-scanner User-Agent response comparison and anti-automation challenge indicators.
- Added detection for credential forms posting cross-origin, hidden external iframes, external meta refresh, suspicious JavaScript decoding/execution combinations, and browser-fingerprinting signals.
- Added DNS, ASN/Prefix/RIPEstat, and pinned TLS certificate inspection behind NetGuard.
- Added redirect-chain context analysis and local campaign correlation over recent high-risk scan history.
- Expanded Unicode script classification for additional IDN warning context.
- Preserved the existing local URL engine, scoring model, Google Safe Browsing, VirusTotal, and RDAP. Updated the consent dialog and `PRIVACY.md` to disclose the new page, script, DNS, and RIPEstat requests.
- No JavaScript execution, form submission, cookie reuse, or browser session simulation is performed. The user-agent comparison is only an HTTP header comparison, not a real browser run.
- Flutter analysis, tests, and APK build remain pending because the Flutter/Dart SDK is unavailable in the editing environment.
