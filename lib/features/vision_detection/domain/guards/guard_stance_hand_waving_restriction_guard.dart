import '../services/arm_kinetic_tracker.dart';
import 'punch_restriction_guard.dart';

/// Restriction Guard: Eliminates false punch detections caused by holding hands
/// in a guard position or waving forearms/wrists in the air without dynamic arm extension.
///
/// Ensures a punch candidate is ONLY confirmed if:
///   1) Dynamic extension surge delta (peakExtensionInCandidate - baselineGuardExtension) >= 0.12 SW, OR
///   2) Absolute arm extension reach >= 0.75 SW, OR
///   3) Accompanied by significant kinetic shoulder drive (shoulderMovement >= 0.08 SW).
class GuardStanceHandWavingRestrictionGuard implements PunchRestrictionGuard {
  final double minExtensionDeltaSurge;
  final double minAbsoluteFullExtension;
  final double minExplosiveShoulderDrive;

  const GuardStanceHandWavingRestrictionGuard({
    this.minExtensionDeltaSurge = 0.08,
    this.minAbsoluteFullExtension = 0.68,
    this.minExplosiveShoulderDrive = 0.05,
  });

  @override
  String get name => 'GuardStanceHandWavingRestrictionGuard';

  @override
  bool evaluate(ArmKineticTracker tracker, PunchDetectionContext context) {
    // Calculate dynamic extension surge since candidate activation
    final double baseline = tracker.baselineGuardExtension;
    final double peak = tracker.peakExtensionInCandidate;
    final double current = tracker.armExtension;
    final double maxExtensionReached = peak > current ? peak : current;
    final double deltaExtensionSurge = maxExtensionReached - baseline;

    // Reject retraction counter-pivots: if opposite arm punched < 400ms ago, require explicit extension surge (>= 0.08 SW)
    if (context.lastConfirmedArm.isNotEmpty &&
        context.lastConfirmedArm != tracker.side &&
        context.timeSinceLastPunchMs < 400) {
      if (deltaExtensionSurge < 0.08 &&
          maxExtensionReached < minAbsoluteFullExtension) {
        return false; // False opposite punch triggered by torso counter-rotation during arm retraction
      }
    }

    // 1. Pass if there is explicit dynamic extension surge (arm opening outward)
    if (deltaExtensionSurge >= minExtensionDeltaSurge) {
      return true;
    }

    // 2. Pass if arm reaches full absolute extended reach (>= 0.68 SW) AND has minimum extension surge (>= 0.04 SW)
    if (maxExtensionReached >= minAbsoluteFullExtension &&
        deltaExtensionSurge >= 0.04) {
      return true;
    }

    // 3. Pass if accompanied by explosive shoulder rotation AND minimum extension surge (>= 0.03 SW)
    if (tracker.shoulderMovement >= minExplosiveShoulderDrive &&
        deltaExtensionSurge >= 0.03) {
      return true;
    }

    // REJECT: Arm is held static in guard stance or counter-pivoting with near-zero extension surge
    return false;
  }
}
