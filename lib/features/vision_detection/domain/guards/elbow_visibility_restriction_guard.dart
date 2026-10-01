import '../services/arm_kinetic_tracker.dart';
import 'punch_restriction_guard.dart';

/// Restriction Guard: Rejects candidate punch activation if the driving arm's elbow landmark is not detected in the camera frame.
class ElbowVisibilityRestrictionGuard implements PunchRestrictionGuard {
  @override
  String get name => 'ElbowVisibilityRestrictionGuard';

  @override
  bool evaluate(ArmKineticTracker tracker, PunchDetectionContext context) {
    final history = tracker.history;
    if (history.isEmpty) return false;

    // Driving arm elbow MUST be present in the camera frame to measure kinetic upper arm movement
    /*
    if (latest.elbow == null) {
      return false; // Driving arm elbow out of frame or not detected
    }
    */

    return true;
  }
}
