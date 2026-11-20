import 'package:flutter/animation.dart';

/// Joints of the lesson figure (side view, facing right = orthodox).
/// "Lead" is the side nearer the target.
enum J {
  head,
  neck,
  shoulderLead,
  shoulderRear,
  elbowLead,
  elbowRear,
  wristLead,
  wristRear,
  hipLead,
  hipRear,
  kneeLead,
  kneeRear,
  ankleLead,
  ankleRear,
}

/// A body position: every joint as a point in a 1 × 1 box (x right, y down).
class BoxerPose {
  final Map<J, Offset> p;

  const BoxerPose(this.p);

  Offset operator [](J j) => p[j]!;

  BoxerPose withJoints(Map<J, Offset> changes) => BoxerPose({...p, ...changes});

  /// Whole body moved (footwork).
  BoxerPose shift(double dx, [double dy = 0]) =>
      BoxerPose({for (final e in p.entries) e.key: e.value.translate(dx, dy)});

  /// Upper body lowered (knee bend) by [dy], feet stay on the floor.
  BoxerPose dip(double dy) => BoxerPose({
    for (final e in p.entries)
      e.key: e.key == J.ankleLead || e.key == J.ankleRear
          ? e.value
          : e.key == J.kneeLead || e.key == J.kneeRear
          ? e.value.translate(0, dy * 0.5)
          : e.value.translate(0, dy),
  });

  /// Southpaw faces the other way.
  BoxerPose mirrored() => BoxerPose({
    for (final e in p.entries) e.key: Offset(1 - e.value.dx, e.value.dy),
  });

  static BoxerPose lerp(BoxerPose a, BoxerPose b, double t) =>
      BoxerPose({for (final j in J.values) j: Offset.lerp(a[j], b[j], t)!});
}

/// One step of a move: blend into [pose] over [ms], then hold [holdMs].
class Keyframe {
  final BoxerPose pose;
  final int ms;
  final int holdMs;
  final Curve curve;

  const Keyframe(
    this.pose, {
    this.ms = 300,
    this.holdMs = 0,
    this.curve = Curves.easeInOutCubic,
  });
}

/// A looping animation: starts and ends on its first pose.
class BoxerMove {
  final String id;
  final List<Keyframe> frames;

  const BoxerMove(this.id, this.frames);

  int get durationMs => frames.fold(0, (s, f) => s + f.ms + f.holdMs);

  /// Pose at [ms] into the loop.
  BoxerPose poseAt(int ms) {
    final total = durationMs;
    if (total <= 0) return frames.first.pose;
    var t = ms % total;
    var prev = frames.last.pose;
    for (final f in frames) {
      if (t < f.ms) {
        return BoxerPose.lerp(prev, f.pose, f.curve.transform(t / f.ms));
      }
      t -= f.ms;
      if (t < f.holdMs) return f.pose;
      t -= f.holdMs;
      prev = f.pose;
    }
    return frames.last.pose;
  }
}

/// The poses and moves used by the Learn lessons.
class BoxerMoves {
  static const BoxerPose guard = BoxerPose({
    J.head: Offset(0.52, 0.17),
    J.neck: Offset(0.50, 0.26),
    J.shoulderLead: Offset(0.53, 0.29),
    J.shoulderRear: Offset(0.46, 0.30),
    J.elbowLead: Offset(0.59, 0.41),
    J.elbowRear: Offset(0.51, 0.42),
    J.wristLead: Offset(0.63, 0.25),
    J.wristRear: Offset(0.57, 0.23),
    J.hipLead: Offset(0.51, 0.56),
    J.hipRear: Offset(0.45, 0.56),
    J.kneeLead: Offset(0.61, 0.73),
    J.kneeRear: Offset(0.40, 0.74),
    J.ankleLead: Offset(0.67, 0.92),
    J.ankleRear: Offset(0.31, 0.92),
  });

  static final BoxerPose jab = guard.withJoints({
    J.head: const Offset(0.53, 0.17),
    J.shoulderLead: const Offset(0.56, 0.28),
    J.elbowLead: const Offset(0.73, 0.28),
    J.wristLead: const Offset(0.89, 0.27),
  });

  static final BoxerPose cross = guard.withJoints({
    J.head: const Offset(0.56, 0.17),
    J.neck: const Offset(0.53, 0.26),
    J.shoulderLead: const Offset(0.52, 0.29),
    J.shoulderRear: const Offset(0.58, 0.28),
    J.elbowRear: const Offset(0.74, 0.28),
    J.wristRear: const Offset(0.90, 0.26),
    J.elbowLead: const Offset(0.57, 0.41),
    J.wristLead: const Offset(0.60, 0.25),
    J.hipRear: const Offset(0.50, 0.56),
    J.kneeRear: const Offset(0.43, 0.73),
    J.ankleRear: const Offset(0.32, 0.91),
  });

  static final BoxerPose leadHook = guard.withJoints({
    J.head: const Offset(0.50, 0.17),
    J.shoulderLead: const Offset(0.55, 0.29),
    J.elbowLead: const Offset(0.70, 0.29),
    J.wristLead: const Offset(0.75, 0.22),
    J.hipLead: const Offset(0.50, 0.56),
    J.kneeLead: const Offset(0.60, 0.73),
  });

  static final BoxerPose rearHook = guard.withJoints({
    J.head: const Offset(0.55, 0.17),
    J.neck: const Offset(0.52, 0.26),
    J.shoulderRear: const Offset(0.56, 0.29),
    J.elbowRear: const Offset(0.70, 0.28),
    J.wristRear: const Offset(0.76, 0.21),
    J.hipRear: const Offset(0.49, 0.56),
    J.kneeRear: const Offset(0.43, 0.73),
  });

  static final BoxerPose leadUpper = guard.withJoints({
    J.head: const Offset(0.53, 0.16),
    J.elbowLead: const Offset(0.64, 0.36),
    J.wristLead: const Offset(0.70, 0.17),
  });

  static final BoxerPose rearUpper = guard.withJoints({
    J.head: const Offset(0.54, 0.16),
    J.shoulderRear: const Offset(0.53, 0.29),
    J.elbowRear: const Offset(0.61, 0.37),
    J.wristRear: const Offset(0.68, 0.16),
    J.hipRear: const Offset(0.48, 0.56),
  });

  static final BoxerPose block = guard.withJoints({
    J.elbowLead: const Offset(0.58, 0.32),
    J.wristLead: const Offset(0.60, 0.13),
    J.elbowRear: const Offset(0.53, 0.33),
    J.wristRear: const Offset(0.57, 0.13),
  });

  static final BoxerPose slip = guard.dip(0.04).withJoints({
    J.head: const Offset(0.58, 0.22),
    J.neck: const Offset(0.54, 0.30),
  });

  static final BoxerPose rollLow = guard.dip(0.10).withJoints({
    J.head: const Offset(0.50, 0.30),
  });

  static final List<Keyframe> _bounce = [
    Keyframe(guard, ms: 350),
    Keyframe(guard.dip(0.012), ms: 350),
  ];

  static Keyframe _punch(BoxerPose p) =>
      Keyframe(p, ms: 170, holdMs: 120, curve: Curves.easeOutCubic);
  static Keyframe _back({int hold = 600}) =>
      Keyframe(guard, ms: 260, holdMs: hold, curve: Curves.easeInOut);

  static final Map<String, BoxerMove> all = {
    'stance': BoxerMove('stance', _bounce),
    'step': BoxerMove('step', [
      Keyframe(guard, ms: 300, holdMs: 400),
      // Step forward: lead foot first, then the rear foot follows.
      Keyframe(
        guard.withJoints({
          J.ankleLead: const Offset(0.77, 0.92),
          J.kneeLead: const Offset(0.68, 0.73),
        }),
        ms: 250,
      ),
      Keyframe(guard.shift(0.10), ms: 250, holdMs: 400),
      // Step back: rear foot first, then the lead foot.
      Keyframe(
        guard.shift(0.10).withJoints({
          J.ankleRear: const Offset(0.31, 0.92),
          J.kneeRear: const Offset(0.45, 0.74),
        }),
        ms: 250,
      ),
      Keyframe(guard, ms: 250, holdMs: 200),
    ]),
    'jab': BoxerMove('jab', [
      Keyframe(guard, holdMs: 500),
      _punch(jab),
      _back(),
    ]),
    'cross': BoxerMove('cross', [
      Keyframe(guard, holdMs: 500),
      _punch(cross),
      _back(),
    ]),
    'one_two': BoxerMove('one_two', [
      Keyframe(guard, holdMs: 500),
      _punch(jab),
      Keyframe(guard, ms: 150),
      _punch(cross),
      _back(hold: 700),
    ]),
    'lead_hook': BoxerMove('lead_hook', [
      Keyframe(guard, holdMs: 500),
      Keyframe(leadHook, ms: 220, holdMs: 120, curve: Curves.easeOutCubic),
      _back(),
    ]),
    'rear_hook': BoxerMove('rear_hook', [
      Keyframe(guard, holdMs: 500),
      Keyframe(rearHook, ms: 220, holdMs: 120, curve: Curves.easeOutCubic),
      _back(),
    ]),
    'uppercuts': BoxerMove('uppercuts', [
      Keyframe(guard, holdMs: 400),
      Keyframe(guard.dip(0.04), ms: 200),
      Keyframe(leadUpper, ms: 200, holdMs: 120, curve: Curves.easeOutCubic),
      Keyframe(guard, ms: 250, holdMs: 300),
      Keyframe(guard.dip(0.04), ms: 200),
      Keyframe(rearUpper, ms: 200, holdMs: 120, curve: Curves.easeOutCubic),
      _back(),
    ]),
    'defense': BoxerMove('defense', [
      Keyframe(guard, holdMs: 400),
      Keyframe(block, ms: 200, holdMs: 400),
      Keyframe(guard, ms: 250, holdMs: 300),
      Keyframe(slip, ms: 220, holdMs: 300),
      Keyframe(guard, ms: 250, holdMs: 300),
      Keyframe(guard.dip(0.06), ms: 220),
      Keyframe(rollLow, ms: 220),
      Keyframe(
        guard.dip(0.04).withJoints({J.head: const Offset(0.56, 0.24)}),
        ms: 220,
      ),
      _back(hold: 500),
    ]),
    'combo': BoxerMove('combo', [
      Keyframe(guard, holdMs: 400),
      _punch(jab),
      Keyframe(guard, ms: 140),
      _punch(cross),
      Keyframe(guard, ms: 160),
      Keyframe(leadHook, ms: 220, holdMs: 120, curve: Curves.easeOutCubic),
      _back(hold: 800),
    ]),
  };

  static BoxerMove of(String id) => all[id] ?? all['stance']!;
}
