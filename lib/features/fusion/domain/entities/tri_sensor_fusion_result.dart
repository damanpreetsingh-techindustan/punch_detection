import 'sensor_signal_state.dart';

/// Strongly typed entity capturing the evaluation result of the Tri-Sensor Matrix.
class TriSensorFusionResult {
  final PunchOutcome outcome;
  final String combinationCode;
  final String reasonLabel;
  final double confidenceScore; // 0.0 to 100.0
  final AudioSignalState audioState;
  final VibrationSignalState vibrationState;
  final CameraSignalState cameraState;
  final int timestampMs;

  const TriSensorFusionResult({
    required this.outcome,
    required this.combinationCode,
    required this.reasonLabel,
    required this.confidenceScore,
    required this.audioState,
    required this.vibrationState,
    required this.cameraState,
    required this.timestampMs,
  });

  bool get isValidPunch => outcome == PunchOutcome.validPunch;
  bool get isCandidate => outcome == PunchOutcome.candidate;
  bool get isNotPunch => outcome == PunchOutcome.notPunch;
  bool get isRejected => isNotPunch;

  String get formattedLogEntry {
    final String icon = isValidPunch ? '🟢' : (isCandidate ? '🟡' : '🔴');
    return '$icon [$combinationCode] $reasonLabel (Audio:${audioState.name}, Vibe:${vibrationState.name}, Cam:${cameraState.name})';
  }
}
