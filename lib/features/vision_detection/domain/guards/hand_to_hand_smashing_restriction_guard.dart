import 'dart:math';
import '../services/arm_kinetic_tracker.dart';
import 'punch_restriction_guard.dart';

/// Restriction Guard: Rejects candidate punch activation when left and right hands are smashing, clapping, or rubbing together in front of the body.
class HandToHandSmashingRestrictionGuard implements PunchRestrictionGuard {
  @override
  String get name => 'HandToHandSmashingRestrictionGuard';

  @override
  bool evaluate(ArmKineticTracker tracker, PunchDetectionContext context) {
    final history = tracker.history;
    if (history.isEmpty) return true;

    final latest = history.last;
    final double shoulderWidth = context.shoulderWidth;

    // Check if both left and right wrists/hands are present in the recent frame
    if (latest.wrist != null && context.oppositeArmTracker.history.isNotEmpty) {
      final oppositeLatest = context.oppositeArmTracker.history.last;
      if (oppositeLatest.wrist != null) {
        final double wristDistance = sqrt(
          pow(latest.wrist!.dx - oppositeLatest.wrist!.dx, 2) +
              pow(latest.wrist!.dy - oppositeLatest.wrist!.dy, 2),
        );

        // If hands are within 0.38 shoulder width of each other (hand-to-hand smashing/clapping)
        if (wristDistance < shoulderWidth * 0.38) {
          return false; // Hand-to-hand smashing/clapping (Not a punch into bag)
        }
      }
    }

    return true;
  }
}
