import 'models/vibration_gate_evaluation.dart';

/// Abstract contract for vibration gating strategies (DIP & ISP).
///
/// Implementations determine whether physical vibration validates an impact window
/// created by an acoustic spike.
abstract class IVibrationGate {
  /// Descriptive name of the gating strategy (e.g. 'FreshKnockGate', 'PeakThresholdGate').
  String get name;

  /// Evaluates whether physical vibration validates an impact whose acoustic spike occurred at [audioTsMs].
  ///
  /// [audioTsMs]: Timestamp of the acoustic strike in milliseconds.
  /// [fromMs]: Start of the coincidence window (e.g. audioTsMs - impactVibrationBeforeMs).
  /// [toMs]: End of the coincidence window (e.g. audioTsMs + impactVibrationAfterMs).
  /// [threshold]: Configured vibration sensitivity threshold.
  /// [windowClosed]: True when the full impact window duration has elapsed.
  /// [isVibrationDisabled]: True if the vibration gate is bypassed (pole mount or toggle off).
  VibrationGateEvaluation evaluate({
    required int audioTsMs,
    required int fromMs,
    required int toMs,
    required double threshold,
    required bool windowClosed,
    required bool isVibrationDisabled,
  });

  /// Ingests a raw accelerometer sample (before deadband) with optional 3D axes.
  void addRawSample({
    required int sensorMs,
    required double rawMag,
    double? rawX,
    double? rawY,
    double? rawZ,
  });

  /// Ingests a processed envelope magnitude sample (for legacy/fallback rules).
  void addEnvelopeSample({
    required int arrivalMs,
    required double magnitude,
  });

  /// Permanently consumes the knock associated with [audioTsMs] upon punch confirmation.
  void onPunchConfirmed({
    required int audioTsMs,
    required int punchNo,
  });

  /// Releases any temporary knock claim if an impact window ended in rejection.
  void onImpactRejected({required int audioTsMs});

  /// Resets internal buffers and state between sessions.
  void reset();
}
