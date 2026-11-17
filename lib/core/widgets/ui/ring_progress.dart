import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Circular progress ring with a child in the middle (countdowns, timers,
/// hold-to-finish).
class RingProgress extends StatelessWidget {
  /// 0.0 – 1.0
  final double value;
  final double size;
  final double strokeWidth;
  final Gradient gradient;
  final Color trackColor;
  final Widget? child;

  const RingProgress({
    super.key,
    required this.value,
    required this.size,
    this.strokeWidth = 6,
    this.gradient = AppColors.primaryGradient,
    this.trackColor = AppColors.stroke,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0.0, 1.0),
          strokeWidth: strokeWidth,
          gradient: gradient,
          trackColor: trackColor,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final double strokeWidth;
  final Gradient gradient;
  final Color trackColor;

  _RingPainter({
    required this.value,
    required this.strokeWidth,
    required this.gradient,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);
    if (value <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(rect);
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * value, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.strokeWidth != strokeWidth ||
      old.trackColor != trackColor;
}
