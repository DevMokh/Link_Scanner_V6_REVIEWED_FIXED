# UI redesign round 2 — 14 November 2026

## Scope

This pass changes the app's information architecture and placement, not just its palette. Existing scan engines, persistence, settings, navigation destinations, tools, and result actions are retained.

## What changed

- `lib/screens/home_dashboard.dart`: rebuilt the home screen as a security command center. The primary URL scan action is now first, followed by real on-device scan statistics, a two-column scan-tool grid, learning shortcuts, recent scans, threat-source freshness notice, and the daily safety tip.
- `lib/screens/home_shell.dart`: replaced the full-width stock navigation bar with a compact floating five-destination bar. The same five tabs remain at the same indices.
- `lib/screens/url_scan_screen.dart`: redesigned the URL input panel with clearer hierarchy, an explicit URL field, a single dominant scan action, separate paste and QR actions, and an on-device analysis note. Existing result, URL breakdown, advanced scan, findings, copy, share, and retry flows remain in place.
- `lib/screens/more_screen.dart`: reorganized secondary tools into grouped two-column grids (additional scans, learning, password/link tools) and a separate settings row. All original destinations remain connected to their existing actions.
- `lib/widgets/app_header.dart`: unified the top-level tool headers as compact bordered cards.
- `lib/core/theme.dart` and `lib/widgets/common.dart`: changed shared panels from glossy gradients to flatter surfaces with consistent borders and softened shadows, keeping the public widget APIs intact.

## Preservation checks

- Compared the current project file set with `Link_Scanner_REDESIGNED_COMPLETE.zip`: no original file was removed. `REPAIR_REPORT.md` is an additional report file.
- Compared class and function declarations in the redesigned files with the source archive: no previous function or class declaration was removed.
- Existing navigation indices remain: Home 0, URL 1, Message 2, History 3, More 4.
- URL scan flow still includes local analysis, paste, QR scan, report copy/share, URL breakdown, advanced online analysis, redirect chain, intelligence sources, findings, and scan-again actions.
- Secondary tools remain connected: sender scan, batch scan, OCR/image scan, QR, training, lessons, password strength, password generation, link cleaning, hash, and settings.
- `pubspec.yaml` dependencies and app version were not changed in this redesign pass.

## Validation

- YAML parsing passed for `pubspec.yaml`, `.github/workflows/main.yml`, and `analysis_options.yaml`.
- `bash -n tool/verify_apk.sh` passed.
- `python -m py_compile tool/gen_psl.py` passed.
- Flutter and Dart SDKs are not installed in the editing environment. Therefore `dart format`, `flutter analyze`, `flutter test`, and APK compilation were not run here. The GitHub Actions workflow remains the required compile/analyze/test gate after upload.


## متابعة إصلاح اختبار AppHeader

- سبب فشل `AppHeader` مع `Drawer` كان عدم توافق محدد الاختبار مع أيقونة زر القائمة بعد إعادة التصميم: الاختبار يبحث عن `Icons.menu_rounded` بينما الواجهة تعرض `Icons.tune_rounded`.
- تم إعادة الأيقونة إلى `Icons.menu_rounded` مع الإبقاء على شكل الزر الجديد (الخلفية، الحواف، المقاس، والتنسيق) وعلى callback فتح القائمة كما هو.
- لم يتم تعطيل الاختبار أو حذفه، ولم تتغير أي وظيفة. يجب إعادة تشغيل `flutter test` في GitHub Actions لتأكيد نجاح التشغيل في البيئة الفعلية.

## Branded navigation glyph update

- Added `lib/widgets/app_menu_glyph.dart`, a local vector-painted widget built with Flutter `CustomPainter`; it uses three horizontal scan tracks and offset Indigo/Turquoise signal nodes rather than a stock Material menu/tune glyph.
- Reused the same component in `AppHeader` and the home dashboard top bar, with Arabic tooltip and button semantics.
- Preserved the existing actions (`Scaffold.openDrawer()` and the dashboard's `onMenu` callback).
- Updated `test/app_shell_widgets_test.dart` to assert the custom glyph and tap its tooltip target to verify the drawer still opens.
- Flutter SDK is unavailable in this environment, so widget tests and `flutter analyze` remain to be run by CI.
