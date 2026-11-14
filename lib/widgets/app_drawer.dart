import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_info.dart';
import '../core/theme.dart';
import '../services/settings_store.dart';
import 'brand_logo.dart';

/// SOC command menu. Every entry still routes to its existing action.
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.selectedTab,
    required this.onTab,
    required this.onQr,
    required this.onImage,
    required this.onSender,
    required this.onBatch,
    required this.onTrain,
    required this.onLearn,
    required this.onSettings,
    this.onExit,
  });

  final int selectedTab;
  final void Function(int tab) onTab;
  final VoidCallback onQr;
  final VoidCallback onImage;
  final VoidCallback onSender;
  final VoidCallback onBatch;
  final VoidCallback onTrain;
  final VoidCallback onLearn;
  final VoidCallback onSettings;
  final VoidCallback? onExit;

  static String _t(String ar, String en) => SettingsStore.instance.english ? en : ar;

  void _go(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
        child: Text(text.toUpperCase(), style: const TextStyle(color: C.secondary, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.w900, letterSpacing: 0.75)),
      );

  Widget _item(BuildContext context, IconData icon, String label, VoidCallback action, {bool selected = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected ? alpha(C.accent, 0.13) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _go(context, action),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? alpha(C.accent, 0.42) : Colors.transparent),
            ),
            child: Row(children: [
              Icon(icon, color: selected ? C.accent : C.muted, size: 19),
              const SizedBox(width: 11),
              Expanded(child: Text(label, style: TextStyle(color: selected ? C.accent : C.text, fontSize: 12.5, fontWeight: selected ? FontWeight.w900 : FontWeight.w600))),
              if (selected) const Text('ACTIVE', style: TextStyle(color: C.green, fontSize: 8, fontFamily: 'monospace', fontWeight: FontWeight.w900)),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsStore.instance,
      builder: (context, _) {
        return Drawer(
          width: 310,
          backgroundColor: C.bg,
          child: SafeArea(
            child: Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(17, 17, 17, 14),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const LinkScannerLogo(size: 52, glowing: false),
                    const SizedBox(width: 11),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text(kAppNameAr, style: TextStyle(color: C.text, fontSize: 19, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      const Text(kAppNameEn, style: TextStyle(color: C.secondary, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.25)),
                      const SizedBox(height: 2),
                      const Text('PRECISION INTELLIGENCE', style: TextStyle(color: C.muted, fontFamily: 'monospace', fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.35)),
                    ])),
                  ]),
                  const SizedBox(height: 13),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: C.surface, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(6)),
                    child: Row(children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle)),
                      const SizedBox(width: 7),
                      const Text('LOCAL ANALYSIS', style: TextStyle(color: C.statusSafe, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.w900)),
                      const Spacer(),
                      Text('v$kAppVersion', style: const TextStyle(color: C.muted, fontSize: 9, fontFamily: 'monospace')),
                    ]),
                  ),
                ]),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.symmetric(vertical: 6), children: [
                  _label(_t('مركز العمليات', 'OPERATIONS')),
                  _item(context, Icons.home_rounded, _t('الرئيسية', 'Home'), () => onTab(0), selected: selectedTab == 0),
                  _item(context, Icons.link_rounded, _t('فحص الروابط', 'Scan links'), () => onTab(1), selected: selectedTab == 1),
                  _item(context, Icons.mark_email_unread_rounded, _t('فحص الرسائل', 'Scan messages'), () => onTab(2), selected: selectedTab == 2),
                  _item(context, Icons.history_rounded, _t('سجل الفحوصات', 'Scan history'), () => onTab(3), selected: selectedTab == 3),
                  _label(_t('أدوات الجمع والتحليل', 'COLLECTION & ANALYSIS')),
                  _item(context, Icons.qr_code_scanner_rounded, _t('فحص رمز QR', 'Scan a QR code'), onQr),
                  _item(context, Icons.image_search_rounded, _t('فحص الصور', 'Scan an image'), onImage),
                  _item(context, Icons.alternate_email_rounded, _t('فحص المرسل', 'Check a sender'), onSender),
                  _item(context, Icons.playlist_add_check_rounded, _t('الفحص المجمّع', 'Batch scan'), onBatch),
                  _label(_t('المعرفة والإعدادات', 'KNOWLEDGE & CONFIG')),
                  _item(context, Icons.sports_esports_rounded, _t('تدرّب على الكشف', 'Train your detection'), onTrain),
                  _item(context, Icons.school_rounded, _t('دروس الحماية', 'Protection lessons'), onLearn),
                  _item(context, Icons.apps_rounded, _t('أدوات الأمان الإضافية', 'More security tools'), () => onTab(4), selected: selectedTab == 4),
                  _item(context, Icons.settings_rounded, _t('الإعدادات', 'Settings'), onSettings),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 9, 14, 13),
                child: Column(children: [
                  Text('${_t('الإصدار', 'Version')} $kAppVersion ($kAppBuild)', style: const TextStyle(color: C.muted, fontSize: 10, fontFamily: 'monospace')),
                  const SizedBox(height: 9),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onExit ?? () => SystemNavigator.pop(),
                      style: OutlinedButton.styleFrom(foregroundColor: C.red, side: BorderSide(color: alpha(C.red, 0.35)), padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7))),
                      icon: const Icon(Icons.power_settings_new_rounded, size: 17),
                      label: Text(_t('خروج', 'Exit')),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}
