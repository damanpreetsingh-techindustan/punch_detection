import 'package:get/get.dart';
import '../../data/datasources/local_history_datasource.dart';
import '../../data/repositories/history_repository_impl.dart';
import '../../domain/repositories/history_repository.dart';
import '../../domain/usecases/clear_workout_history.dart';
import '../../domain/usecases/get_workout_history.dart';
import '../../domain/usecases/save_workout_record.dart';
import '../controllers/history_controller.dart';

class HistoryBinding extends Bindings {
  @override
  void dependencies() {
    final datasource = LocalHistoryDatasource();
    final repository = HistoryRepositoryImpl(localDatasource: datasource);
    Get.lazyPut<HistoryRepository>(() => repository);

    final getHistoryUseCase = GetWorkoutHistory(repository);
    final saveRecordUseCase = SaveWorkoutRecord(repository);
    final clearHistoryUseCase = ClearWorkoutHistory(repository);

    Get.lazyPut<GetWorkoutHistory>(() => getHistoryUseCase);
    Get.lazyPut<SaveWorkoutRecord>(() => saveRecordUseCase);
    Get.lazyPut<ClearWorkoutHistory>(() => clearHistoryUseCase);

    Get.lazyPut<HistoryController>(
      () => HistoryController(
        getWorkoutHistoryUseCase: getHistoryUseCase,
        clearWorkoutHistoryUseCase: clearHistoryUseCase,
      ),
    );
  }
}
