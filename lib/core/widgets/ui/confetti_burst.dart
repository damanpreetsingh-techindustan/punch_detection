import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// One-shot confetti burst from the top centre, played when it is first
/// built. Ignores touches; put it on top of the screen in a Stack.
class ConfettiBurst extends StatefulWidget {
  final int pieces;
  final Duration duration;

  const ConfettiBurst({
    super.key,
    this.pieces = 70,
    this.duration = const Duration(milliseconds: 2200),
  });

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  static const _colors = [
    AppColors.primary,
    AppColors.primaryLight,
    AppColors.gold,
    AppColors.success,
    AppColors.textPrimary,
  ];

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  late final List<_Piece> _pieces = () {
    final rnd = math.Random();
    return List.generate(widget.pieces, (i) {
      // Fan upwards and outwards, then fall.
      final angle = -math.pi / 2 + (rnd.nextDouble() - 0.5) * math.pi * 0.9;
      final speed = 0.55 + rnd.nextDouble() * 0.6;
      return _Piece(
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        spin: (rnd.nextDouble() - 0.5) * 14,
        size: 5 + rnd.nextDouble() * 6,
        color: _colors[i % _colors.length],
        round: rnd.nextBool(),
      );
    });
  }();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_pieces, _ctrl.value),
          ),
        ),
      ),
    );
  }
}

class _Piece {
  final double vx;
  final double vy;
  final double spin;
  final double size;
  final Color color;
  final bool round;

  const _Piece({
    required this.vx,
    required this.vy,
    required this.spin,
    required this.size,
    required this.color,
    required this.round,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;

  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final origin = Offset(size.width / 2, size.height * 0.28);
    final scale = size.shortestSide;
    const gravity = 1.6;
    final fade = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
    final paint = Paint();
    for (final p in pieces) {
      final x = origin.dx + p.vx * scale * t;
      final y = origin.dy + (p.vy * t + 0.5 * gravity * t * t) * scale;
      paint.color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.5,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
