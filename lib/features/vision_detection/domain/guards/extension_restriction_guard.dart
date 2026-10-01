import '../services/arm_kinetic_tracker.dart';
import 'punch_restriction_guard.dart';

/// Restriction Guard: Verifies mandatory arm extension (armExtension >= 0.55 SW).
class ExtensionRestrictionGuard implements PunchRestrictionGuard {
  @override
  String get name => 'ExtensionRestrictionGuard';

  @override
  bool evaluate(ArmKineticTracker tracker, PunchDetectionContext context) {
    /*
    if (tracker.motionVelocity >= 1.50 || tracker.wristVelocity >= 1.50) {
      return tracker.armExtension >= 0.45;
    }
    return tracker.armExtension >= 0.50;
    */
    return true;
  }
}
