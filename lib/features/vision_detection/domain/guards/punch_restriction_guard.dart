import '../entities/punch_detection_config.dart';
import '../services/arm_kinetic_tracker.dart';

/// Context passed to Restriction Guards containing frame-level evaluation data.
class PunchDetectionContext {
  final double shoulderWidth;
  final String lastConfirmedArm;
  final int timeSinceLastPunchMs;
  final ArmKineticTracker oppositeArmTracker;
  final PunchDetectionConfig config;
  final bool isDeviceStable;

  PunchDetectionContext({
    required this.shoulderWidth,
    required this.lastConfirmedArm,
    required this.timeSinceLastPunchMs,
    required this.oppositeArmTracker,
    required this.config,
    this.isDeviceStable = true,
  });
}

/// Abstract Interface for Punch Restriction Validation (SOLID Open/Closed Principle).
/// Implementations validate single kinetic rules (e.g. extension, retraction, direction).
abstract class PunchRestrictionGuard {
  /// Name identifier for telemetry & debugging.
  String get name;

  /// Validates whether the active arm tracker satisfies this restriction rule.
  /// Returns `true` if valid (passed restriction), `false` if rejected.
  bool evaluate(ArmKineticTracker tracker, PunchDetectionContext context);
}
