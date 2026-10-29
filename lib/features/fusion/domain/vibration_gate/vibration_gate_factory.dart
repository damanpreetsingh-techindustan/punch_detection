import '../../../../core/utils/constants.dart';
import 'i_vibration_gate.dart';
import 'services/fresh_knock_gate.dart';
import 'services/peak_threshold_gate.dart';
import 'services/vibration_knock_tracker.dart';

/// Factory for instantiating the active [IVibrationGate] based on app configuration (OCP).
class VibrationGateFactory {
  const VibrationGateFactory._();

  static IVibrationGate create({
    VibrationGateType? type,
    double? minKnockDelta,
    int? knockMergeMs,
  }) {
    final effectiveType = type ?? AppConstants.vibrationGateType;
    switch (effectiveType) {
      case VibrationGateType.knock:
        return FreshKnockGate(
          tracker: VibrationKnockTracker(
            minKnockDelta: minKnockDelta ?? AppConstants.knockMinJerk,
            knockMergeMs: knockMergeMs ?? AppConstants.knockMergeMs,
          ),
        );
      case VibrationGateType.peakThreshold:
        return PeakThresholdGate();
    }
  }
}
