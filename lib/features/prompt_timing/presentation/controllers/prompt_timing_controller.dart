import 'package:get/get.dart';
import '../../../../core/services/config_service.dart';
import '../../domain/entities/prompt_combo.dart';
import '../../domain/entities/prompt_config.dart';
import '../../domain/entities/reaction_time_result.dart';
import '../../domain/usecases/calculate_reaction_time.dart';
import '../../domain/usecases/play_prompt_callout.dart';

class PromptTimingController extends GetxController {
  final PlayPromptCallout playPromptCalloutUseCase;
  final CalculateReactionTime calculateReactionTimeUseCase;
  final ConfigService configService;

  final Rxn<PromptCombo> currentPrompt = Rxn<PromptCombo>();
  final Rxn<ReactionTimeResult> lastReactionResult = Rxn<ReactionTimeResult>();
  final RxList<ReactionTimeResult> sessionResults = <ReactionTimeResult>[].obs;

  PromptTimingController({
    required this.playPromptCalloutUseCase,
    required this.calculateReactionTimeUseCase,
    required this.configService,
  });

  Future<void> triggerPrompt(String text) async {
    const config = PromptConfig();
    final String promptId = DateTime.now().millisecondsSinceEpoch.toString();

    final PromptCombo combo = await playPromptCalloutUseCase(
      PlayPromptCalloutParams(
        promptId: promptId,
        calloutText: text,
        config: config,
      ),
    );

    currentPrompt.value = combo;
  }

  void recordPunchImpact(int punchTimestampUs) async {
    final activePrompt = currentPrompt.value;
    if (activePrompt == null) return;

    final ReactionTimeResult result = await calculateReactionTimeUseCase(
      CalculateReactionTimeParams(
        promptId: activePrompt.id,
        promptTimestampUs: activePrompt.audioStartTimestampUs,
        punchTimestampUs: punchTimestampUs,
      ),
    );

    lastReactionResult.value = result;
    sessionResults.add(result);
  }

  double get averageReactionTimeMs {
    if (sessionResults.isEmpty) return 0.0;
    final int sum = sessionResults.fold(0, (acc, r) => acc + r.reactionTimeMs);
    return sum / sessionResults.length;
  }

  void resetSession() {
    currentPrompt.value = null;
    lastReactionResult.value = null;
    sessionResults.clear();
  }
}
