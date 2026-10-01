import '../datasources/local_history_datasource.dart';
import '../../domain/entities/lifetime_summary_stats.dart';
import '../../domain/entities/workout_record.dart';
import '../../domain/repositories/history_repository.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  final LocalHistoryDatasource localDatasource;

  HistoryRepositoryImpl({required this.localDatasource});

  @override
  Future<List<WorkoutRecord>> getWorkoutHistory() async {
    return localDatasource.readAllRecords();
  }

  @override
  Future<void> saveWorkoutRecord(WorkoutRecord record) async {
    await localDatasource.writeRecord(record);
  }

  @override
  Future<void> clearHistory() async {
    await localDatasource.clearAll();
  }

  @override
  Future<LifetimeSummaryStats> getLifetimeSummaryStats() async {
    final records = await localDatasource.readAllRecords();
    return LifetimeSummaryStats.fromRecords(records);
  }
}
