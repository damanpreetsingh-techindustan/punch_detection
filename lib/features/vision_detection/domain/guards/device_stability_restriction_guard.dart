import '../../../../core/utils/constants.dart';
import '../services/arm_kinetic_tracker.dart';
import 'punch_restriction_guard.dart';

/// Restriction Guard that rejects pose-based punch activations whenever the camera/device
/// is unstable or held in hand with significant physical motion.
class DeviceStabilityRestrictionGuard implements PunchRestrictionGuard {
  @override
  String get name => 'Device Stability & Motion Guard';

  @override
  bool evaluate(ArmKineticTracker tracker, PunchDetectionContext context) {
    // 1. Check Global Feature Flag & Config Toggle
    if (!AppConstants.enableDeviceStabilityCheck ||
        !context.config.enableDeviceStabilityGuard) {
      return true; // Bypass restriction guard when disabled
    }

    // 2. Check Device Stability State
    return context.isDeviceStable;
  }
}
