import 'package:equatable/equatable.dart';

class WorkoutSessionStats extends Equatable {
  final int totalPunches;
  final double averageReactionMs;
  final int lastReactionMs;
  final String lastRating;
  final int currentRound;
  final int totalRounds;
  final int elapsedSeconds;
  final bool isCameraActive;

  const WorkoutSessionStats({
    required this.totalPunches,
    required this.averageReactionMs,
    required this.lastReactionMs,
    required this.lastRating,
    required this.currentRound,
    required this.totalRounds,
    required this.elapsedSeconds,
    required this.isCameraActive,
  });

  factory WorkoutSessionStats.initial() {
    return const WorkoutSessionStats(
      totalPunches: 0,
      averageReactionMs: 0.0,
      lastReactionMs: 0,
      lastRating: 'N/A',
      currentRound: 1,
      totalRounds: 3,
      elapsedSeconds: 0,
      isCameraActive: true,
    );
  }

  WorkoutSessionStats copyWith({
    int? totalPunches,
    double? averageReactionMs,
    int? lastReactionMs,
    String? lastRating,
    int? currentRound,
    int? totalRounds,
    int? elapsedSeconds,
    bool? isCameraActive,
  }) {
    return WorkoutSessionStats(
      totalPunches: totalPunches ?? this.totalPunches,
      averageReactionMs: averageReactionMs ?? this.averageReactionMs,
      lastReactionMs: lastReactionMs ?? this.lastReactionMs,
      lastRating: lastRating ?? this.lastRating,
      currentRound: currentRound ?? this.currentRound,
      totalRounds: totalRounds ?? this.totalRounds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      isCameraActive: isCameraActive ?? this.isCameraActive,
    );
  }

  @override
  List<Object?> get props => [
        totalPunches,
        averageReactionMs,
        lastReactionMs,
        lastRating,
        currentRound,
        totalRounds,
        elapsedSeconds,
        isCameraActive,
      ];
}
