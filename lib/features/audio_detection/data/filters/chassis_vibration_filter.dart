import '../../domain/entities/audio_filter_config.dart';
import '../../domain/entities/audio_frame.dart';
import 'audio_filter_stage.dart';

class ChassisVibrationFilter implements AudioFilterStage {
  @override
  String get name => 'Chassis Vibration Discrimination';

  @override
  FilterStageResult process(
    AudioFrame frame,
    AudioFilterConfig config,
    double currentNoiseFloorRms,
  ) {
    if (frame.pcmBytes.length < 16) {
      return FilterStageResult(
        passed: true,
        stageName: name,
        score: 1.0,
        metrics: {'note': 'Insufficient samples'},
      );
    }

    // High frequency content vs low frequency content ratio
    int highFreqCount = 0;
    int lowFreqCount = 0;

    for (int i = 0; i < frame.pcmBytes.length - 3; i += 4) {
      final int s1 = ((frame.pcmBytes[i + 1] << 8) | (frame.pcmBytes[i] & 0xFF)).toSigned(16);
      final int s2 = ((frame.pcmBytes[i + 3] << 8) | (frame.pcmBytes[i + 2] & 0xFF)).toSigned(16);
      
      final int diff = (s2 - s1).abs();
      if (diff > 4000) {
        highFreqCount++;
      } else {
        lowFreqCount++;
      }
    }

    final double total = (highFreqCount + lowFreqCount).toDouble();
    final double lowRatio = total > 0 ? lowFreqCount / total : 0.5;

    // Plastic mount taps have disproportionately high-frequency click content without low-end acoustic thud
    final bool passed = lowRatio >= config.chassisLowFreqMinRatio;
    final double score = (lowRatio / config.chassisLowFreqMinRatio).clamp(0.0, 1.0);

    return FilterStageResult(
      passed: passed,
      stageName: name,
      score: score,
      metrics: {
        'lowFreqRatio': lowRatio,
        'minLowFreqRatio': config.chassisLowFreqMinRatio,
      },
    );
  }
}
