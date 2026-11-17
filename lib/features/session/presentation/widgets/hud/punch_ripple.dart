import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../../core/theme/app_colors.dart';

/// Ember ring that bursts from the middle of the camera view, with a light
/// haptic tap, every time [punchCount] goes up. Draw it over the camera; it
/// ignores touches.
class PunchRipple extends StatefulWidget {
  final RxInt punchCount;

  const PunchRipple({super.key, required this.punchCount});

  @override
  State<PunchRipple> createState() => _PunchRippleState();
}

class _PunchRippleState extends State<PunchRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Worker _worker;
  late int _lastCount = widget.punchCount.value;

  @override
  void initState() {
    super.initState();
    _worker = ever<int>(widget.punchCount, _onCount);
  }

  void _onCount(int count) {
    if (count > _lastCount) {
      HapticFeedback.lightImpact();
      _ctrl.forward(from: 0);
    }
    _lastCount = count;
  }

  @override
  void dispose() {
    _worker.dispose();
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
            painter: _RipplePainter(_ctrl.value),
          ),
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double t;

  _RipplePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final center = size.center(Offset.zero);
    final eased = Curves.easeOutCubic.transform(t);
    final fade = 1 - t;
    final shortest = math.min(size.width, size.height);
    final radius = shortest * (0.12 + 0.55 * eased);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.28 * fade),
            AppColors.primary.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + 10 * fade
        ..color = AppColors.primaryLight.withValues(alpha: 0.85 * fade),
    );
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.t != t;
}
