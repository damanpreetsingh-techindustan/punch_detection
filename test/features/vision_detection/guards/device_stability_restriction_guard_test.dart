import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/entities/punch_detection_config.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/guards/device_stability_restriction_guard.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/guards/punch_restriction_guard.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/services/arm_kinetic_tracker.dart';

void main() {
  group('DeviceStabilityRestrictionGuard Unit Tests', () {
    late DeviceStabilityRestrictionGuard guard;
    late ArmKineticTracker tracker;

    setUp(() {
      guard = DeviceStabilityRestrictionGuard();
      tracker = ArmKineticTracker(side: 'right');
      AppConstants.enableDeviceStabilityCheck = true;
    });

    test('should PASS when device is stable and guard is enabled', () {
      final context = PunchDetectionContext(
        shoulderWidth: 100.0,
        lastConfirmedArm: 'left',
        timeSinceLastPunchMs: 500,
        oppositeArmTracker: ArmKineticTracker(side: 'left'),
        config: const PunchDetectionConfig(enableDeviceStabilityGuard: true),
        isDeviceStable: true,
      );

      final result = guard.evaluate(tracker, context);
      expect(result, isTrue);
    });

    test('should REJECT (return false) when device is unstable and guard is enabled', () {
      final context = PunchDetectionContext(
        shoulderWidth: 100.0,
        lastConfirmedArm: 'left',
        timeSinceLastPunchMs: 500,
        oppositeArmTracker: ArmKineticTracker(side: 'left'),
        config: const PunchDetectionConfig(enableDeviceStabilityGuard: true),
        isDeviceStable: false,
      );

      final result = guard.evaluate(tracker, context);
      expect(result, isFalse);
    });

    test('should PASS when global AppConstants.enableDeviceStabilityCheck is false', () {
      AppConstants.enableDeviceStabilityCheck = false;

      final context = PunchDetectionContext(
        shoulderWidth: 100.0,
        lastConfirmedArm: 'left',
        timeSinceLastPunchMs: 500,
        oppositeArmTracker: ArmKineticTracker(side: 'left'),
        config: const PunchDetectionConfig(enableDeviceStabilityGuard: true),
        isDeviceStable: false, // device unstable, but global check disabled!
      );

      final result = guard.evaluate(tracker, context);
      expect(result, isTrue);
    });

    test('should PASS when PunchDetectionConfig.enableDeviceStabilityGuard is false', () {
      AppConstants.enableDeviceStabilityCheck = true;

      final context = PunchDetectionContext(
        shoulderWidth: 100.0,
        lastConfirmedArm: 'left',
        timeSinceLastPunchMs: 500,
        oppositeArmTracker: ArmKineticTracker(side: 'left'),
        config: const PunchDetectionConfig(enableDeviceStabilityGuard: false),
        isDeviceStable: false, // device unstable, but config toggle disabled!
      );

      final result = guard.evaluate(tracker, context);
      expect(result, isTrue);
    });
  });
}
