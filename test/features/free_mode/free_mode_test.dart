import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/audio_detection/domain/entities/audio_confidence_score.dart';
import 'package:punch_detection_demo/features/free_mode/data/repositories/free_mode_repository_impl.dart';
import 'package:punch_detection_demo/features/free_mode/domain/entities/free_mode_config.dart';
import 'package:punch_detection_demo/features/free_mode/domain/entities/free_mode_stats.dart';
import 'package:punch_detection_demo/features/fusion/data/repositories/fusion_repository_impl.dart';
import 'package:punch_detection_demo/features/fusion/domain/entities/fusion_config.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/entities/vision_confidence_score.dart';

void main() {
  late FusionRepositoryImpl fusionRepository;
  late FreeModeRepositoryImpl repository;
  late FusionConfig fusionConfig;

  setUp(() {
    fusionRepository = FusionRepositoryImpl();
    repository = FreeModeRepositoryImpl(fusionRepository: fusionRepository);
    fusionConfig = const FusionConfig();
  });

  group('Phase 9: Free Mode Engine Unit Tests', () {
    test('1. startSession initializes free mode stats', () async {
      await repository.startSession(const FreeModeConfig());
      final stats = repository.getStats();

      expect(stats.totalPunches, equals(0));
      expect(stats.punchesPerMinute, equals(0));
      expect(stats.intensityLevel, equals(WorkoutIntensity.moderate));
    });

    test(
      '2. FreeModeRepositoryImpl calculates rolling 5s PPM cadence',
      () async {
        await repository.startSession(const FreeModeConfig());

        // Ingest 5 punch events within 10 seconds
        for (int i = 0; i < 5; i++) {
          final audio = AudioConfidenceScore(
            score: 0.90,
            isPunchCandidate: true,
            timestampMicroseconds: 1000000 + (i * 1000000), // 1s intervals
            filterResults: const {},
            metrics: const {},
          );

          final vision = VisionConfidenceScore(
            score: 0.85,
            isPunchMotionDetected: true,
            timestampMicroseconds: 1000000 + (i * 1000000),
            ruleResults: const {},
            metrics: const {},
          );

          repository.processLiveFrame(
            audioResult: audio,
            visionResult: vision,
            config: fusionConfig,
          );
        }

        final stats = repository.getStats();
        expect(stats.totalPunches, equals(5));
        expect(stats.punchesPerMinute, equals(30)); // 5 punches * 6 = 30 PPM
        expect(stats.intensityLevel, equals(WorkoutIntensity.moderate));
      },
    );

    test('3. FreeModeStats evaluates intensity levels correctly', () {
      expect(FreeModeStats.getIntensity(30), equals(WorkoutIntensity.moderate));
      expect(FreeModeStats.getIntensity(60), equals(WorkoutIntensity.high));
      expect(FreeModeStats.getIntensity(95), equals(WorkoutIntensity.peak));
    });
  });
}
