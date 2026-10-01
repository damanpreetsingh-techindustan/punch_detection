import '../../../../core/usecases/usecase.dart';
import '../entities/prompt_combo.dart';
import '../entities/prompt_config.dart';
import '../repositories/prompt_timing_repository.dart';

class PlayPromptCalloutParams {
  final String promptId;
  final String calloutText;
  final PromptConfig config;

  const PlayPromptCalloutParams({
    required this.promptId,
    required this.calloutText,
    required this.config,
  });
}

class PlayPromptCallout implements UseCase<PromptCombo, PlayPromptCalloutParams> {
  final PromptTimingRepository repository;

  PlayPromptCallout(this.repository);

  @override
  Future<PromptCombo> call(PlayPromptCalloutParams params) async {
    return repository.speakPrompt(
      promptId: params.promptId,
      calloutText: params.calloutText,
      config: params.config,
    );
  }
}
