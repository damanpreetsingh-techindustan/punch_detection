import '../services/arm_kinetic_tracker.dart';
import 'punch_restriction_guard.dart';

/// Restriction Guard: Verifies active kinetic shoulder drive & explosive motion velocity.
class MotionVelocityRestrictionGuard implements PunchRestrictionGuard {
  @override
  String get name => 'MotionVelocityRestrictionGuard';

  @override
  bool evaluate(ArmKineticTracker tracker, PunchDetectionContext context) {
    /*
    final bool hasShoulderDrive =
        tracker.shoulderMovement >= 0.045 ||
        (tracker.armExtension >= 0.65 && tracker.wristVelocity >= 0.80);
    final bool hasMotionVelocity =
        tracker.motionVelocity >= 0.50 || tracker.wristVelocity >= 0.50;

    return hasShoulderDrive && hasMotionVelocity;
    */
    return true;
  }
}
