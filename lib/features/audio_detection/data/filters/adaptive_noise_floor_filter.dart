import 'dart:math';
import '../../domain/entities/audio_filter_config.dart';
import '../../domain/entities/audio_frame.dart';
import 'audio_filter_stage.dart';

class AdaptiveNoiseFloorTracker {
  final int maxHistorySize;
  final List<double> _rmsHistory = [];

  AdaptiveNoiseFloorTracker({this.maxHistorySize = 100}); // ~5s window (100 frames of 100ms)

  void addFrame(double rms) {
    _rmsHistory.add(rms);
    if (_rmsHistory.length > maxHistorySize) {
      _rmsHistory.removeAt(0);
    }
  }

  /// Calculates the 30th percentile RMS value (resilient to loud punch outliers).
  double get currentNoiseFloor {
    if (_rmsHistory.isEmpty) return 0.02; // Default baseline

    final sorted = List<double>.from(_rmsHistory)..sort();
    final int index = (sorted.length * 0.30).floor();
    return sorted[min(index, sorted.length - 1)].clamp(0.01, 0.5);
  }

  void reset() {
    _rmsHistory.clear();
  }
}

class AdaptiveNoiseFloorFilter implements AudioFilterStage {
  @override
  String get name => 'Adaptive Noise Floor Tracking';

  @override
  FilterStageResult process(
    AudioFrame frame,
    AudioFilterConfig config,
    double currentNoiseFloorRms,
  ) {
    final double rms = frame.rmsEnergy;
    final double noiseFloor = max(currentNoiseFloorRms, 0.01);
    final double ratio = rms / noiseFloor;

    final bool passed = ratio >= 1.2; // Above baseline noise floor

    return FilterStageResult(
      passed: passed,
      stageName: name,
      score: (ratio / 3.0).clamp(0.0, 1.0),
      metrics: {
        'rms': rms,
        'noiseFloor': noiseFloor,
        'ratio': ratio,
      },
    );
  }
}
