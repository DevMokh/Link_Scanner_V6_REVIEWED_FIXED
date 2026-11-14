import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A compact, branded navigation glyph for opening the app's side drawer.
///
/// The three scan tracks and offset signal nodes make it visually distinct
/// from Material's stock menu/tune icons while remaining immediately readable.
class AppMenuGlyph extends StatelessWidget {
  const AppMenuGlyph({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _AppMenuGlyphPainter(),
    );
  }
}

class _AppMenuGlyphPainter extends CustomPainter {
  const _AppMenuGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    final track = Paint()
      ..color = alpha(C.muted, 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Three clean navigation tracks.
    canvas.drawLine(const Offset(4, 5.5), const Offset(20, 5.5), track);
    canvas.drawLine(const Offset(4, 12), const Offset(20, 12), track);
    canvas.drawLine(const Offset(4, 18.5), const Offset(20, 18.5), track);

    // Offset signal nodes give the glyph its Link Scanner identity.
    _drawNode(canvas, const Offset(14.5, 5.5), C.secondary);
    _drawNode(canvas, const Offset(8.5, 12), C.accent);
    _drawNode(canvas, const Offset(16.5, 18.5), C.secondary);

    canvas.restore();
  }

  void _drawNode(Canvas canvas, Offset center, Color color) {
    final halo = Paint()
      ..color = alpha(color, 0.22)
      ..style = PaintingStyle.fill;
    final core = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 3.1, halo);
    canvas.drawCircle(center, 1.65, core);
  }

  @override
  bool shouldRepaint(covariant _AppMenuGlyphPainter oldDelegate) => false;
}
