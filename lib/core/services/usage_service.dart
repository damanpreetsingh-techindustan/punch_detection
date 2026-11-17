import 'package:get/get.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

/// Today's punch usage for the free daily limit
/// ([AppConstants.freeDailyPunchLimit], switched by
/// [AppConstants.enforceDailyLimit]).
///
/// Counted live while a session runs and written to storage on every punch,
/// so closing or killing the app mid-session never gives punches back.
/// Resetting the count in a session doesn't give them back either.
class UsageService extends GetxService {
  static UsageService get to => Get.find();

  final StorageService _storage = StorageService.to;

  /// Punches used today (resets at midnight, via the stored date).
  final RxInt todayPunches = 0.obs;

  /// Pro users have no daily limit. Set by the purchase service (RevenueCat)
  /// once purchases are connected; false until then.
  final RxBool isPro = false.obs;

  /// True while the running session has stopped counting at the limit
  /// (the session screen shows "not counting").
  final RxBool countingStopped = false.obs;

  int get dailyLimit => AppConstants.freeDailyPunchLimit;

  // The getters below read their observables before combining them with the
  // const switches, so an Obx using them always has something to listen to
  // (`&&` / `||` would otherwise skip the observable).

  /// Whether the free limit applies to this user right now. Reactive.
  bool get limitApplies {
    final pro = isPro.value;
    return AppConstants.enforceDailyLimit && !pro;
  }

  int get remaining => (dailyLimit - todayPunches.value).clamp(0, dailyLimit);

  /// Reactive: reads [todayPunches] and [isPro].
  bool get limitReached {
    final used = todayPunches.value;
    return limitApplies && used >= dailyLimit;
  }

  @override
  void onInit() {
    super.onInit();
    refreshFromStorage();
  }

  /// Re-reads today's total (also rolls over to 0 after midnight).
  void refreshFromStorage() => todayPunches.value = _storage.todayPunches;

  /// Counts every increase of [punchCount] for as long as the returned worker
  /// lives. Dispose it when the session ends.
  Worker trackSession(RxInt punchCount) {
    var last = punchCount.value;
    return ever<int>(punchCount, (count) {
      if (count > last) _add(count - last);
      last = count;
    });
  }

  /// Testing only ([AppConstants.showTestUsageReset]): today's count back to
  /// 0, as if it were a new day.
  Future<void> resetToday() async {
    todayPunches.value = 0;
    await _storage.setTodayPunches(0);
  }

  void _add(int punches) {
    // Read the stored value so a session that runs past midnight starts the
    // new day at 0.
    var total = _storage.todayPunches + punches;
    // A punch landing in the instant before counting stops is not charged.
    if (limitApplies && total > dailyLimit) total = dailyLimit;
    todayPunches.value = total;
    _storage.setTodayPunches(total);
  }
}
