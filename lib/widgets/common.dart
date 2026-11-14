import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// Frosted surface used by dashboards, tool panels and technical reports.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.radius = 20,
    this.glowColor,
    this.blur = 14,
    this.margin,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final double radius;
  final Color? glowColor;
  final double blur;
  final EdgeInsetsGeometry? margin;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: glowColor == null
            ? null
            : glow(glowColor!, opacity: 0.12, blur: 24, spread: 0.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: gradient == null ? C.surfaceGlass : null,
              gradient: gradient,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: borderColor ?? alpha(C.borderGlass, 0.78),
                width: 1,
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Compact semantic status pill. Color is always driven by a real app state.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.color = C.statusCyan,
    this.icon,
    this.dot = true,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: alpha(color, 0.11),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: alpha(color, 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
          ] else if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }
}

/// Monospace presentation for domains, URLs, hashes, IPs and technical values.
class MonospaceText extends StatelessWidget {
  const MonospaceText(
    this.data, {
    super.key,
    this.color = C.textPrimary,
    this.fontSize = 12,
    this.fontWeight = FontWeight.w600,
    this.maxLines,
    this.textAlign,
    this.selectable = false,
  });

  final String data;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final int? maxLines;
  final TextAlign? textAlign;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: color,
      fontSize: fontSize,
      fontFamily: 'monospace',
      fontWeight: fontWeight,
      height: 1.45,
      letterSpacing: 0.05,
    );
    if (selectable) {
      return SelectableText(
        data,
        maxLines: maxLines,
        textAlign: textAlign,
        style: style,
      );
    }
    return Text(
      data,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      textAlign: textAlign,
      style: style,
    );
  }
}

/// Main Indigo action with light haptic feedback and restrained outer glow.
class CyberButton extends StatelessWidget {
  const CyberButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.height = 54,
    this.fullWidth = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final double height;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final button = Opacity(
      opacity: enabled ? 1 : 0.42,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[C.accentPrimary, C.accentDeep],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled ? glow(C.accentPrimary, opacity: 0.28, blur: 20) : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled
                ? () {
                    HapticFeedback.mediumImpact();
                    onPressed!();
                  }
                : null,
            child: SizedBox(
              height: height,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return fullWidth ? button : IntrinsicWidth(child: button);
  }
}

/// Compatibility wrapper retained for all existing buttons and callbacks.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.height = 54,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) => CyberButton(
        label: label,
        icon: icon,
        onPressed: onPressed,
        height: height,
      );
}

/// Legacy panel API, now rendered with the shared frosted-glass treatment.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: padding,
        borderColor: borderColor,
        radius: 18,
        child: child,
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(1, 8, 1, 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 17,
            decoration: BoxDecoration(
              color: C.accentPrimary,
              borderRadius: BorderRadius.circular(4),
              boxShadow: glow(C.accentPrimary, opacity: 0.24, blur: 9),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: C.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

InputDecoration fieldDecoration({String? hint, Widget? suffix}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: C.textSecondary, fontSize: 13),
    filled: true,
    fillColor: alpha(C.backgroundPrimary, 0.78),
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.all(14),
    enabledBorder: border(alpha(C.borderGlass, 0.9)),
    focusedBorder: border(C.accentPrimary),
    border: border(alpha(C.borderGlass, 0.9)),
  );
}

void toast(BuildContext context, String message) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(message)));
}

ButtonStyle outlineButtonStyle() => OutlinedButton.styleFrom(
      foregroundColor: C.textPrimary,
      side: BorderSide(color: alpha(C.borderGlass, 0.9)),
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

ButtonStyle filledButtonStyle() => FilledButton.styleFrom(
      backgroundColor: C.accentPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
    );

/// Retained for older screens; now a soft indigo/cyan ambient field, not a hacker grid.
class CyberGrid extends StatelessWidget {
  const CyberGrid({super.key, required this.child, this.opacity = 0.22});

  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _CyberGridPainter(opacity),
        child: child,
      );
}

class _CyberGridPainter extends CustomPainter {
  const _CyberGridPainter(this.opacity);
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.75, -0.9),
        radius: 1.1,
        colors: <Color>[alpha(C.accentPrimary, opacity * 0.25), Colors.transparent],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
    final secondary = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.9, 0.8),
        radius: 0.9,
        colors: <Color>[alpha(C.statusCyan, opacity * 0.12), Colors.transparent],
      ).createShader(rect);
    canvas.drawRect(rect, secondary);
  }

  @override
  bool shouldRepaint(covariant _CyberGridPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
