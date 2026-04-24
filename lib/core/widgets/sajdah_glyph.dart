import 'package:flutter/material.dart';

/// A small custom glyph for the Sajdah (prostration) badge.
///
/// A crescent arc resting on a baseline — visually suggests a bowing
/// head meeting the ground. Replaces the 🕌 mosque emoji that used to
/// sit in the Sajdah pill. Sajdah is a command, not a decoration, so
/// this glyph is drawn once with deliberate geometry in the accent
/// color rather than borrowed from the emoji set.
class SajdahGlyph extends StatelessWidget {
  final double size;
  final Color color;

  const SajdahGlyph({
    super.key,
    this.size = 12,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SajdahGlyphPainter(color: color),
      ),
    );
  }
}

class _SajdahGlyphPainter extends CustomPainter {
  final Color color;

  _SajdahGlyphPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.height * 0.12;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;

    // Crescent arc — centered horizontally, sitting above the baseline.
    // Start from upper-left, sweep downward to upper-right, so the
    // concave side faces the ground (the direction of prostration).
    final arcRect = Rect.fromLTWH(
      size.width * 0.12,
      size.height * 0.10,
      size.width * 0.76,
      size.height * 0.66,
    );
    canvas.drawArc(arcRect, 3.4, 2.6, false, paint);

    // Baseline — the ground the head meets.
    final y = size.height * 0.88;
    canvas.drawLine(
      Offset(size.width * 0.08, y),
      Offset(size.width * 0.92, y),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SajdahGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}
