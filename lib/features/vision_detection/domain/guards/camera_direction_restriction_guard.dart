import '../services/arm_kinetic_tracker.dart';
import 'punch_restriction_guard.dart';

/// Restriction Guard: Verifies that Arm & Shoulder extend forward toward camera,
/// rejecting downward movements toward waist, lap, or floor.
class CameraDirectionRestrictionGuard implements PunchRestrictionGuard {
  @override
  String get name => 'CameraDirectionRestrictionGuard';

  @override
  bool evaluate(ArmKineticTracker tracker, PunchDetectionContext context) {
    if (tracker.armExtension < 0.45) return false;

    final history = tracker.history;
    if (history.isEmpty) return false;

    final latest = history.last;
    final double shoulderWidth = context.shoulderWidth;

    // NOTE: Wrist vertical drop check is commented out because mobile cameras are mounted directly above punching bags where wrist/hands are occluded by the bag or out of frame. Detection logic relies strictly on Shoulder -> Elbow (Upper Arm) metrics.
    /*
    if (latest.wrist != null) {
      final double dyWrist = latest.wrist!.dy - latest.shoulder.dy;
      if (dyWrist > shoulderWidth * 0.85) {
        return false;
      }
    }
    */

    // Check Elbow vertical drop (allow natural elbow drop up to 0.95 SW during punch extension)
    if (latest.elbow != null) {
      final double dyElbow = latest.elbow!.dy - latest.shoulder.dy;
      if (dyElbow > shoulderWidth * 0.95) {
        return false;
      }
    }

    final bool hasMovement =
        tracker.shoulderMovement >= 0.025 ||
        tracker.wristVelocity >= 0.40 ||
        tracker.motionVelocity >= 0.40 ||
        tracker.armExtension >= 0.45;
    return hasMovement;
  }
}
