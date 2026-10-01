import '../../../../core/usecases/usecase.dart';
import '../entities/reaction_time_result.dart';
import '../repositories/prompt_timing_repository.dart';

class CalculateReactionTimeParams {
  final String promptId;
  final int promptTimestampUs;
  final int punchTimestampUs;

  const CalculateReactionTimeParams({
    required this.promptId,
    required this.promptTimestampUs,
    required this.punchTimestampUs,
  });
}

class CalculateReactionTime implements UseCase<ReactionTimeResult, CalculateReactionTimeParams> {
  final PromptTimingRepository repository;

  CalculateReactionTime(this.repository);

  @override
  Future<ReactionTimeResult> call(CalculateReactionTimeParams params) async {
    return repository.calculateReactionTime(
      promptId: params.promptId,
      promptTimestampUs: params.promptTimestampUs,
      punchTimestampUs: params.punchTimestampUs,
    );
  }
}
