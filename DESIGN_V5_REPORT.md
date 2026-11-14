# Link Scanner V5 — Cyber-Glass Redesign Report

## Visual identity

تم تحويل واجهة التطبيق من هوية Terminal الخضراء إلى نظام **Cyber-Glass & Precision Intelligence**:

- خلفية Midnight Navy `#070B14` وأسطح Slate `#0F172A`.
- أسطح Frosted Glass بحدود `#334155` وطبقة `BackdropFilter` للبطاقات الأساسية.
- Indigo `#6366F1` للإجراءات النشطة، Cyan `#06B6D4` وEmerald `#10B981` للحالات الآمنة/المعلوماتية، Amber للتحذير وCrimson للخطر.
- نصوص الواجهة بخط النظام، والبيانات الفنية بخط monospace.
- مكونات مشتركة: `GlassCard`, `StatusBadge`, `CyberButton`, `MonospaceText` مع الاحتفاظ بواجهات `Panel` و`PrimaryButton` القديمة للتوافق.

## الشاشات التي تم تحديثها

- `home_dashboard.dart`: شعار وهوية V5، حالة المحرك المحلي، توضيح دمج NetGuard، Quick Scan مع اللصق والمسح، اختصارات URL/QR/OCR/Batch، وإحصاءات تُحسب من سجل الجهاز فقط.
- `home_shell.dart`: شريط تنقل سفلي زجاجي مع تمييز Indigo واهتزاز خفيف عند تغيير التبويب.
- `url_scan_screen.dart`: بطاقة إدخال زجاجية، لصق، تنظيف معاملات التتبع عبر `UrlCleaner`، قراءة QR، والوصول إلى التوسيع والفحص المتقدم الحالي بعد الفحص المحلي وموافقة المستخدم.
- `risk_gauge.dart` و`scan_report.dart`: عدّاد خطر مرسوم بـ `CustomPainter` وتدرج Cyan → Amber → Crimson، مع إبقاء درجة وقرار المحلل كما هما.
- `history_screen.dart`: بحث وتصفية بحسب المستوى، ملخصات حقيقية، تصدير ومسح السجل، تفاصيل الملخص، وإعادة فحص الدومين المحفوظ للروابط.
- `more_screen.dart` و`app_header.dart`: بطاقات زجاجية وترويسات موحدة.
- `intel_tiles.dart` و`intel_settings.dart`: عرض حالات مصادر الاستخبارات مع توضيح حماية NetGuard لطلبات التحويلات.
- `app_info_panel.dart`: إصدار التطبيق وإفصاح خصوصية داخل التطبيق وفق `PRIVACY.md`.

## سلامة البيانات والوظائف

- لم يتم تعديل ملفات الخدمات أو قواعد التحليل أو نماذج البيانات أو تخزين الإعدادات.
- بقيت الخدمات الحالية، ومنها `url_analyzer.dart`, `advanced_scanner.dart`, `batch_scanner.dart`, `net_guard.dart`, `ocr_service.dart`, `qr_analyzer.dart`, `message_analyzer.dart`, `link_expander.dart`, `url_confusables.dart`, `online_intel.dart`, `history_store.dart`, و`settings_store.dart` كما هي.
- لم تتم إضافة نتائج تجريبية أو قاعدة تهديدات وهمية. أرقام لوحة التحكم مشتقة من `HistoryStore`.
- سجل الرسائل ما زال يحفظ ملخصًا فقط ولا يخزن محتوى الرسالة. لذلك لا يعرض سجل الرسائل زر إعادة فحص؛ أما الروابط فيُعاد فحص اسم المضيف المحفوظ فقط، وليس المسار الأصلي الذي لا يخزنه السجل.
- لم يتم تغيير رقم إصدار التطبيق أو معرّفات الحزمة أو مفاتيح التخزين.

## التحقق

- تم التحقق من سلامة أرشيف ZIP الأصلي قبل التعديل.
- تم إجراء فحص اتزان الأقواس/الأقواس المعقوفة على الملفات المعدّلة وفحص مسارات الاستيراد النسبية.
- لم تتغير ملفات `lib/services/` أو `pubspec.yaml`.
- **لم يتم تشغيل** `dart format` أو `flutter analyze` أو `flutter test` أو بناء APK؛ لا يتوفر Flutter/Dart SDK في بيئة التنفيذ الحالية. يلزم تشغيل هذه الأوامر في بيئة Flutter قبل اعتماد APK نهائي.
