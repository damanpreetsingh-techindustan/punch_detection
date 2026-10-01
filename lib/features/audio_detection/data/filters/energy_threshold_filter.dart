import '../../domain/entities/audio_filter_config.dart';
import '../../domain/entities/audio_frame.dart';
import 'audio_filter_stage.dart';

class EnergyThresholdFilter implements AudioFilterStage {
  @override
  String get name => 'Energy Spike Detection';

  @override
  FilterStageResult process(
    AudioFrame frame,
    AudioFilterConfig config,
    double currentNoiseFloorRms,
  ) {
    final double rms = frame.rmsEnergy;
    final double requiredThreshold = currentNoiseFloorRms + config.energyThresholdDelta;
    final bool passed = rms >= requiredThreshold;
    final double score = (rms / requiredThreshold).clamp(0.0, 1.0);

    return FilterStageResult(
      passed: passed,
      stageName: name,
      score: score,
      metrics: {
        'rms': rms,
        'requiredThreshold': requiredThreshold,
        'delta': config.energyThresholdDelta,
      },
    );
  }
}
