import 'package:get/get.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/services/usage_service.dart';
import '../../../../core/utils/constants.dart';
import '../../../history/domain/entities/workout_record.dart';
import '../../../history/domain/repositories/history_repository.dart';

class HomeController extends GetxController {
  RxInt get todayPunches => UsageService.to.todayPunches;

  /// Last few saved sessions for the "Recent" strip.
  final RxList<WorkoutRecord> recent = <WorkoutRecord>[].obs;
  static const int recentCount = 3;

  int get dailyLimit => AppConstants.freeDailyPunchLimit;

  /// The Pro card: always while testing ([AppConstants.alwaysShowUpgrade]),
  /// otherwise once today's free punches are used up. Reactive.
  /// The PRO button in the top bar: for free users, always while testing
  /// ([AppConstants.alwaysShowUpgrade]), otherwise once today's free punches
  /// are used up. Hidden for Pro users. Reactive.
  bool get showProButton {
    // Read the observables first: with the const switch on, `||` would skip
    // them and the Obx around the button would have nothing to listen to.
    final applies = UsageService.to.limitApplies;
    final reached = UsageService.to.limitReached;
    return applies && (AppConstants.alwaysShowUpgrade || reached);
  }

  /// Pro: no daily limit, the today card shows just the count. Reactive.
  bool get isUnlimited => !UsageService.to.limitApplies;

  /// Today's free punches are used up. Reactive.
  bool get limitReached => UsageService.to.limitReached;

  /// Free punches left today. Reactive.
  int get remaining => UsageService.to.remaining;

  bool get showTestReset => AppConstants.showTestUsageReset;

  /// Testing only: today's count back to 0.
  Future<void> resetTodayForTesting() async {
    await UsageService.to.resetToday();
    Get.snackbar(
      'Test reset',
      'Today\'s punch count is back to 0.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  void openPaywall() =>
      AppNavigator.toPaywall(fromLimit: UsageService.to.limitReached);

  @override
  void onInit() {
    super.onInit();
    refreshUsage();
    loadRecent();
  }

  Future<void> loadRecent() async {
    try {
      final all = await Get.find<HistoryRepository>().getWorkoutHistory();
      recent.assignAll(all.take(recentCount));
    } catch (_) {
      recent.clear();
    }
  }

  /// Re-reads today's usage (rolls over to 0 after midnight).
  void refreshUsage() => UsageService.to.refreshFromStorage();

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void startFreeMode() {
    if (_offerProIfLimitReached()) return;
    AppNavigator.toGetReady(sessionType: 'free');
  }

  /// Today's free punches are used up: a session would count nothing, so the
  /// paywall opens instead. Returns true when it did.
  bool _offerProIfLimitReached() {
    if (!UsageService.to.limitReached) return false;
    AppNavigator.toPaywall(fromLimit: true);
    return true;
  }

  /// Reaction Drill library (pick a drill, then Get Ready).
  void openDrills() {
    if (_offerProIfLimitReached()) return;
    AppNavigator.toDrills();
  }

  Future<void> openHistory() async {
    await AppNavigator.toHistory();
    // History may have been cleared there.
    await loadRecent();
  }

  void openSession(WorkoutRecord record) =>
      AppNavigator.toHistoryDetail(record);

  void openSettings() {
    AppNavigator.toSettings();
  }
}
