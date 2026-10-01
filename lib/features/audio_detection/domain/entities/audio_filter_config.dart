import 'package:equatable/equatable.dart';

class AudioFilterConfig extends Equatable {
  final double energyThresholdDelta; // Energy required above noise floor
  final int maxAttackTimeMs;          // Max attack time for impulsive transient (e.g. 15ms)
  final int maxDecayTimeMs;           // Max decay duration for transient (e.g. 120ms)
  final double spectralFlatnessMin;   // Min spectral flatness for wideband impact
  final double proximityGateMinRms;   // Min RMS amplitude for local bag impact
  final double chassisLowFreqMinRatio;// Min low-frequency energy ratio to reject plastic phone taps

  const AudioFilterConfig({
    this.energyThresholdDelta = 0.15,
    this.maxAttackTimeMs = 20,
    this.maxDecayTimeMs = 120,
    this.spectralFlatnessMin = 0.35,
    this.proximityGateMinRms = 0.08,
    this.chassisLowFreqMinRatio = 0.25,
  });

  @override
  List<Object?> get props => [
        energyThresholdDelta,
        maxAttackTimeMs,
        maxDecayTimeMs,
        spectralFlatnessMin,
        proximityGateMinRms,
        chassisLowFreqMinRatio,
      ];
}
