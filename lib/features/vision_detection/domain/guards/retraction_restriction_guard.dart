import '../services/arm_kinetic_tracker.dart';
import 'punch_restriction_guard.dart';

/// Restriction Guard: Verifies physical arm retraction before re-arming for a new punch.
class RetractionRestrictionGuard implements PunchRestrictionGuard {
  @override
  String get name => 'RetractionRestrictionGuard';

  @override
  bool evaluate(ArmKineticTracker tracker, PunchDetectionContext context) {
    if (tracker.hasRetractedSinceLastPunch ||
        context.timeSinceLastPunchMs > 250 ||
        tracker.shoulderMovement <= 0.025) {
      return true;
    }
    return false;
  }
}
