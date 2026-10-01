import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/audio_detection/domain/entities/audio_confidence_score.dart';
import 'package:punch_detection_demo/features/fusion/data/repositories/fusion_repository_impl.dart';
import 'package:punch_detection_demo/features/fusion/domain/entities/fusion_config.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/entities/vision_confidence_score.dart';
import 'package:punch_detection_demo/features/workout_session/data/repositories/workout_session_repository_impl.dart';
import 'package:punch_detection_demo/features/workout_session/domain/entities/session_config.dart';

void main() {
  late FusionRepositoryImpl fusionRepository;
  late WorkoutSessionRepositoryImpl repository;
  late FusionConfig fusionConfig;

  setUp(() {
    fusionRepository = FusionRepositoryImpl();
    repository = WorkoutSessionRepositoryImpl(fusionRepository: fusionRepository);
    fusionConfig = const FusionConfig();
  });

  group('Phase 7: Workout Session Engine Unit Tests', () {
    test('1. startSession initializes session config stats', () async {
      const config = SessionConfig(totalRounds: 3, isAudioOnly: false);
      await repository.startSession(config);

      final stats = repository.endSession();
      expect(stats.totalRounds, equals(3));
      expect(stats.totalPunches, equals(0));
      expect(stats.isCameraActive, isTrue);
    });

    test('2. processLiveFrame fuses matched signals and increments punch count', () async {
      const config = SessionConfig(totalRounds: 3);
      await repository.startSession(config);

      const audio = AudioConfidenceScore(
        score: 0.90,
        isPunchCandidate: true,
        timestampMicroseconds: 1000000,
        filterResults: {},
        metrics: {},
      );

      const vision = VisionConfidenceScore(
        score: 0.85,
        isPunchMotionDetected: true,
        timestampMicroseconds: 1000000,
        ruleResults: {},
        metrics: {},
      );

      final event = repository.processLiveFrame(
        audioResult: audio,
        visionResult: vision,
        config: fusionConfig,
      );

      expect(event.isPunchConfirmed, isTrue);

      final stats = repository.endSession();
      expect(stats.totalPunches, equals(1));
    });
  });
}
