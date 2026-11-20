import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/boxer_moves.dart';

/// Animated lesson figure: loops [moveId] (see [BoxerMoves]). Side view,
/// facing right for orthodox and left for southpaw. Moving gloves leave a
/// short fading trail so hooks and uppercuts read clearly.
class BoxerFigure extends StatefulWidget {
  final String moveId;

  /// 1.0 = normal, 0.5 = slow motion.
  final double speed;
  final bool paused;

  /// null = the user's stance setting.
  final bool? southpaw;

  const BoxerFigure({
    super.key,
    required this.moveId,
    this.speed = 1,
    this.paused = false,
    this.southpaw,
  });

  @override
  State<BoxerFigure> createState() => _BoxerFigureState();
}

class _BoxerFigureState extends State<BoxerFigure>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker = AnimationController(
    vsync: this,
    duration: const Duration(days: 1),
  );
  double _ms = 0;
  Duration _last = Duration.zero;

  BoxerMove get _move => BoxerMoves.of(widget.moveId);

  @override
  void initState() {
    super.initState();
    _ticker.addListener(_onTick);
    if (!widget.paused) _ticker.forward();
  }

  void _onTick() {
    final now = _ticker.lastElapsedDuration ?? Duration.zero;
    final dt = (now - _last).inMicroseconds / 1000;
    _last = now;
    setState(() => _ms += dt * widget.speed);
  }

  @override
  void didUpdateWidget(BoxerFigure old) {
    super.didUpdateWidget(old);
    if (old.moveId != widget.moveId) _ms = 0;
    if (widget.paused && _ticker.isAnimating) {
      _ticker.stop();
    } else if (!widget.paused && !_ticker.isAnimating) {
      _last = Duration.zero;
      _ticker.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget paint(bool southpaw) => CustomPaint(
      painter: BoxerPainter(move: _move, ms: _ms.round(), southpaw: southpaw),
      child: const SizedBox.expand(),
    );
    return AspectRatio(
      aspectRatio: 1,
      child: widget.southpaw != null
          ? paint(widget.southpaw!)
          : Obx(() => paint(StorageService.to.southpaw.value)),
    );
  }
}

class BoxerPainter extends CustomPainter {
  final BoxerMove move;
  final int ms;
  final bool southpaw;

  BoxerPainter({required this.move, required this.ms, required this.southpaw});

  static const _trailSteps = 7;
  static const _trailStepMs = 22;

  BoxerPose _pose(int at) {
    final p = move.poseAt(at);
    return southpaw ? p.mirrored() : p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    Offset pt(Offset o) => Offset(o.dx * s, o.dy * s);
    final pose = _pose(ms);
    final limb = s * 0.045;

    // Floor shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0.5 * s, 0.94 * s),
        width: 0.62 * s,
        height: 0.05 * s,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    final rear = Paint()
      ..color = const Color(0xFF6B6B78)
      ..strokeWidth = limb
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final lead = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = limb
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    void line(J a, J b, Paint paint) =>
        canvas.drawLine(pt(pose[a]), pt(pose[b]), paint);

    // Back side first (further from the viewer).
    line(J.hipRear, J.kneeRear, rear);
    line(J.kneeRear, J.ankleRear, rear);
    line(J.shoulderRear, J.elbowRear, rear);
    line(J.elbowRear, J.wristRear, rear);
    _trail(canvas, s, J.wristRear, AppColors.primaryDeep);
    _glove(canvas, pt(pose[J.wristRear]), s, AppColors.primaryDeep);

    // Torso.
    final torso = Path()
      ..moveTo(pt(pose[J.shoulderRear]).dx, pt(pose[J.shoulderRear]).dy)
      ..lineTo(pt(pose[J.shoulderLead]).dx, pt(pose[J.shoulderLead]).dy)
      ..lineTo(pt(pose[J.hipLead]).dx, pt(pose[J.hipLead]).dy)
      ..lineTo(pt(pose[J.hipRear]).dx, pt(pose[J.hipRear]).dy)
      ..close();
    canvas.drawPath(
      torso,
      Paint()
        ..color = AppColors.textPrimary
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      torso,
      Paint()
        ..color = AppColors.textPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = limb * 0.9
        ..strokeJoin = StrokeJoin.round,
    );
    line(J.neck, J.shoulderLead, lead);

    // Shorts band.
    canvas.drawLine(
      pt(pose[J.hipRear]),
      pt(pose[J.hipLead]),
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = limb * 1.3
        ..strokeCap = StrokeCap.round,
    );

    // Front side.
    line(J.hipLead, J.kneeLead, lead);
    line(J.kneeLead, J.ankleLead, lead);
    line(J.shoulderLead, J.elbowLead, lead);
    line(J.elbowLead, J.wristLead, lead);

    // Head.
    final head = pt(pose[J.head]);
    canvas.drawCircle(head, s * 0.062, Paint()..color = AppColors.textPrimary);
    // Eye side shows which way the figure faces.
    final facing = southpaw ? -1 : 1;
    canvas.drawCircle(
      head.translate(facing * s * 0.025, -s * 0.008),
      s * 0.008,
      Paint()..color = AppColors.bg,
    );

    _trail(canvas, s, J.wristLead, AppColors.primary);
    _glove(canvas, pt(pose[J.wristLead]), s, AppColors.primary);
  }

  void _glove(Canvas canvas, Offset c, double s, Color color) {
    canvas.drawCircle(c, s * 0.045, Paint()..color = color);
    canvas.drawCircle(
      c.translate(-s * 0.012, -s * 0.012),
      s * 0.014,
      Paint()..color = Colors.white.withValues(alpha: 0.25),
    );
  }

  /// Fading dots where the glove was a moment ago, only while it moves fast.
  void _trail(Canvas canvas, double s, J wrist, Color color) {
    final now = _pose(ms)[wrist];
    final past = _pose(math.max(0, ms - _trailSteps * _trailStepMs))[wrist];
    if ((now - past).distance < 0.06) return;
    for (var k = _trailSteps; k >= 1; k--) {
      final p = _pose(math.max(0, ms - k * _trailStepMs))[wrist];
      final a = (1 - k / (_trailSteps + 1)) * 0.35;
      canvas.drawCircle(
        Offset(p.dx * s, p.dy * s),
        s * 0.04 * (1 - k / (_trailSteps * 2)),
        Paint()..color = color.withValues(alpha: a),
      );
    }
  }

  @override
  bool shouldRepaint(BoxerPainter old) =>
      old.ms != ms || old.move != move || old.southpaw != southpaw;
}
