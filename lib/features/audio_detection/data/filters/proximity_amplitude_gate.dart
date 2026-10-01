import '../../domain/entities/audio_filter_config.dart';
import '../../domain/entities/audio_frame.dart';
import 'audio_filter_stage.dart';

class ProximityAmplitudeGate implements AudioFilterStage {
  @override
  String get name => 'Proximity Amplitude Gate';

  @override
  FilterStageResult process(
    AudioFrame frame,
    AudioFilterConfig config,
    double currentNoiseFloorRms,
  ) {
    final double peak = frame.peakAmplitude;
    final double rms = frame.rmsEnergy;

    // Distant bags (>3m) produce peak amplitudes below local bracket threshold
    final bool passed = peak >= config.proximityGateMinRms && rms >= (config.proximityGateMinRms * 0.5);
    final double score = (peak / config.proximityGateMinRms).clamp(0.0, 1.0);

    return FilterStageResult(
      passed: passed,
      stageName: name,
      score: score,
      metrics: {
        'peakAmplitude': peak,
        'rmsEnergy': rms,
        'minRequiredRms': config.proximityGateMinRms,
      },
    );
  }
}
