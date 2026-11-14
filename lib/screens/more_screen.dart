import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/settings_store.dart';
import '../services/strings.dart';
import '../widgets/common.dart';
import '../widgets/intel_settings.dart';
import '../widgets/app_header.dart';
import '../widgets/app_info_panel.dart';
import '../widgets/sub_page.dart';
import '../widgets/tools.dart';
import '../widgets/tools_extra.dart';
import 'learn_screen.dart';
import 'train_screen.dart';

String _t(String ar, String en) => SettingsStore.instance.english ? en : ar;

void _push(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

void openTrain(BuildContext context) => _push(context, const BackPage(child: TrainScreen()));
void openLearn(BuildContext context) => _push(context, const LearnPage());

void openSettings(BuildContext context) {
  _push(
    context,
    ToolPage(
      title: _t('الإعدادات', 'Settings'),
      subtitle: _t('اللغة والتنبيهات ومصادر الفحص المتقدم', 'Language, alerts and advanced scan sources'),
      icon: Icons.settings_rounded,
      children: const <Widget>[
        SettingsPanel(),
        SizedBox(height: 14),
        IntelSettingsPanel(),
        SizedBox(height: 14),
        AppInfoPanel(),
      ],
    ),
  );
}

void openSenderTool(BuildContext context) {
  _openTool(context, _t('فحص المرسل', 'Check a sender'), _t('تحقق من هوية المرسل', 'Verify who sent it'), Icons.alternate_email_rounded, const SenderTool());
}

void openBatchTool(BuildContext context) {
  _openTool(context, _t('فحص مجمّع', 'Batch scan'), _t('الصق عدة روابط وافحصها دفعة واحدة', 'Paste several links and scan them together'), Icons.playlist_add_check_rounded, const BatchTool());
}

void _openTool(BuildContext context, String title, String subtitle, IconData icon, Widget tool) {
  _push(context, ToolPage(title: title, subtitle: subtitle, icon: icon, children: <Widget>[tool]));
}

/// All secondary modules remain available, grouped by analyst workflow.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.onQr, required this.onImage});

  final VoidCallback onQr;
  final VoidCallback onImage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        AppHeader(title: tr(S.moreTitle), subtitle: tr(S.moreSubtitle), icon: Icons.grid_view_rounded),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _consoleBanner(),
            const SizedBox(height: 16),
            SectionTitle(_t('جمع الأدلة والتحليل', 'COLLECT & ANALYZE')),
            const SizedBox(height: 8),
            _module(
              code: 'MOD-01', icon: Icons.qr_code_scanner_rounded,
              title: _t('فحص رمز QR', 'QR INSPECTOR'),
              subtitle: _t('اقرأ الرمز واستخرج الرابط قبل فتحه', 'Read codes and inspect embedded links'),
              onTap: onQr, tint: C.green,
            ),
            _module(
              code: 'MOD-02', icon: Icons.image_search_rounded,
              title: _t('فحص صورة', 'IMAGE ANALYSIS'),
              subtitle: _t('حلّل لقطة شاشة واستخرج النصوص والروابط', 'Extract text and links from screenshots'),
              onTap: onImage, tint: C.secondary,
            ),
            _module(
              code: 'MOD-03', icon: Icons.alternate_email_rounded,
              title: _t('فحص المرسل', 'SENDER INTEL'),
              subtitle: _t('تحقق من بيانات وهوية المرسل', 'Inspect sender identity and metadata'),
              onTap: () => openSenderTool(context), tint: C.amber,
            ),
            _module(
              code: 'MOD-04', icon: Icons.playlist_add_check_rounded,
              title: _t('الفحص المجمّع', 'BATCH ANALYZER'),
              subtitle: _t('افحص عدة روابط في عملية واحدة', 'Run multiple URLs in one operation'),
              onTap: () => openBatchTool(context), tint: C.accent,
            ),
            const SizedBox(height: 15),
            SectionTitle(_t('معمل التدريب', 'TRAINING LAB')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _module(
                code: 'LAB-01', icon: Icons.sports_esports_rounded,
                title: _t('تدرّب على الكشف', 'DETECTION DRILLS'),
                subtitle: _t('تحديات بمستويات مختلفة', 'Progressive challenges'),
                onTap: () => openTrain(context), tint: C.secondary, compact: true,
              )),
              const SizedBox(width: 8),
              Expanded(child: _module(
                code: 'LAB-02', icon: Icons.school_rounded,
                title: _t('دليل الحماية', 'FIELD GUIDE'),
                subtitle: _t('دروس وعلامات الاحتيال', 'Lessons and scam indicators'),
                onTap: () => openLearn(context), tint: C.green, compact: true,
              )),
            ]),
            const SizedBox(height: 15),
            SectionTitle(_t('أدوات المرافق', 'ANALYST UTILITIES')),
            const SizedBox(height: 8),
            _module(
              code: 'UTIL-01', icon: Icons.password_rounded,
              title: _t('قوة كلمة السر', 'PASSWORD AUDIT'),
              subtitle: _t('قيّم قوة كلمة السر محليًا', 'Evaluate password strength locally'),
              onTap: () => _openTool(context, _t('قوة كلمة السر', 'Password strength'), _t('التحليل بيتم على جهازك فقط', 'Analyzed on your device only'), Icons.password_rounded, const StrengthTool()),
              tint: C.secondary,
            ),
            _module(
              code: 'UTIL-02', icon: Icons.casino_rounded,
              title: _t('مولّد كلمات السر', 'PASSWORD GENERATOR'),
              subtitle: _t('أنشئ كلمات قوية وعشوائية', 'Generate strong random passwords'),
              onTap: () => _openTool(context, _t('مولّد كلمات السر', 'Password generator'), _t('كلمات سر عشوائية قوية', 'Strong random passwords'), Icons.casino_rounded, const GeneratorTool()),
              tint: C.green,
            ),
            _module(
              code: 'UTIL-03', icon: Icons.cleaning_services_rounded,
              title: _t('منظّف الروابط', 'URL SANITIZER'),
              subtitle: _t('أزل معاملات التتبع من الرابط', 'Remove tracking parameters from URLs'),
              onTap: () => _openTool(context, _t('منظّف الروابط', 'Link cleaner'), _t('شيل التتبّع من الرابط', 'Remove tracking from a link'), Icons.cleaning_services_rounded, const CleanerTool()),
              tint: C.amber,
            ),
            _module(
              code: 'UTIL-04', icon: Icons.tag_rounded,
              title: _t('حساب الهاش', 'HASH GENERATOR'),
              subtitle: _t('احسب بصمة النص على جهازك', 'Compute a text fingerprint locally'),
              onTap: () => _openTool(context, _t('هاش', 'Hash'), _t('بصمة النص على جهازك', 'Text fingerprint on your device'), Icons.tag_rounded, const HashTool()),
              tint: C.orange,
            ),
            const SizedBox(height: 15),
            SectionTitle(_t('تهيئة المنصة', 'PLATFORM CONFIGURATION')),
            const SizedBox(height: 8),
            _module(
              code: 'SYS-01', icon: Icons.settings_rounded,
              title: _t('الإعدادات ومصادر الفحص', 'SYSTEM SETTINGS'),
              subtitle: _t('اللغة، مراقبة الحافظة، ومفاتيح الفحص المتقدم', 'Language, clipboard watch and advanced scan keys'),
              onTap: () => openSettings(context), tint: C.accent,
            ),
          ]),
        ),
      ],
    );
  }

  Widget _consoleBanner() {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      radius: 20,
      borderColor: alpha(C.accentPrimary, 0.28),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: alpha(C.accentPrimary, 0.12), border: Border.all(color: alpha(C.accentPrimary, 0.30)), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.grid_view_rounded, color: C.accentPrimary, size: 22),
        ),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t('مكتبة الأدوات', 'TOOLKIT INDEX'), style: const TextStyle(color: C.textPrimary, fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 4),
          Text(_t('وحدات إضافية للفحص والتعلّم والإدارة', 'Additional modules for analysis, training and system management'), style: const TextStyle(color: C.textSecondary, fontSize: 10.5, height: 1.35)),
        ])),
        const StatusBadge(label: 'MODULES', color: C.statusCyan, dot: false),
      ]),
    );
  }

  Widget _module({
    required String code,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color tint,
    bool compact = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 0 : 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: GlassCard(
            padding: EdgeInsets.all(compact ? 11 : 12),
            radius: 18,
            borderColor: alpha(tint, 0.22),
            child: compact
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Icon(icon, color: tint, size: 20), const Spacer(), MonospaceText(code, color: C.textSecondary, fontSize: 8)]),
                    const SizedBox(height: 12),
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.textPrimary, fontSize: 11, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.textSecondary, fontSize: 9, height: 1.3)),
                  ])
                : Row(children: [
                    Container(
                      width: 41,
                      height: 41,
                      decoration: BoxDecoration(color: alpha(tint, 0.12), border: Border.all(color: alpha(tint, 0.27)), borderRadius: BorderRadius.circular(14)),
                      child: Icon(icon, color: tint, size: 20),
                    ),
                    const SizedBox(width: 11),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w800))), const SizedBox(width: 7), MonospaceText(code, color: C.textSecondary, fontSize: 8)]),
                      const SizedBox(height: 4),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.textSecondary, fontSize: 9.5, height: 1.25)),
                    ])),
                    const Icon(Icons.chevron_right_rounded, color: C.textSecondary, size: 18),
                  ]),
          ),
        ),
      ),
    );
  }
}
