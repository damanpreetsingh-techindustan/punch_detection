import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/services/monotonic_clock_service.dart';
import 'package:punch_detection_demo/features/prompt_timing/data/datasources/test_prompt_datasource.dart';
import 'package:punch_detection_demo/features/prompt_timing/data/repositories/prompt_timing_repository_impl.dart';
import 'package:punch_detection_demo/features/prompt_timing/domain/entities/prompt_config.dart';
import 'package:punch_detection_demo/features/prompt_timing/domain/entities/reaction_time_result.dart';

void main() {
  late MonotonicClockService clockService;
  late TestPromptDatasource testDatasource;
  late PromptTimingRepositoryImpl repository;
  late PromptConfig config;

  setUp(() {
    clockService = MonotonicClockService();
    testDatasource = TestPromptDatasource(clockService: clockService);
    repository = PromptTimingRepositoryImpl(ttsDatasource: testDatasource);
    config = const PromptConfig();
  });

  group('Phase 5: Prompt & Timing Engine Unit Tests', () {
    test('1. TTS prompt playback records monotonic start timestamp', () async {
      final combo = await repository.speakPrompt(
        promptId: 'p_1',
        calloutText: '1',
        config: config,
      );

      expect(combo.id, equals('p_1'));
      expect(combo.calloutText, equals('1'));
      expect(combo.audioStartTimestampUs, greaterThan(0));
    });

    test('2. Fast reaction time (280ms) calculates rating fast', () {
      const int promptUs = 1000000;
      const int punchUs = 1280000; // 280ms delta

      final result = repository.calculateReactionTime(
        promptId: 'p_1',
        promptTimestampUs: promptUs,
        punchTimestampUs: punchUs,
      );

      expect(result.reactionTimeMs, equals(280));
      expect(result.rating, equals(ReactionRating.fast));
    });

    test('3. Good reaction time (450ms) calculates rating good', () {
      const int promptUs = 1000000;
      const int punchUs = 1450000; // 450ms delta

      final result = repository.calculateReactionTime(
        promptId: 'p_2',
        promptTimestampUs: promptUs,
        punchTimestampUs: punchUs,
      );

      expect(result.reactionTimeMs, equals(450));
      expect(result.rating, equals(ReactionRating.good));
    });

    test('4. Slow reaction time (750ms) calculates rating slow', () {
      const int promptUs = 1000000;
      const int punchUs = 1750000; // 750ms delta

      final result = repository.calculateReactionTime(
        promptId: 'p_3',
        promptTimestampUs: promptUs,
        punchTimestampUs: punchUs,
      );

      expect(result.reactionTimeMs, equals(750));
      expect(result.rating, equals(ReactionRating.slow));
    });
  });
}
