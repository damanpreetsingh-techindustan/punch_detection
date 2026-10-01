import '../../../../core/usecases/usecase.dart';
import '../entities/free_mode_config.dart';
import '../repositories/free_mode_repository.dart';

class StartFreeModeSession implements UseCase<void, FreeModeConfig> {
  final FreeModeRepository repository;

  StartFreeModeSession(this.repository);

  @override
  Future<void> call(FreeModeConfig params) async {
    return repository.startSession(params);
  }
}
