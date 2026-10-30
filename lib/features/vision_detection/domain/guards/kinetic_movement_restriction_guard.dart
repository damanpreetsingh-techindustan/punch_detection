import '../services/arm_kinetic_tracker.dart';
import 'punch_restriction_guard.dart';

/// Restriction Guard: Ensures a punch is ONLY confirmed as valid if there is explicit, valid kinetic movement in either the Shoulder or the Elbow.
/// Rejects static body stances, passive hand movements, or micro-twitches where neither shoulder nor elbow displacement satisfies active movement thresholds.
class KineticMovementRestrictionGuard implements PunchRestrictionGuard {
  @override
  String get name => 'KineticMovementRestrictionGuard';

  @override
  bool evaluate(ArmKineticTracker tracker, PunchDetectionContext context) {
    final history = tracker.history;
    if (history.length < 2) return false;

    final double minShoulderThreshold =
        context.config.minShoulderMovementThreshold; // Default: 0.055 SW
    final double minVelocityThreshold =
        context.config.minWristVelocityThreshold; // Default: 0.35 SW/s

    final bool hasValidShoulderMovement =
        tracker.shoulderMovement >= minShoulderThreshold;
    final bool hasValidElbowMovement =
        (tracker.wristVelocity >= minVelocityThreshold) ||
        (tracker.armExtension >= 0.45);

    // Punch is ONLY valid if explicit kinetic movement is present in either shoulder or elbow
    if (!hasValidShoulderMovement && !hasValidElbowMovement) {
      return false; // Insufficient shoulder or elbow kinetic movement (Static / passive stance)
    }

    return true;
  }
}
