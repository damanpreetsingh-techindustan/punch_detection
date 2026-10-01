import '../../../../core/usecases/usecase.dart';
import '../entities/workout_record.dart';
import '../repositories/history_repository.dart';

class GetWorkoutHistory implements UseCase<List<WorkoutRecord>, NoParams> {
  final HistoryRepository repository;

  GetWorkoutHistory(this.repository);

  @override
  Future<List<WorkoutRecord>> call(NoParams params) async {
    return repository.getWorkoutHistory();
  }
}
