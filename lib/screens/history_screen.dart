import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../services/history_store.dart';
import '../services/inbox.dart';
import '../services/strings.dart';
import '../services/settings_store.dart';
import '../widgets/app_header.dart';
import '../widgets/common.dart';
import '../widgets/stats_card.dart';

enum _HistoryFilter { all, safe, suspicious, malicious }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.onTab});

  final void Function(int tabIndex) onTab;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _search = TextEditingController();
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _t(String ar, String en) => SettingsStore.instance.english ? en : ar;

  String _filterLabel(_HistoryFilter filter) {
    switch (filter) {
      case _HistoryFilter.all:
        return _t('الكل', 'All');
      case _HistoryFilter.safe:
        return _t('دون مؤشرات', 'Safe');
      case _HistoryFilter.suspicious:
        return _t('مشبوه', 'Suspicious');
      case _HistoryFilter.malicious:
        return _t('خطير', 'Malicious');
    }
  }

  bool _matches(HistoryItem item) {
    final query = _search.text.trim().toLowerCase();
    final matchesSearch = query.isEmpty || item.title.toLowerCase().contains(query);
    if (!matchesSearch) return false;
    switch (_filter) {
      case _HistoryFilter.all:
        return true;
      case _HistoryFilter.safe:
        return item.level == RiskLevel.low;
      case _HistoryFilter.suspicious:
        return item.level == RiskLevel.medium;
      case _HistoryFilter.malicious:
        return item.level == RiskLevel.high || item.level == RiskLevel.critical;
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.backgroundSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: alpha(C.borderGlass, 0.8))),
        title: Text(_t('مسح السجل', 'Clear history')),
        content: Text(_t('هيتم حذف كل الفحوصات المحفوظة على هذا الجهاز.', 'All scan records saved on this device will be deleted.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('إلغاء', 'Cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: C.statusDanger, foregroundColor: Colors.white),
            child: Text(_t('امسح', 'Clear')),
          ),
        ],
      ),
    );
    if (ok == true) await HistoryStore.instance.clear();
  }

  Future<void> _export(List<HistoryItem> items) async {
    final buffer = StringBuffer('سجل فحوصات كاشف الروابط | Link Scanner\n\n');
    for (final item in items) {
      buffer.writeln(
        '${fmtTime(item.time)} - ${item.kind == ScanKind.url ? 'رابط' : 'رسالة'} - '
        '${item.score}/100 (${item.level.label}) - ${item.title}',
      );
    }
    buffer.writeln('\nملاحظة: الدرجات تقديرية محليًا ولا تغني عن الحذر. نصوص الرسائل الأصلية لا تُحفظ في السجل.');
    await SharePlus.instance.share(ShareParams(text: buffer.toString(), subject: 'سجل فحوصات كاشف الروابط'));
  }

  void _rescanUrl(HistoryItem item) {
    // The privacy-preserving history stores only a hostname, never the complete URL or message body.
    final host = item.title.trim();
    if (host.isEmpty) return;
    HapticFeedback.lightImpact();
    Inbox.toUrl.value = Incoming(host.startsWith('http://') || host.startsWith('https://') ? host : 'https://$host');
    widget.onTab(1);
  }

  Future<void> _showEntry(HistoryItem item) async {
    final color = levelColor(item.level);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.backgroundSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: alpha(color, 0.42))),
        title: Row(
          children: [
            Icon(item.kind == ScanKind.url ? Icons.link_rounded : Icons.message_outlined, color: color),
            const SizedBox(width: 9),
            Expanded(child: Text(_t('ملخص الفحص', 'Scan summary'))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MonospaceText(item.title, selectable: true, fontSize: 12),
            const SizedBox(height: 12),
            Row(children: [Text(_t('الدرجة', 'Score'), style: const TextStyle(color: C.textSecondary)), const Spacer(), MonospaceText('${item.score}/100', color: color)]),
            const SizedBox(height: 7),
            Row(children: [Text(_t('التصنيف', 'Verdict'), style: const TextStyle(color: C.textSecondary)), const Spacer(), Text(tr(levelLabelKey(item.level)), style: TextStyle(color: color, fontWeight: FontWeight.w800))]),
            const SizedBox(height: 7),
            Row(children: [Text(_t('التاريخ', 'Date'), style: const TextStyle(color: C.textSecondary)), const Spacer(), Text(fmtTime(item.time), style: const TextStyle(color: C.textPrimary))]),
            const SizedBox(height: 12),
            Text(
              _t('السجل يحتفظ بملخص مختصر فقط. لا يتم تخزين نص الرسالة أو تفاصيل التقرير الكامل حفاظًا على الخصوصية.', 'History stores a short summary only. Message text and full reports are not stored.'),
              style: TextStyle(color: C.textSecondary, fontSize: 11.5, height: 1.45),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('إغلاق', 'Close')))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HistoryStore.instance,
      builder: (context, _) {
        final items = HistoryStore.instance.items;
        final filtered = items.where(_matches).toList(growable: false);
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            AppHeader(title: tr(S.historyTitle), subtitle: tr(S.historySubtitle), icon: Icons.history_rounded),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 2, 15, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (items.isNotEmpty) ...[
                    StatsCard(items: items),
                    const SizedBox(height: 14),
                    GlassCard(
                      padding: const EdgeInsets.all(12),
                      radius: 18,
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(color: C.textPrimary, fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: _t('ابحث في الدومين أو عنوان السجل...', 'Search domain or history title...'),
                          prefixIcon: const Icon(Icons.search_rounded, color: C.textSecondary),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(onPressed: () { _search.clear(); setState(() {}); }, icon: const Icon(Icons.close_rounded, color: C.textSecondary)),
                          border: InputBorder.none,
                          filled: true,
                          fillColor: alpha(C.backgroundPrimary, 0.75),
                        ),
                      ),
                    ),
                    const SizedBox(height: 11),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final filter in _HistoryFilter.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: ChoiceChip(
                                label: Text(_filterLabel(filter)),
                                selected: _filter == filter,
                                onSelected: (_) => setState(() => _filter = filter),
                                selectedColor: alpha(C.accentPrimary, 0.22),
                                backgroundColor: C.backgroundSecondary,
                                side: BorderSide(color: _filter == filter ? alpha(C.accentPrimary, 0.6) : C.borderGlass),
                                labelStyle: TextStyle(color: _filter == filter ? C.textPrimary : C.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 9),
                    SectionTitle(
                      _t('${filtered.length} من ${items.length} فحص', '${filtered.length} of ${items.length} scans'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(tooltip: _t('تصدير السجل', 'Export history'), onPressed: () => _export(items), icon: const Icon(Icons.ios_share_rounded, color: C.accentPrimary, size: 19)),
                          IconButton(tooltip: _t('مسح السجل', 'Clear history'), onPressed: () => _confirmClear(context), icon: const Icon(Icons.delete_sweep_rounded, color: C.statusDanger, size: 20)),
                        ],
                      ),
                    ),
                    if (filtered.isEmpty)
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 16),
                        child: Center(child: Text(_t('لا توجد نتائج مطابقة للبحث أو التصفية.', 'No results match the current search or filters.'), style: const TextStyle(color: C.textSecondary, fontSize: 12))),
                      )
                    else
                      ...filtered.map(_tile),
                  ] else
                    GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 16),
                      child: Column(
                        children: [
                          const Icon(Icons.inbox_outlined, color: C.textSecondary, size: 42),
                          const SizedBox(height: 11),
                          Text(_t('لا توجد فحوصات بعد', 'No scans yet'), style: TextStyle(color: C.textSecondary, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 5),
                          Text(_t('نتائج الفحوصات التي تجريها ستظهر هنا.', 'Your scan results will appear here.'), style: TextStyle(color: C.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tile(HistoryItem item) {
    final color = levelColor(item.level);
    return Dismissible(
      key: ValueKey<int>(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => HistoryStore.instance.remove(item.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(color: alpha(C.statusDanger, 0.18), borderRadius: BorderRadius.circular(18)),
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 22),
        child: const Icon(Icons.delete_outline_rounded, color: C.statusDanger),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _showEntry(item),
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              radius: 18,
              borderColor: alpha(color, 0.25),
              child: Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: alpha(color, 0.12), borderRadius: BorderRadius.circular(15), border: Border.all(color: alpha(color, 0.28))),
                    child: MonospaceText('${item.score}', color: color, fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Directionality(
                          textDirection: item.kind == ScanKind.url ? TextDirection.ltr : TextDirection.rtl,
                          child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                        const SizedBox(height: 5),
                        Text('${item.kind == ScanKind.url ? 'URL' : 'MESSAGE'}  •  ${fmtTime(item.time)}', style: const TextStyle(color: C.textSecondary, fontSize: 9.5, fontFamily: 'monospace')),
                        const SizedBox(height: 6),
                        StatusBadge(label: tr(levelLabelKey(item.level)), color: color, dot: false),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Column(
                    children: [
                      if (item.kind == ScanKind.url)
                        IconButton(
                          tooltip: _t('إعادة فحص الدومين المحفوظ', 'Re-scan saved domain'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _rescanUrl(item),
                          icon: const Icon(Icons.refresh_rounded, color: C.accentPrimary, size: 19),
                        ),
                      IconButton(
                        tooltip: _t('حذف', 'Delete'),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => HistoryStore.instance.remove(item.id),
                        icon: const Icon(Icons.delete_outline_rounded, color: C.textSecondary, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
