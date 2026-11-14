import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Precision risk dial (270°), animated from zero to the real scan score.
class RiskGauge extends StatelessWidget {
  const RiskGauge({
    super.key,
    required this.score,
    required this.color,
    this.size = 184,
  });

  final int score;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final safeScore = score.clamp(0, 100).toInt();
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(safeScore),
      tween: Tween<double>(begin: 0, end: safeScore / 100),
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final liveColor = riskColorForScore(value * 100);
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _GaugePainter(value, liveColor, fallbackColor: color),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(value * 100).round()}',
                    style: TextStyle(
                      fontSize: size * 0.30,
                      fontWeight: FontWeight.w900,
                      color: liveColor,
                      height: 1,
                      fontFamily: 'monospace',
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'RISK SCORE / 100',
                    style: TextStyle(
                      color: C.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter(this.value, this.color, {required this.fallbackColor});

  final double value;
  final Color color;
  final Color fallbackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final rect = Rect.fromLTWH(
      stroke + 4,
      stroke + 4,
      size.width - (stroke + 4) * 2,
      size.height - (stroke + 4) * 2,
    );
    const start = math.pi * 0.75;
    const sweepAll = math.pi * 1.5;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = alpha(C.borderGlass, 0.8);
    canvas.drawArc(rect, start, sweepAll, false, track);

    // Precision ticks are intentionally subtle and do not resemble a terminal grid.
    final tickPaint = Paint()
      ..color = alpha(C.textSecondary, 0.27)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final center = rect.center;
    final outerRadius = rect.width / 2 + 10;
    for (var i = 0; i <= 20; i++) {
      final angle = start + sweepAll * (i / 20);
      final major = i % 5 == 0;
      final innerRadius = outerRadius - (major ? 8 : 4);
      final p1 = Offset(
        center.dx + math.cos(angle) * innerRadius,
        center.dy + math.sin(angle) * innerRadius,
      );
      final p2 = Offset(
        center.dx + math.cos(angle) * outerRadius,
        center.dy + math.sin(angle) * outerRadius,
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    if (value <= 0) return;
    final activeSweep = sweepAll * value.clamp(0.0, 1.0).toDouble();
    final arcShader = SweepGradient(
      startAngle: start,
      endAngle: start + sweepAll,
      colors: <Color>[C.statusCyan, C.statusWarning, C.statusDanger],
      stops: const <double>[0, 0.52, 1],
    ).createShader(rect);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 7
      ..strokeCap = StrokeCap.round
      ..color = alpha(color, 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(rect, start, activeSweep, false, glowPaint);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = arcShader;
    canvas.drawArc(rect, start, activeSweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value || old.color != color || old.fallbackColor != fallbackColor;
}
