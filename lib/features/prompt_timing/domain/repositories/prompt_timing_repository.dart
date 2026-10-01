import '../entities/prompt_combo.dart';
import '../entities/prompt_config.dart';
import '../entities/reaction_time_result.dart';

abstract class PromptTimingRepository {
  /// Speaks a prompt call-out via TTS and returns PromptCombo with monotonic start timestamp
  Future<PromptCombo> speakPrompt({
    required String promptId,
    required String calloutText,
    required PromptConfig config,
  });

  /// Calculates reaction time in milliseconds given prompt start and punch impact timestamps
  ReactionTimeResult calculateReactionTime({
    required String promptId,
    required int promptTimestampUs,
    required int punchTimestampUs,
  });
}
