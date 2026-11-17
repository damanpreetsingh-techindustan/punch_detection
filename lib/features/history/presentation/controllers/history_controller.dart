import 'package:get/get.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/workout_record.dart';
import '../../domain/history_insights.dart';
import '../../domain/usecases/clear_workout_history.dart';
import '../../domain/usecases/get_workout_history.dart';

class HistoryController extends GetxController {
  final GetWorkoutHistory getWorkoutHistoryUseCase;
  final ClearWorkoutHistory clearWorkoutHistoryUseCase;

  final RxList<WorkoutRecord> records = <WorkoutRecord>[].obs;
  final RxBool isLoading = false.obs;

  HistoryController({
    required this.getWorkoutHistoryUseCase,
    required this.clearWorkoutHistoryUseCase,
  });

  DateTime get now => DateTime.now();

  List<DayTotal> get week => HistoryInsights.lastSevenDays(records, now);
  int get dayStreak => HistoryInsights.dayStreak(records, now);
  PersonalBests get bests => HistoryInsights.bests(records);
  int get totalPunches => HistoryInsights.totalPunches(records);

  @override
  void onInit() {
    super.onInit();
    loadHistory();
  }

  Future<void> loadHistory() async {
    isLoading.value = true;
    try {
      records.value = await getWorkoutHistoryUseCase(NoParams());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> clearAllHistory() async {
    await clearWorkoutHistoryUseCase(NoParams());
    await loadHistory();
  }

  void openSession(WorkoutRecord record) =>
      AppNavigator.toHistoryDetail(record);
}
