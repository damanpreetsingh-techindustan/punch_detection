import '../entities/audio_confidence_score.dart';
import '../entities/audio_filter_config.dart';
import '../entities/audio_frame.dart';

abstract class AudioAnalyzerRepository {
  /// Stream raw audio frames captured from mic or test datasource.
  Stream<AudioFrame> streamAudioFrames();

  /// Analyzes a single audio frame using the 6-stage filter pipeline.
  AudioConfidenceScore analyzeFrame(AudioFrame frame, AudioFilterConfig config);

  /// Resets calibration & rolling noise floor.
  void resetNoiseFloor();
}
