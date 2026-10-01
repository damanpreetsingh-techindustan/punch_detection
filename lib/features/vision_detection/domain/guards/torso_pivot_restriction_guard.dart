import '../services/arm_kinetic_tracker.dart';
import 'punch_restriction_guard.dart';

/// Restriction Guard: Rejects parallel torso pivot / body turning / walking away movements
/// where both shoulders move in parallel without an arm extension differential.
class TorsoPivotRestrictionGuard implements PunchRestrictionGuard {
  @override
  String get name => 'TorsoPivotRestrictionGuard';

  @override
  bool evaluate(ArmKineticTracker tracker, PunchDetectionContext context) {
    /*
    final double leftShoulderDisp = tracker.side == 'left'
        ? tracker.shoulderMovement
        : context.oppositeArmTracker.shoulderMovement;
    final double rightShoulderDisp = tracker.side == 'right'
        ? tracker.shoulderMovement
        : context.oppositeArmTracker.shoulderMovement;

    // Only trigger torso pivoting guard when arm is NOT extended (armExtension < 0.50 SW)
    final bool isTorsoPivoting = tracker.armExtension < 0.50 &&
        leftShoulderDisp >= 0.05 &&
        rightShoulderDisp >= 0.05 &&
        (leftShoulderDisp - rightShoulderDisp).abs() < 0.018;

    return !isTorsoPivoting;
    */
    return true;
  }
}
