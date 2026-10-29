import '../../services/impact_gate_evaluator.dart';
import 'vibration_knock.dart';

/// Structured result of evaluating a vibration window for punch confirmation.
class VibrationGateEvaluation {
  /// Tri-state outcome aligned with [ImpactGateEvaluator].
  final VibrationGateState state;

  /// The specific knock matching the impact window, if verified.
  final VibrationKnock? matchedKnock;

  /// Peak magnitude in the window (for logging and telemetry).
  final double peakMagnitude;

  /// Diagnostic detail string for telemetry logs and developer console.
  final String detail;

  const VibrationGateEvaluation({
    required this.state,
    this.matchedKnock,
    this.peakMagnitude = 0.0,
    this.detail = '',
  });

  bool get isPresent => state == VibrationGateState.present;
  bool get isMissing => state == VibrationGateState.missing;
  bool get isNotRequired => state == VibrationGateState.notRequired;
}
