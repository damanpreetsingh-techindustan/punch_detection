import '../../domain/entities/audio_filter_config.dart';
import '../../domain/entities/audio_frame.dart';
import 'audio_filter_stage.dart';

class SpectralFlatnessFilter implements AudioFilterStage {
  @override
  String get name => 'Spectral Frequency Width Check';

  @override
  FilterStageResult process(
    AudioFrame frame,
    AudioFilterConfig config,
    double currentNoiseFloorRms,
  ) {
    if (frame.pcmBytes.length < 32) {
      return FilterStageResult(
        passed: false,
        stageName: name,
        score: 0.0,
        metrics: {'error': 'Frame too short'},
      );
    }

    int zeroCrossings = 0;
    int previousSample = 0;
    double energyVariance = 0;
    final double meanRms = frame.rmsEnergy;

    final int totalSamples = frame.pcmBytes.length ~/ 2;
    for (int i = 0; i < frame.pcmBytes.length - 1; i += 2) {
      final int sample = ((frame.pcmBytes[i + 1] << 8) | (frame.pcmBytes[i] & 0xFF)).toSigned(16);
      
      if ((previousSample < 0 && sample >= 0) || (previousSample >= 0 && sample < 0)) {
        zeroCrossings++;
      }
      previousSample = sample;

      final double norm = sample / 32768.0;
      final double diff = norm.abs() - meanRms;
      energyVariance += diff * diff;
    }

    energyVariance = totalSamples > 0 ? energyVariance / totalSamples : 0;
    final double zcrRatio = totalSamples > 0 ? zeroCrossings / totalSamples : 0;

    final bool isWideband = zcrRatio >= 0.08 && energyVariance <= 0.35;
    final double score = isWideband ? 0.90 : 0.30;

    return FilterStageResult(
      passed: isWideband,
      stageName: name,
      score: score,
      metrics: {
        'zeroCrossings': zeroCrossings,
        'zcrRatio': zcrRatio,
        'energyVariance': energyVariance,
        'isWideband': isWideband,
      },
    );
  }
}
