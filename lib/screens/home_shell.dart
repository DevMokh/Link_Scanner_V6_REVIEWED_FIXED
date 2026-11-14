import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../services/inbox.dart';
import '../services/message_analyzer.dart';
import '../services/qr_analyzer.dart';
import '../services/settings_store.dart';
import '../services/strings.dart';
import '../widgets/app_drawer.dart';
import '../widgets/common.dart';
import 'history_screen.dart';
import 'home_dashboard.dart';
import 'image_scan_screen.dart';
import 'message_scan_screen.dart';
import 'more_screen.dart';
import 'qr_scan_screen.dart';
import 'url_scan_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  String _lastClip = '';

  /// مفتاح الـ Scaffold عشان زر القائمة في الداشبورد يفتح الـ Drawer.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ترتيب التبويبات: 0 الرئيسية، 1 رابط، 2 رسالة، 3 السجل، 4 المزيد.
  // نحتفظ بنفس Widgets طوال عمر الشاشة حتى لا نعيد إنشاء شجرة التبويبات
  // في كل ضغطة تنقّل أو تحديث صغير.
  late List<Widget> _pages;

  void _refreshPages() {
    if (!mounted) return;
    // نحتفظ بالشاشات بين التنقلات العادية، لكن نحدّث Widgets عند تغيير
    // الإعدادات (ومنها اللغة) حتى تعيد النصوص المترجمة بناء نفسها.
    setState(() => _pages = _createPages());
  }

  void _selectTab(int index) {
    if (!mounted || index < 0 || index >= 5 || index == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = index);
  }

  List<Widget> _createPages() => <Widget>[
        HomeDashboard(
          onTab: _selectTab,
          onQr: _openQr,
          onImage: _openImage,
          onSender: () => openSenderTool(context),
          onBatch: () => openBatchTool(context),
          onTrain: () => openTrain(context),
          onLearn: () => openLearn(context),
          onSettings: () => openSettings(context),
          onMenu: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        const UrlScanScreen(),
        const MessageScanScreen(),
        HistoryScreen(onTab: _selectTab),
        MoreScreen(onQr: _openQr, onImage: _openImage),
      ];

  /// مسح QR من أي مكان: لو فيه رابط يتفحص في تبويب الرابط، وغير كده نعرض المحتوى.
  Future<void> _openQr() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const QrScanScreen()),
    );
    if (raw == null || !mounted) return;
    final info = QrAnalyzer.classify(raw);
    if (info.link != null) {
      setState(() => _index = 1);
      Inbox.toUrl.value = Incoming(info.link!);
      toast(context, 'تم قراءة الرمز وفحص الرابط');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface2,
        title: Text('رمز QR: ${info.title}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(info.note, style: const TextStyle(height: 1.6)),
              const SizedBox(height: 12),
              SelectableText(
                info.raw,
                style: const TextStyle(color: C.muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('تمام'),
          ),
        ],
      ),
    );
  }

  void _openImage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ImageScanScreen()),
    );
  }

  @override
  void initState() {
    super.initState();
    _pages = _createPages();
    SettingsStore.instance.addListener(_refreshPages);
    WidgetsBinding.instance.addObserver(this);
    Inbox.shared.addListener(_onShared);
    Inbox.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SettingsStore.instance.removeListener(_refreshPages);
    Inbox.shared.removeListener(_onShared);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkClipboard();
  }

  /// نص جاي من "مشاركة" أو تحديد نص: رابط واحد -> فحص رابط، غير كده -> فحص رسالة
  void _onShared() {
    final inc = Inbox.shared.value;
    if (inc == null) return;
    final text = inc.text;
    final links = MessageAnalyzer.extractLinks(text);
    final singleLink = links.length == 1 && (text.length - links.first.length) < 12;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (singleLink) {
        setState(() => _index = 1);
        Inbox.toUrl.value = Incoming(links.first);
      } else {
        setState(() => _index = 2);
        Inbox.toMessage.value = Incoming(text);
      }
    });
  }

  Future<void> _checkClipboard() async {
    if (!SettingsStore.instance.clipWatch) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    try {
      final d = await Clipboard.getData(Clipboard.kTextPlain);
      final t = d?.text?.trim();
      if (t == null || t.isEmpty || t == _lastClip) return;
      _lastClip = t;
      final links = MessageAnalyzer.extractLinks(t);
      if (links.isEmpty || !mounted) return;
      final first = links.first;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: const Text('في رابط منسوخ. تحب تفحصه؟'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'افحص',
          textColor: C.accent,
          onPressed: () {
            setState(() => _index = 1);
            Inbox.toUrl.value = Incoming(first);
          },
        ),
      ));
    } catch (_) {
      // أندرويد منع قراءة الحافظة الآن: نتجاهل
    }
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _index == index;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _selectTab(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: selected ? alpha(C.accent, 0.13) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: selected ? Border.all(color: alpha(C.accent, 0.38)) : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: selected ? C.accent : C.muted, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? C.accent : C.muted,
                      fontSize: 9.5,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // الاستماع لـ SettingsStore هنا يخلي الشاشة كلها (وشاشاتها الفرعية) تعيد
    // البناء لما لغة الواجهة تتغيّر من الإعدادات.
    return ListenableBuilder(
      listenable: SettingsStore.instance,
      builder: (context, _) {
        return Scaffold(
          key: _scaffoldKey,
          drawer: AppDrawer(
            selectedTab: _index,
            onTab: _selectTab,
            onQr: _openQr,
            onImage: _openImage,
            onSender: () => openSenderTool(context),
            onBatch: () => openBatchTool(context),
            onTrain: () => openTrain(context),
            onLearn: () => openLearn(context),
            onSettings: () => openSettings(context),
          ),
          body: IndexedStack(index: _index, children: _pages),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                radius: 24,
                blur: 18,
                borderColor: alpha(C.borderGlass, 0.82),
                child: SizedBox(
                  height: 62,
                  child: Row(
                    children: [
                      _navItem(0, Icons.home_rounded, tr(S.navHome)),
                      _navItem(1, Icons.link_rounded, tr(S.navLink)),
                      _navItem(2, Icons.mark_email_unread_rounded, tr(S.navMessage)),
                      _navItem(3, Icons.history_rounded, tr(S.navHistory)),
                      _navItem(4, Icons.grid_view_rounded, tr(S.navMore)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
