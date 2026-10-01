import '../../../../core/usecases/usecase.dart';
import '../repositories/history_repository.dart';

class ClearWorkoutHistory implements UseCase<void, NoParams> {
  final HistoryRepository repository;

  ClearWorkoutHistory(this.repository);

  @override
  Future<void> call(NoParams params) async {
    return repository.clearHistory();
  }
}
