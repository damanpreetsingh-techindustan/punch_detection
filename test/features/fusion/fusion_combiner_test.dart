import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/audio_detection/domain/entities/audio_confidence_score.dart';
import 'package:punch_detection_demo/features/fusion/data/repositories/fusion_repository_impl.dart';
import 'package:punch_detection_demo/features/fusion/domain/entities/fused_punch_event.dart';
import 'package:punch_detection_demo/features/fusion/domain/entities/fusion_config.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/entities/vision_confidence_score.dart';

void main() {
  late FusionRepositoryImpl repository;
  late FusionConfig config;

  setUp(() {
    repository = FusionRepositoryImpl();
    config = const FusionConfig(
      audioWeight: 0.70,
      visionWeight: 0.30,
      minFusedConfidenceThreshold: 0.65,
    );
  });

  group('Phase 4: Fusion Combiner Engine Unit Tests', () {
    test('1. Matched Audio + Vision produces confirmed fused punch event', () {
      const audioResult = AudioConfidenceScore(
        score: 0.85,
        isPunchCandidate: true,
        timestampMicroseconds: 1000000,
        filterResults: {},
        metrics: {},
      );

      const visionResult = VisionConfidenceScore(
        score: 0.80,
        isPunchMotionDetected: true,
        timestampMicroseconds: 1000050, // 50ms offset (within 150ms window)
        ruleResults: {},
        metrics: {},
      );

      final event = repository.fuseSignals(
        audioResult: audioResult,
        visionResult: visionResult,
        config: config,
      );

      expect(event.isPunchConfirmed, isTrue);
      expect(event.fusionMode, equals(FusionMode.fusion));
      expect(event.fusedConfidenceScore, closeTo(0.835, 0.01));
    });

    test('2. Camera offline gracefully falls back to 100% Audio Primary mode', () {
      const audioResult = AudioConfidenceScore(
        score: 0.90,
        isPunchCandidate: true,
        timestampMicroseconds: 1000000,
        filterResults: {},
        metrics: {},
      );

      final event = repository.fuseSignals(
        audioResult: audioResult,
        visionResult: null, // Camera offline
        config: config,
      );

      expect(event.isPunchConfirmed, isTrue);
      expect(event.fusionMode, equals(FusionMode.cameraFallback));
      expect(event.fusedConfidenceScore, equals(0.90));
    });

    test('3. Vision movement without matching audio impact spike is rejected', () {
      const audioResult = AudioConfidenceScore(
        score: 0.20,
        isPunchCandidate: false, // No audio spike
        timestampMicroseconds: 1000000,
        filterResults: {},
        metrics: {},
      );

      const visionResult = VisionConfidenceScore(
        score: 0.95, // High camera movement
        isPunchMotionDetected: true,
        timestampMicroseconds: 1000000,
        ruleResults: {},
        metrics: {},
      );

      final event = repository.fuseSignals(
        audioResult: audioResult,
        visionResult: visionResult,
        config: config,
      );

      expect(event.isPunchConfirmed, isFalse);
      expect(event.fusedConfidenceScore, equals(0.0));
    });

    test('4. Non-punch audio and no vision movement is rejected', () {
      const audioResult = AudioConfidenceScore(
        score: 0.30,
        isPunchCandidate: false,
        timestampMicroseconds: 1000000,
        filterResults: {},
        metrics: {},
      );

      const visionResult = VisionConfidenceScore(
        score: 0.10,
        isPunchMotionDetected: false,
        timestampMicroseconds: 1000000,
        ruleResults: {},
        metrics: {},
      );

      final event = repository.fuseSignals(
        audioResult: audioResult,
        visionResult: visionResult,
        config: config,
      );

      expect(event.isPunchConfirmed, isFalse);
    });
  });
}
