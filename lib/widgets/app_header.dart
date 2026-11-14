import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'app_menu_glyph.dart';
import 'brand_logo.dart';
import 'common.dart';

/// Shared glass header for secondary screens.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
  });

  final String title;
  final String subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final scaffold = Scaffold.maybeOf(context);
    final hasMenu = scaffold?.hasDrawer ?? false;
    final badge = icon == null
        ? const LinkScannerLogo(size: 38, glowing: false)
        : Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: alpha(C.accentPrimary, 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: alpha(C.accentPrimary, 0.32)),
            ),
            child: Icon(icon, color: C.accentPrimary, size: 21),
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(15, top + 10, 15, 14),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(13, 11, 12, 12),
        radius: 20,
        blur: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: C.statusSafe, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'LINK SCANNER  /  PRECISION INTELLIGENCE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: C.statusCyan, fontSize: 8.5, fontFamily: 'monospace', fontWeight: FontWeight.w800, letterSpacing: 0.45),
                  ),
                ),
                const StatusBadge(label: 'V5', color: C.accentPrimary, dot: false),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                badge,
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.textPrimary, fontSize: 16.5, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.textSecondary, fontSize: 10.5, height: 1.3)),
                    ],
                  ),
                ),
                if (hasMenu) ...[
                  const SizedBox(width: 8),
                  Material(
                    color: alpha(C.backgroundPrimary, 0.75),
                    borderRadius: BorderRadius.circular(13),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: () => scaffold?.openDrawer(),
                      child: Tooltip(
                        message: 'فتح القائمة الجانبية',
                        child: Semantics(
                          button: true,
                          label: 'فتح القائمة الجانبية',
                          child: const SizedBox(width: 40, height: 40, child: Center(child: AppMenuGlyph(size: 21))),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
