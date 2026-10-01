import '../../domain/entities/audio_filter_config.dart';
import '../../domain/entities/audio_frame.dart';

class FilterStageResult {
  final bool passed;
  final String stageName;
  final double score; // 0.0 to 1.0
  final Map<String, dynamic> metrics;

  const FilterStageResult({
    required this.passed,
    required this.stageName,
    required this.score,
    required this.metrics,
  });
}

abstract class AudioFilterStage {
  String get name;

  FilterStageResult process(
    AudioFrame frame,
    AudioFilterConfig config,
    double currentNoiseFloorRms,
  );
}
