import '../../../../core/usecases/usecase.dart';
import '../entities/workout_record.dart';
import '../repositories/history_repository.dart';

class SaveWorkoutRecord implements UseCase<void, WorkoutRecord> {
  final HistoryRepository repository;

  SaveWorkoutRecord(this.repository);

  @override
  Future<void> call(WorkoutRecord params) async {
    return repository.saveWorkoutRecord(params);
  }
}
