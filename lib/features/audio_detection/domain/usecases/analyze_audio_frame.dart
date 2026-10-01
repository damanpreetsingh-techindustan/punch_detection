import '../../../../core/usecases/usecase.dart';
import '../entities/audio_confidence_score.dart';
import '../entities/audio_filter_config.dart';
import '../entities/audio_frame.dart';
import '../repositories/audio_analyzer_repository.dart';

class AnalyzeAudioFrameParams {
  final AudioFrame frame;
  final AudioFilterConfig config;

  const AnalyzeAudioFrameParams({
    required this.frame,
    required this.config,
  });
}

class AnalyzeAudioFrame implements UseCase<AudioConfidenceScore, AnalyzeAudioFrameParams> {
  final AudioAnalyzerRepository repository;

  AnalyzeAudioFrame(this.repository);

  @override
  Future<AudioConfidenceScore> call(AnalyzeAudioFrameParams params) async {
    return repository.analyzeFrame(params.frame, params.config);
  }
}
