import '../../../../core/usecases/usecase.dart';
import '../entities/session_config.dart';
import '../repositories/workout_session_repository.dart';

class StartWorkoutSession implements UseCase<void, SessionConfig> {
  final WorkoutSessionRepository repository;

  StartWorkoutSession(this.repository);

  @override
  Future<void> call(SessionConfig params) async {
    return repository.startSession(params);
  }
}
