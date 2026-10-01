import 'package:equatable/equatable.dart';

enum ReactionRating { fast, good, slow }

class ReactionTimeResult extends Equatable {
  final String promptId;
  final int promptTimestampUs;
  final int punchTimestampUs;
  final int reactionTimeMs;
  final ReactionRating rating;

  const ReactionTimeResult({
    required this.promptId,
    required this.promptTimestampUs,
    required this.punchTimestampUs,
    required this.reactionTimeMs,
    required this.rating,
  });

  static ReactionRating getRating(int reactionTimeMs) {
    if (reactionTimeMs <= 350) {
      return ReactionRating.fast;
    } else if (reactionTimeMs <= 600) {
      return ReactionRating.good;
    } else {
      return ReactionRating.slow;
    }
  }

  @override
  List<Object?> get props => [
        promptId,
        promptTimestampUs,
        punchTimestampUs,
        reactionTimeMs,
        rating,
      ];
}
