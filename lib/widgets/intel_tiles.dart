import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/online_intel.dart';
import 'common.dart';

/// صف نتيجة مصدر تهديدات واحد
class IntelTile extends StatelessWidget {
  const IntelTile({super.key, required this.result});

  final IntelResult result;

  Color get _color {
    switch (result.status) {
      case IntelStatus.clean:
        return C.green;
      case IntelStatus.hit:
        return C.red;
      case IntelStatus.info:
        return C.muted;
      case IntelStatus.skipped:
        return C.muted;
      case IntelStatus.notConfigured:
        return C.muted;
      case IntelStatus.error:
        return C.amber;
    }
  }

  IconData get _icon {
    switch (result.status) {
      case IntelStatus.clean:
        return Icons.check_circle_rounded;
      case IntelStatus.hit:
        return Icons.dangerous_rounded;
      case IntelStatus.info:
        return Icons.info_rounded;
      case IntelStatus.skipped:
        return Icons.remove_circle_outline_rounded;
      case IntelStatus.notConfigured:
        return Icons.settings_rounded;
      case IntelStatus.error:
        return Icons.error_outline_rounded;
    }
  }

  String get _statusLabel {
    switch (result.status) {
      case IntelStatus.clean:
        return 'CLEAN';
      case IntelStatus.hit:
        return 'FLAGGED';
      case IntelStatus.info:
        return 'INFO';
      case IntelStatus.skipped:
        return 'SKIPPED';
      case IntelStatus.notConfigured:
        return 'NOT CONFIGURED';
      case IntelStatus.error:
        return 'ERROR';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        radius: 16,
        borderColor: alpha(c, 0.30),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: alpha(c, 0.10), borderRadius: BorderRadius.circular(12)),
              child: Icon(_icon, color: c, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(result.source, style: const TextStyle(color: C.textPrimary, fontWeight: FontWeight.w800, fontSize: 12.5))),
                      const SizedBox(width: 7),
                      StatusBadge(label: _statusLabel, color: c, dot: false),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(result.message, style: const TextStyle(color: C.textSecondary, fontSize: 11.5, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// سلسلة التحويلات
class ChainView extends StatelessWidget {
  const ChainView({super.key, required this.chain});

  final List<String> chain;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < chain.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: alpha(C.accent, 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(color: C.accent, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText(
                      chain[i],
                      style: const TextStyle(
                        color: C.text,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
