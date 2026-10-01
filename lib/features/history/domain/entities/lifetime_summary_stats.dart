import 'package:equatable/equatable.dart';
import 'workout_record.dart';

class LifetimeSummaryStats extends Equatable {
  final int totalWorkouts;
  final int totalPunches;
  final double lifetimeAvgReactionMs;
  final int bestReactionMs;

  const LifetimeSummaryStats({
    required this.totalWorkouts,
    required this.totalPunches,
    required this.lifetimeAvgReactionMs,
    required this.bestReactionMs,
  });

  factory LifetimeSummaryStats.fromRecords(List<WorkoutRecord> records) {
    if (records.isEmpty) {
      return const LifetimeSummaryStats(
        totalWorkouts: 0,
        totalPunches: 0,
        lifetimeAvgReactionMs: 0.0,
        bestReactionMs: 0,
      );
    }

    final int totalPunches = records.fold(0, (sum, r) => sum + r.totalPunches);
    final double totalAvgMs = records.fold(0.0, (sum, r) => sum + r.averageReactionMs);
    final double lifetimeAvgMs = totalAvgMs / records.length;

    int minBestMs = 999999;
    for (final r in records) {
      if (r.bestReactionMs > 0 && r.bestReactionMs < minBestMs) {
        minBestMs = r.bestReactionMs;
      }
    }
    if (minBestMs == 999999) minBestMs = 0;

    return LifetimeSummaryStats(
      totalWorkouts: records.length,
      totalPunches: totalPunches,
      lifetimeAvgReactionMs: lifetimeAvgMs,
      bestReactionMs: minBestMs,
    );
  }

  @override
  List<Object?> get props => [
        totalWorkouts,
        totalPunches,
        lifetimeAvgReactionMs,
        bestReactionMs,
      ];
}
