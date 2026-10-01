import 'package:get/get.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/lifetime_summary_stats.dart';
import '../../domain/entities/workout_record.dart';
import '../../domain/usecases/clear_workout_history.dart';
import '../../domain/usecases/get_workout_history.dart';

class HistoryController extends GetxController {
  final GetWorkoutHistory getWorkoutHistoryUseCase;
  final ClearWorkoutHistory clearWorkoutHistoryUseCase;

  final RxList<WorkoutRecord> records = <WorkoutRecord>[].obs;
  final Rx<LifetimeSummaryStats> summaryStats = const LifetimeSummaryStats(
    totalWorkouts: 0,
    totalPunches: 0,
    lifetimeAvgReactionMs: 0.0,
    bestReactionMs: 0,
  ).obs;
  final RxBool isLoading = false.obs;

  HistoryController({
    required this.getWorkoutHistoryUseCase,
    required this.clearWorkoutHistoryUseCase,
  });

  @override
  void onInit() {
    super.onInit();
    loadHistory();
  }

  Future<void> loadHistory() async {
    isLoading.value = true;
    try {
      final list = await getWorkoutHistoryUseCase(NoParams());
      records.value = list;
      summaryStats.value = LifetimeSummaryStats.fromRecords(list);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> clearAllHistory() async {
    await clearWorkoutHistoryUseCase(NoParams());
    await loadHistory();
  }
}
