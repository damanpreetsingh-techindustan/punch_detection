import '../services/arm_kinetic_tracker.dart';
import 'device_stability_restriction_guard.dart';
import 'punch_restriction_guard.dart';

/*
   import 'camera_direction_restriction_guard.dart';
   import 'elbow_visibility_restriction_guard.dart';
   import 'extension_restriction_guard.dart';
   import 'guard_stance_hand_waving_restriction_guard.dart';
   import 'kinetic_movement_restriction_guard.dart';
   import 'motion_velocity_restriction_guard.dart';
   import 'retraction_restriction_guard.dart';
   import 'shoulder_elbow_angle_restriction_guard.dart';
*/
/// Result of evaluating the Restriction Guard Pipeline.
class GuardPipelineResult {
  final bool isPassed;
  final String? failedGuardName;

  const GuardPipelineResult({required this.isPassed, this.failedGuardName});
}

/// Composite Pipeline for Punch Restriction Validation (SOLID Open/Closed & Single Responsibility).
/// Aggregates and executes a collection of active restriction guards.
class RestrictionGuardPipeline {
  final List<PunchRestrictionGuard> _guards = [];

  RestrictionGuardPipeline({List<PunchRestrictionGuard>? guards}) {
    if (guards != null) {
      _guards.addAll(guards);
    } else {
      // Default Active Guards Suite:
      // Device Stability Guard (Rejects handheld shaking/camera motion via sensors_plus)
      _guards.addAll([
        DeviceStabilityRestrictionGuard(),
      ]);
    }
  }

  List<PunchRestrictionGuard> get guards => List.unmodifiable(_guards);

  /// Dynamically registers a new restriction guard into the pipeline.
  void addGuard(PunchRestrictionGuard guard) {
    _guards.add(guard);
  }

  /// Removes a restriction guard by type or name.
  void removeGuardByName(String guardName) {
    _guards.removeWhere((g) => g.name == guardName);
  }

  /// Evaluates all active restriction guards in sequence.
  GuardPipelineResult verifyAllGuards(
    ArmKineticTracker tracker,
    PunchDetectionContext context,
  ) {
    for (final guard in _guards) {
      final bool isValid = guard.evaluate(tracker, context);
      if (!isValid) {
        return GuardPipelineResult(
          isPassed: false,
          failedGuardName: guard.name,
        );
      }
    }
    return const GuardPipelineResult(isPassed: true);
  }
}
