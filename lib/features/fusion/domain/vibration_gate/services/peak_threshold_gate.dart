import '../../services/impact_gate_evaluator.dart';
import '../i_vibration_gate.dart';
import '../models/vibration_gate_evaluation.dart';

class _EnvelopeSample {
  final int tMs;
  final double mag;
  const _EnvelopeSample(this.tMs, this.mag);
}

/// Legacy vibration gate implementing the peak envelope threshold rule.
///
/// Encapsulates the historical threshold check for backward compatibility and
/// A/B benchmarking.
class PeakThresholdGate implements IVibrationGate {
  final List<_EnvelopeSample> _samples = [];
  final int maxHistoryMs;

  PeakThresholdGate({this.maxHistoryMs = 2000});

  @override
  String get name => 'PeakThresholdGate';

  @override
  void addRawSample({
    required int sensorMs,
    required double rawMag,
    double? rawX,
    double? rawY,
    double? rawZ,
  }) {
    // Legacy gate operates on envelope samples, but can also record raw peak if envelope is absent.
  }

  @override
  void addEnvelopeSample({
    required int arrivalMs,
    required double magnitude,
  }) {
    _samples.add(_EnvelopeSample(arrivalMs, magnitude));
    final cutoff = arrivalMs - maxHistoryMs;
    while (_samples.isNotEmpty && _samples.first.tMs < cutoff) {
      _samples.removeAt(0);
    }
  }

  @override
  VibrationGateEvaluation evaluate({
    required int audioTsMs,
    required int fromMs,
    required int toMs,
    required double threshold,
    required bool windowClosed,
    required bool isVibrationDisabled,
  }) {
    if (isVibrationDisabled) {
      return const VibrationGateEvaluation(
        state: VibrationGateState.notRequired,
        detail: 'Vibration not required (Pole mount or gate off)',
      );
    }

    double peak = 0.0;
    int peakAtMs = 0;
    for (final sample in _samples) {
      if (sample.tMs >= fromMs && sample.tMs <= toMs) {
        if (sample.mag > peak) {
          peak = sample.mag;
          peakAtMs = sample.tMs;
        }
      }
    }

    if (peak >= threshold) {
      return VibrationGateEvaluation(
        state: VibrationGateState.present,
        peakMagnitude: peak,
        detail:
            'Peak vibration verified: ${peak.toStringAsFixed(2)} m/s² >= ${threshold.toStringAsFixed(2)} m/s² @ ${peakAtMs}ms',
      );
    }

    return VibrationGateEvaluation(
      state: VibrationGateState.missing,
      peakMagnitude: peak,
      detail: windowClosed
          ? 'Peak ${peak.toStringAsFixed(2)} < threshold ${threshold.toStringAsFixed(2)} m/s²'
          : 'Waiting for vibration in window...',
    );
  }

  @override
  void onPunchConfirmed({required int audioTsMs, required int punchNo}) {}

  @override
  void onImpactRejected({required int audioTsMs}) {}

  @override
  void reset() {
    _samples.clear();
  }
}
