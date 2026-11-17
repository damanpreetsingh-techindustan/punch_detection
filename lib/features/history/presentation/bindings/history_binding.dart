import 'package:get/get.dart';
import '../../domain/repositories/history_repository.dart';
import '../../domain/usecases/clear_workout_history.dart';
import '../../domain/usecases/get_workout_history.dart';
import '../controllers/history_controller.dart';

class HistoryBinding extends Bindings {
  @override
  void dependencies() {
    // The repository is app-wide (InitialBindings).
    final repository = Get.find<HistoryRepository>();
    Get.lazyPut<HistoryController>(
      () => HistoryController(
        getWorkoutHistoryUseCase: GetWorkoutHistory(repository),
        clearWorkoutHistoryUseCase: ClearWorkoutHistory(repository),
      ),
    );
  }
}
