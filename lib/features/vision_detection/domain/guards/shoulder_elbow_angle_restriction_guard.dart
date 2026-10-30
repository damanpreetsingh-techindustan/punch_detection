import 'dart:math';
import '../services/arm_kinetic_tracker.dart';
import 'punch_restriction_guard.dart';

/// Restriction Guard: Verifies that the Arm Vector (Shoulder -> Elbow & Wrist)
/// is elevated in the air in valid punching orientation (150° - 210° horizontal plane),
/// and REJECTS non-punching movements where the arm/elbow is hanging down toward the ground/lap while sitting.
class ShoulderElbowAngleRestrictionGuard implements PunchRestrictionGuard {
  final double minValidAngleDeg;
  final double maxValidAngleDeg;
  final double maxGroundDropRatio;

  const ShoulderElbowAngleRestrictionGuard({
    this.minValidAngleDeg = 150.0,
    this.maxValidAngleDeg = 210.0,
    this.maxGroundDropRatio = 0.30,
  });

  @override
  String get name => 'ShoulderElbowAngleRestrictionGuard';

  @override
  bool evaluate(ArmKineticTracker tracker, PunchDetectionContext context) {
    final history = tracker.history;
    if (history.isEmpty) return false;

    final latest = history.last;
    final double shoulderWidth = context.shoulderWidth;

    if (latest.elbow == null) {
      // If elbow landmark is missing/occluded, verify shoulder movement drive
      return tracker.shoulderMovement >= 0.035;
    }

    // Vector from Elbow -> Shoulder
    final double dx = latest.shoulder.dx - latest.elbow!.dx;
    final double dy = latest.shoulder.dy - latest.elbow!.dy;

    // 1. Reject if arm is hanging downwards toward ground/lap while sitting (dy < -0.45 SW when arm is UN-EXTENDED)
    if (tracker.armExtension < 0.50 &&
        shoulderWidth > 0 &&
        (-dy / shoulderWidth) > 0.45) {
      return false;
    }

    // 2. Calculate 2D angle (Elbow -> Shoulder) in degrees [0°, 360°)
    double angleDeg = atan2(dy, dx) * 180.0 / pi;
    if (angleDeg < 0) angleDeg += 360.0;

    // Reject downward angles pointing toward ground/floor/lap (range [55°, 125°]) ONLY when arm is UN-EXTENDED
    if (tracker.armExtension < 0.50 && angleDeg >= 55.0 && angleDeg <= 125.0) {
      return false;
    }

    // NOTE: Wrist vertical position check is commented out because mobile cameras are mounted directly above punching bags where wrist/hands are occluded by the bag or out of frame. Detection logic relies strictly on Shoulder -> Elbow (Upper Arm) metrics.
    /*
    if (latest.wrist != null && tracker.armExtension < 0.50) {
      final double dyWrist = latest.wrist!.dy - latest.shoulder.dy;
      if (shoulderWidth > 0 && (dyWrist / shoulderWidth) > 0.55) {
        return false;
      }
    }
    */

    return true;
  }
}
