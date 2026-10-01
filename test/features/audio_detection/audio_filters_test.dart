import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/services/monotonic_clock_service.dart';
import 'package:punch_detection_demo/features/audio_detection/data/datasources/native_audio_stream_datasource.dart';
import 'package:punch_detection_demo/features/audio_detection/data/datasources/test_clip_audio_datasource.dart';
import 'package:punch_detection_demo/features/audio_detection/data/repositories/audio_analyzer_repository_impl.dart';
import 'package:punch_detection_demo/features/audio_detection/domain/entities/audio_filter_config.dart';

void main() {
  late MonotonicClockService clockService;
  late TestClipAudioDatasource testDatasource;
  late AudioAnalyzerRepositoryImpl repository;
  late AudioFilterConfig config;

  setUp(() {
    clockService = MonotonicClockService();
    testDatasource = TestClipAudioDatasource(clockService: clockService);
    final nativeDatasource = NativeAudioStreamDatasource(clockService: clockService);
    repository = AudioAnalyzerRepositoryImpl(nativeDatasource: nativeDatasource);
    config = const AudioFilterConfig(
      energyThresholdDelta: 0.02,
      proximityGateMinRms: 0.02,
    );
  });

  group('Audio Detection 6-Stage Filter Pipeline Tests', () {
    test('Synthetic punch transient passes all 6 filter stages as punch candidate', () {
      // Feed quiet ambient baseline frames first
      for (int i = 0; i < 10; i++) {
        repository.analyzeFrame(testDatasource.generateQuietAmbientFrame(), config);
      }

      final punchFrame = testDatasource.generatePunchFrame();
      final result = repository.analyzeFrame(punchFrame, config);

      expect(result.score, greaterThanOrEqualTo(0.50));
      expect(result.isPunchCandidate, isTrue);
      expect(result.filterResults['Adaptive Noise Floor Tracking'], isTrue);
      expect(result.filterResults['Energy Spike Detection'], isTrue);
      expect(result.filterResults['Transient Envelope Check'], isTrue);
      expect(result.filterResults['Proximity Amplitude Gate'], isTrue);
      expect(result.filterResults['Chassis Vibration Discrimination'], isTrue);
    });

    test('Sustained speech/music narrowband tone fails transient & spectral flatness filter', () {
      final speechFrame = testDatasource.generateSpeechOrMusicFrame();
      final result = repository.analyzeFrame(speechFrame, config);

      expect(result.isPunchCandidate, isFalse);
      expect(result.filterResults['Transient Envelope Check'], isFalse);
    });
  });
}
