import '../services/arm_kinetic_tracker.dart';
import 'punch_restriction_guard.dart';

/// Restriction Guard: Rejects frames where hand/wrist is touching nose, mouth, eyes, or head.
class HandOnFaceRestrictionGuard implements PunchRestrictionGuard {
  @override
  String get name => 'HandOnFaceRestrictionGuard';

  @override
  bool evaluate(ArmKineticTracker tracker, PunchDetectionContext context) {
    // NOTE: Wrist to face check is commented out because mobile cameras are mounted directly above punching bags where wrist/hands are occluded or out of frame. 
    // Detection logic relies strictly on Shoulder -> Elbow (Upper Arm) metrics.
    /*
    final history = tracker.history;
    if (history.isEmpty) return true;

    final latest = history.last;
    final double shoulderWidth = context.shoulderWidth;

    if (latest.head != null && latest.wrist != null) {
      final double dxNose = (latest.wrist!.dx - latest.head!.dx).abs();
      final double dyNose = (latest.wrist!.dy - latest.head!.dy).abs();
      if (dxNose < shoulderWidth * 0.40 && dyNose < shoulderWidth * 0.42) {
        return false; // Hand touching mouth/face/head (Not a punch)
      }
    }
    */

    return true;
  }
}
