import 'package:flutter/material.dart';

/// An ink-drying gold line that draws itself once on mount.
///
/// Used as a dignified completion micro-moment under an ayah: when the
/// user has reflected on today's verse, a thin gold stroke eases out
/// from right to left (matching the Arabic reading direction) and
/// settles. 600ms, no sound. Not gamey — just acknowledgement.
///
/// The stroke stays drawn after the animation completes so revisiting
/// the screen doesn't erase the signal.
class GoldenStroke extends StatefulWidget {
  final double width;
  final double height;
  final Color color;
  final Duration duration;

  const GoldenStroke({
    super.key,
    required this.color,
    this.width = 220,
    this.height = 1.6,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<GoldenStroke> createState() => _GoldenStrokeState();
}

class _GoldenStrokeState extends State<GoldenStroke>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
    // Ease-out so the stroke decelerates like a pen lifting.
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) => CustomPaint(
          painter: _StrokePainter(
            progress: _progress.value,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final double progress;
  final Color color;

  _StrokePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.height
      // Ink gets slightly more saturated as the pen lifts — fade the
      // opacity in parallel with progress so early in the stroke it
      // reads as freshly drawn.
      ..color = color.withValues(alpha: (0.25 + 0.55 * progress).clamp(0, 1));

    // Draw right-to-left to match the Arabic reading direction: the
    // stroke starts at the right edge and extends leftward as
    // `progress` grows.
    final drawn = size.width * progress;
    final y = size.height / 2;
    canvas.drawLine(
      Offset(size.width, y),
      Offset(size.width - drawn, y),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _StrokePainter old) =>
      old.progress != progress || old.color != color;
}
