import '../entities/lifetime_summary_stats.dart';
import '../entities/workout_record.dart';

abstract class HistoryRepository {
  /// Loads all saved workout records from local sandbox storage
  Future<List<WorkoutRecord>> getWorkoutHistory();

  /// Saves a newly completed workout record
  Future<void> saveWorkoutRecord(WorkoutRecord record);

  /// Clears all stored workout history records
  Future<void> clearHistory();

  /// Compiles lifetime summary analytics across all records
  Future<LifetimeSummaryStats> getLifetimeSummaryStats();
}
