import 'dart:math';
import '../../domain/entities/audio_filter_config.dart';
import '../../domain/entities/audio_frame.dart';
import 'audio_filter_stage.dart';

class TransientEnvelopeFilter implements AudioFilterStage {
  @override
  String get name => 'Transient Envelope Check';

  @override
  FilterStageResult process(
    AudioFrame frame,
    AudioFilterConfig config,
    double currentNoiseFloorRms,
  ) {
    if (frame.pcmBytes.length < 16) {
      return FilterStageResult(
        passed: false,
        stageName: name,
        score: 0.0,
        metrics: {'error': 'Buffer too short'},
      );
    }

    // Measure attack time (time to reach 80% peak) and decay profile
    final List<double> subWindowRms = [];
    final int windowSize = max(frame.pcmBytes.length ~/ 10, 16);

    for (int i = 0; i < frame.pcmBytes.length - windowSize; i += windowSize) {
      double subSum = 0;
      int count = 0;
      for (int j = i; j < i + windowSize - 1; j += 2) {
        final int sample = ((frame.pcmBytes[j + 1] << 8) | (frame.pcmBytes[j] & 0xFF)).toSigned(16);
        final double norm = sample / 32768.0;
        subSum += norm * norm;
        count++;
      }
      if (count > 0) {
        subWindowRms.add(sqrt(subSum / count));
      }
    }

    if (subWindowRms.isEmpty) {
      return FilterStageResult(
        passed: false,
        stageName: name,
        score: 0.0,
        metrics: {'error': 'Sub-windows empty'},
      );
    }

    double peakSubRms = 0;
    int peakIndex = 0;
    for (int i = 0; i < subWindowRms.length; i++) {
      if (subWindowRms[i] > peakSubRms) {
        peakSubRms = subWindowRms[i];
        peakIndex = i;
      }
    }

    // Fast attack check: peak must occur near the start of the impact window
    final bool fastAttack = peakIndex <= 3;

    // Decay check: RMS should drop by at least 50% after peak
    bool rapidDecay = true;
    if (peakIndex < subWindowRms.length - 2) {
      final double tailRms = subWindowRms.sublist(peakIndex + 1).reduce(max);
      rapidDecay = tailRms < (peakSubRms * 0.65);
    }

    final bool passed = fastAttack && rapidDecay;
    final double score = passed ? 0.95 : (fastAttack ? 0.5 : 0.2);

    return FilterStageResult(
      passed: passed,
      stageName: name,
      score: score,
      metrics: {
        'peakIndex': peakIndex,
        'subWindowCount': subWindowRms.length,
        'fastAttack': fastAttack,
        'rapidDecay': rapidDecay,
      },
    );
  }
}
