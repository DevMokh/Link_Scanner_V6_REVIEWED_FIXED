import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../services/history_store.dart';
import '../services/inbox.dart';
import '../services/settings_store.dart';
import '../widgets/brand_logo.dart';
import '../widgets/common.dart';
import '../widgets/stats_card.dart';

const List<String> _tips = <String>[
  'لو رسالة بتهدّدك بإيقاف حسابك خلال ساعات، دي علامة نصب كلاسيكية. البنوك الحقيقية مش بتستعجلك كده.',
  'محدش رسمي (بنك، محفظة، شركة اتصالات) هيطلب منك كود التحقق أو الـ CVV في مكالمة أو رسالة. اقفل الخط.',
  'اقرأ اسم الدومين من اليمين لليسار قبل الـ.com أو .eg. الجزء الأهم هو أقرب حاجة لنوع الامتداد.',
  'لو حد قالك "رقمي اتغير" وطلب فلوس، اتصل بالرقم القديم أو اسأله سؤال يعرفه هو بس قبل ما تحول.',
  'رمز QR ممكن يتلصق فوق رمز حقيقي في محل أو عداد ركن. راجع اسم الموقع بعد ما تفحصه قبل الدفع.',
  'لا تثبت تطبيق تحكم عن بعد بناءً على طلب حد اتصل بيك وقال إنه دعم فني.',
  'وظيفة بتطلب فلوس تسجيل مقدمًا هي نصب في الأغلب، مهما كان المرتب المعروض مغري.',
  'لو الرسالة فيها رابط ومعاه استعجال أو تهديد، افتراض إنه نصب أأمن ليك من فتحه.',
  'غيّر كلمة السر فورًا لو ضغطت على رابط مشبوه وكتبت بياناتك، وفعّل التحقق بخطوتين لو متاح.',
  'الجهات الحكومية (تموين، تأمينات، كهرباء) مش بترسل روابط دفع أو تهديد بقطع خدمة برسالة SMS.',
];

String _t(String ar, String en) => SettingsStore.instance.english ? en : ar;

String _tipOfDay() {
  final day = DateTime.now().difference(DateTime(2026, 1, 1)).inDays;
  return _tips[day % _tips.length];
}

int countThreats(List<HistoryItem> items) {
  var n = 0;
  for (final it in items) {
    if (it.level == RiskLevel.high || it.level == RiskLevel.critical) n++;
  }
  return n;
}

int countUrlScans(List<HistoryItem> items) {
  var n = 0;
  for (final it in items) {
    if (it.kind == ScanKind.url) n++;
  }
  return n;
}

int countSafeScans(List<HistoryItem> items) {
  var n = 0;
  for (final it in items) {
    if (it.level == RiskLevel.low) n++;
  }
  return n;
}

String agoText(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return _t('الآن', 'just now');
  if (d.inMinutes < 60) return _t('منذ ${d.inMinutes} دقيقة', '${d.inMinutes} min ago');
  if (d.inHours < 24) return _t('منذ ${d.inHours} ساعة', '${d.inHours} h ago');
  return _t('منذ ${d.inDays} يوم', '${d.inDays} d ago');
}

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({
    super.key,
    required this.onTab,
    required this.onQr,
    required this.onImage,
    required this.onSender,
    required this.onBatch,
    required this.onTrain,
    required this.onLearn,
    required this.onSettings,
    required this.onMenu,
  });

  final void Function(int tabIndex) onTab;
  final VoidCallback onQr;
  final VoidCallback onImage;
  final VoidCallback onSender;
  final VoidCallback onBatch;
  final VoidCallback onTrain;
  final VoidCallback onLearn;
  final VoidCallback onSettings;
  final VoidCallback onMenu;

  Widget _topBar(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, top + 10, 18, 16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: alpha(C.accentPrimary, 0.12),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: alpha(C.accentPrimary, 0.35)),
              boxShadow: glow(C.accentPrimary, opacity: 0.13, blur: 18),
            ),
            child: const Center(child: LinkScannerLogo(size: 31, glowing: false)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Link Scanner V5',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: C.textPrimary, fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  _t('ذكاء أمني دقيق • حماية الروابط', 'PRECISION INTELLIGENCE • LINK PROTECTION'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: C.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _HeaderAction(icon: Icons.grid_view_rounded, tooltip: _t('القائمة', 'Menu'), onTap: onMenu),
          const SizedBox(width: 7),
          _HeaderAction(icon: Icons.settings_outlined, tooltip: _t('الإعدادات', 'Settings'), onTap: onSettings),
        ],
      ),
    );
  }

  Widget _shieldCard(String detail, int total) {
    return GlassCard(
      padding: const EdgeInsets.all(17),
      radius: 24,
      borderColor: alpha(C.statusCyan, 0.30),
      glowColor: C.accentPrimary,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[alpha(C.accentPrimary, 0.13), alpha(C.statusCyan, 0.045), alpha(C.surfaceGlass, 0.3)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'SYSTEM SHIELD STATUS',
                  style: TextStyle(color: C.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.1),
                ),
              ),
              const StatusBadge(label: 'LOCAL ENGINE READY', color: C.statusSafe),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: alpha(C.statusSafe, 0.10),
                  border: Border.all(color: alpha(C.statusSafe, 0.34), width: 1.2),
                  boxShadow: glow(C.statusSafe, opacity: 0.16, blur: 24),
                ),
                child: const Center(child: Icon(Icons.shield_rounded, color: C.statusSafe, size: 48)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('الحماية جاهزة', 'PROTECTION READY'),
                      style: const TextStyle(color: C.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: C.textSecondary, fontSize: 10.5, height: 1.45),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.verified_user_outlined, color: C.statusCyan, size: 14),
                        const SizedBox(width: 6),
                        Expanded(child: Text(_t('NetGuard مدمج بطبقة الاتصال', 'NetGuard protects outbound probes'), style: const TextStyle(color: C.statusCyan, fontSize: 9.5, fontWeight: FontWeight.w700))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Divider(color: alpha(C.borderGlass, 0.65), height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.history_rounded, color: C.textSecondary, size: 15),
              const SizedBox(width: 6),
              Expanded(child: Text(_t('عمليات محفوظة على هذا الجهاز', 'ON-DEVICE SCAN HISTORY'), style: const TextStyle(color: C.textSecondary, fontSize: 9))),
              MonospaceText('$total', color: C.textPrimary, fontSize: 12, fontWeight: FontWeight.w800),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label, Color color, String code) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        radius: 17,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: color, size: 17), const Spacer(), Text(code, style: const TextStyle(color: C.textSecondary, fontFamily: 'monospace', fontSize: 7.5, fontWeight: FontWeight.w700))]),
            const SizedBox(height: 9),
            MonospaceText(value, color: color, fontSize: 21, fontWeight: FontWeight.w900),
            const SizedBox(height: 3),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.textSecondary, fontSize: 8.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _toolTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color tint = C.accentPrimary,
    bool featured = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.all(12),
          radius: 17,
          borderColor: featured ? alpha(tint, 0.42) : alpha(C.borderGlass, 0.72),
          glowColor: featured ? tint : null,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: alpha(tint, 0.13),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: alpha(tint, 0.27)),
                ),
                child: Icon(icon, color: tint, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.textSecondary, fontSize: 9.2, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.chevron_right_rounded, color: alpha(tint, 0.9), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recent(HistoryItem item) {
    final color = levelColor(item.level);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        radius: 15,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: alpha(color, 0.12), shape: BoxShape.circle, border: Border.all(color: alpha(color, 0.28))),
              child: Center(child: Icon(item.kind == ScanKind.url ? Icons.link_rounded : Icons.message_outlined, color: color, size: 18)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Directionality(
                    textDirection: item.kind == ScanKind.url ? TextDirection.ltr : TextDirection.rtl,
                    child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 4),
                  Text('${item.level.label} • ${agoText(item.time)}', style: TextStyle(color: color, fontSize: 9.2, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(label: '${item.score}%', color: color, dot: false),
          ],
        ),
      ),
    );
  }

  Widget _tipCard() {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      radius: 18,
      borderColor: alpha(C.statusCyan, 0.25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: alpha(C.statusCyan, 0.12), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.lightbulb_outline_rounded, color: C.statusCyan, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('معلومة أمنية', 'SECURITY INSIGHT'), style: const TextStyle(color: C.statusCyan, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.55)),
                const SizedBox(height: 6),
                Text(_tipOfDay(), style: const TextStyle(color: C.textPrimary, fontSize: 11.5, height: 1.55)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HistoryStore.instance,
      builder: (context, _) {
        final items = HistoryStore.instance.items;
        final detail = items.isEmpty
            ? _t('محرك التحليل المحلي جاهز. ابدأ بفحص رابط أو رسالة قبل فتحها.', 'Local analysis is ready. Inspect a link or message before opening it.')
            : '${_t('آخر فحص', 'LAST SCAN')}: ${agoText(items.first.time)}';
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _topBar(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _shieldCard(detail, items.length),
                  const SizedBox(height: 16),
                  SectionTitle(_t('فحص سريع', 'QUICK SCAN')),
                  QuickScanOmnibox(
                    onAnalyze: (url) {
                      Inbox.toUrl.value = Incoming(url);
                      onTab(1);
                    },
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.90,
                    children: [
                      _QuickNode(icon: Icons.link_rounded, label: _t('رابط', 'URL'), tint: C.accentPrimary, onTap: () => onTab(1)),
                      _QuickNode(icon: Icons.qr_code_2_rounded, label: 'QR', tint: C.statusCyan, onTap: onQr),
                      _QuickNode(icon: Icons.document_scanner_outlined, label: _t('صورة / OCR', 'OCR IMAGE'), tint: C.statusWarning, onTap: onImage),
                      _QuickNode(icon: Icons.playlist_add_check_rounded, label: _t('مجمّع', 'BATCH'), tint: C.statusSafe, onTap: onBatch),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SectionTitle(_t('مؤشرات السجل', 'HISTORY TELEMETRY')),
                  Row(
                    children: [
                      _stat(Icons.shield_outlined, '${countSafeScans(items)}', _t('دون مؤشرات', 'NO FLAGS'), C.statusSafe, 'SAFE'),
                      const SizedBox(width: 8),
                      _stat(Icons.link_rounded, '${countUrlScans(items)}', _t('روابط', 'URL SCANS'), C.statusCyan, 'URL'),
                      const SizedBox(width: 8),
                      _stat(Icons.warning_amber_rounded, '${countThreats(items)}', _t('تهديدات', 'THREATS'), C.statusDanger, 'RISK'),
                      const SizedBox(width: 8),
                      _stat(Icons.manage_search_rounded, '${items.length}', _t('الإجمالي', 'TOTAL'), C.accentPrimary, 'ALL'),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _t('الأرقام مستمدة من سجل الفحوصات المحفوظ على جهازك، وليست إحصاءات عامة.', 'Metrics come from your on-device scan history, not global threat statistics.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: C.textSecondary, fontSize: 9.2),
                  ),
                  const SizedBox(height: 16),
                  SectionTitle(_t('وحدات التحليل', 'ANALYSIS MODULES')),
                  Text(_t('كل أدوات الفحص الأساسية في مكان واحد.', 'Core inspection modules in one place.'), style: const TextStyle(color: C.textSecondary, fontSize: 10.5)),
                  const SizedBox(height: 9),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 9,
                    crossAxisSpacing: 9,
                    childAspectRatio: 1.62,
                    children: [
                      _toolTile(icon: Icons.link_rounded, title: _t('فحص رابط', 'URL ANALYZER'), subtitle: _t('تحليل عنوان الموقع ومؤشرات الخطر', 'URL structure and risk indicators'), onTap: () => onTab(1), tint: C.accentPrimary, featured: true),
                      _toolTile(icon: Icons.mark_email_unread_rounded, title: _t('فحص رسالة', 'MESSAGE SCAN'), subtitle: _t('استخراج الروابط وإشارات الاحتيال', 'Extract links and scam indicators'), onTap: () => onTab(2), tint: C.statusCyan),
                      _toolTile(icon: Icons.qr_code_scanner_rounded, title: _t('فحص QR', 'QR INSPECTOR'), subtitle: _t('قراءة الرمز وفحص محتواه', 'Read and inspect the payload'), onTap: onQr, tint: C.statusSafe),
                      _toolTile(icon: Icons.image_search_rounded, title: _t('فحص صورة', 'IMAGE ANALYSIS'), subtitle: _t('استخراج النصوص والروابط', 'Extract text and URLs'), onTap: onImage, tint: C.statusWarning),
                      _toolTile(icon: Icons.alternate_email_rounded, title: _t('فحص المرسل', 'SENDER CHECK'), subtitle: _t('تحليل بيانات المرسل', 'Inspect sender details'), onTap: onSender, tint: C.orange),
                      _toolTile(icon: Icons.playlist_add_check_rounded, title: _t('فحص مجمّع', 'BATCH SCAN'), subtitle: _t('فحص عدة روابط دفعة واحدة', 'Inspect multiple URLs together'), onTap: onBatch, tint: C.statusCyan),
                    ],
                  ),
                  const SizedBox(height: 17),
                  SectionTitle(_t('التدريب والمعرفة', 'TRAINING & KNOWLEDGE')),
                  Row(
                    children: [
                      Expanded(child: _toolTile(icon: Icons.school_outlined, title: _t('معمل التدريب', 'TRAINING LAB'), subtitle: _t('تحديات كشف التصيّد', 'Phishing detection drills'), onTap: onTrain, tint: C.statusCyan)),
                      const SizedBox(width: 9),
                      Expanded(child: _toolTile(icon: Icons.menu_book_outlined, title: _t('دليل الحماية', 'FIELD GUIDE'), subtitle: _t('دروس وممارسات آمنة', 'Security lessons'), onTap: onLearn, tint: C.accentPrimary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (items.isNotEmpty) ...[
                    SectionTitle(_t('النشاط الأخير', 'RECENT ACTIVITY'), trailing: TextButton(onPressed: () => onTab(3), child: Text(_t('عرض الكل', 'VIEW ALL')))),
                    for (final item in items.take(3)) _recent(item),
                    const SizedBox(height: 8),
                    StatsCard(items: items),
                    const SizedBox(height: 16),
                  ] else ...[
                    GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
                      radius: 18,
                      child: Row(
                        children: [
                          const Icon(Icons.history_toggle_off_rounded, color: C.textSecondary, size: 27),
                          const SizedBox(width: 11),
                          Expanded(child: Text(_t('لا توجد عمليات محفوظة حتى الآن. أول فحص سيظهر هنا.', 'No saved scans yet. Your first scan will appear here.'), style: const TextStyle(color: C.textSecondary, fontSize: 11.5, height: 1.5))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _tipCard(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class QuickScanOmnibox extends StatefulWidget {
  const QuickScanOmnibox({super.key, required this.onAnalyze});

  final ValueChanged<String> onAnalyze;

  @override
  State<QuickScanOmnibox> createState() => _QuickScanOmniboxState();
}

class _QuickScanOmniboxState extends State<QuickScanOmnibox> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final value = data?.text?.trim() ?? '';
      if (value.isEmpty) {
        if (mounted) toast(context, _t('الحافظة فارغة', 'Clipboard is empty'));
        return;
      }
      _controller.text = value;
      HapticFeedback.lightImpact();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) toast(context, _t('تعذرت قراءة الحافظة', 'Could not read clipboard'));
    }
  }

  void _analyze() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      toast(context, _t('اكتب رابطًا أو الصقه أولًا', 'Enter or paste a URL first'));
      return;
    }
    widget.onAnalyze(value);
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      radius: 20,
      borderColor: alpha(C.accentPrimary, 0.40),
      glowColor: C.accentPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.travel_explore_rounded, color: C.accentPrimary, size: 19),
              const SizedBox(width: 8),
              Expanded(child: Text(_t('أدخل رابطًا للتحليل المحلي', 'PASTE A URL FOR LOCAL ANALYSIS'), style: const TextStyle(color: C.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w800))),
              TextButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste_rounded, size: 15),
                label: Text(_t('لصق', 'PASTE'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                style: TextButton.styleFrom(foregroundColor: C.statusCyan, visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: alpha(C.backgroundPrimary, 0.82),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: alpha(C.borderGlass, 0.85)),
            ),
            child: TextField(
              controller: _controller,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _analyze(),
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: C.textPrimary, fontFamily: 'monospace', fontSize: 12.2),
              decoration: InputDecoration(
                hintText: 'https://example.com/login',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
                prefixIcon: const Icon(Icons.link_rounded, color: C.textSecondary, size: 19),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: _t('مسح', 'Clear'),
                        onPressed: () {
                          _controller.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded, color: C.textSecondary, size: 18),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          CyberButton(label: _t('حلّل الرابط', 'ANALYZE LINK'), icon: Icons.radar_rounded, onPressed: _analyze, height: 48),
        ],
      ),
    );
  }
}

class _QuickNode extends StatelessWidget {
  const _QuickNode({required this.icon, required this.label, required this.tint, required this.onTap});

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(5, 12, 5, 11),
          radius: 17,
          borderColor: alpha(tint, 0.32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: tint, size: 23),
              const SizedBox(height: 8),
              Text(label, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.textPrimary, fontSize: 9, fontWeight: FontWeight.w800, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: alpha(C.surfaceGlass, 0.85),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 41,
            height: 41,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: alpha(C.borderGlass, 0.8))),
            child: Icon(icon, color: C.textPrimary, size: 19),
          ),
        ),
      ),
    );
  }
}
