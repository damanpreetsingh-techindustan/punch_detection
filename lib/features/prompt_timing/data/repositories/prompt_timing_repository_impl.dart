import 'dart:math';
import '../datasources/tts_prompt_datasource.dart';
import '../../domain/entities/prompt_combo.dart';
import '../../domain/entities/prompt_config.dart';
import '../../domain/entities/reaction_time_result.dart';
import '../../domain/repositories/prompt_timing_repository.dart';

class PromptTimingRepositoryImpl implements PromptTimingRepository {
  final ITTSPromptDatasource ttsDatasource;

  PromptTimingRepositoryImpl({required this.ttsDatasource});

  @override
  Future<PromptCombo> speakPrompt({
    required String promptId,
    required String calloutText,
    required PromptConfig config,
  }) async {
    return ttsDatasource.speak(promptId, calloutText, config);
  }

  @override
  ReactionTimeResult calculateReactionTime({
    required String promptId,
    required int promptTimestampUs,
    required int punchTimestampUs,
  }) {
    final int deltaUs = max(0, punchTimestampUs - promptTimestampUs);
    final int reactionTimeMs = deltaUs ~/ 1000;
    final ReactionRating rating = ReactionTimeResult.getRating(reactionTimeMs);

    return ReactionTimeResult(
      promptId: promptId,
      promptTimestampUs: promptTimestampUs,
      punchTimestampUs: punchTimestampUs,
      reactionTimeMs: reactionTimeMs,
      rating: rating,
    );
  }
}
