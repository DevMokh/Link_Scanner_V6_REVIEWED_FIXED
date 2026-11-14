# Link Scanner V6 — Scan Report UI Update

## What changed

- Replaced the completed advanced-scan detail block in the URL result screen with an expandable intelligence dossier.
- Added distinct sections for redirect timeline, static HTML/JavaScript inspection, DNS/TLS/ASN, local campaign correlation, reputation providers, and consolidated findings.
- Technical values (URLs, hostnames, IP addresses, ASN, prefixes, certificate identities and dates) use selectable monospace/LTR presentation.
- Every section is populated from the existing `AdvancedReport`, `PageBehaviorReport`, `NetworkIntelligenceReport`, `IntelResult`, and `Finding` objects. No demonstration scan results or hardcoded threat intelligence have been added.
- Partial or unavailable checks are explicitly labeled; the report warns that missing data is not evidence of safety.
- The consolidated findings section receives the original local `ScanResult` so the report includes local and advanced findings together.

## Current report limitations

- The app still performs static HTML/JavaScript inspection; it does not execute JavaScript or run a full isolated Chromium browser.
- User-Agent response differences are a variance signal, not proof of cloaking.
- DNS/TLS/ASN and reputation results depend on network reachability and configured provider keys.
- The current UI does not claim a full browser-behavior verdict or guarantee detection of every dynamic phishing flow.

## Validation

- The original project source and services were retained.
- Static archive and import checks are performed during packaging.
- `dart format`, `flutter analyze`, `flutter test`, and APK build remain unverified because the Flutter/Dart SDK is unavailable in this environment.
