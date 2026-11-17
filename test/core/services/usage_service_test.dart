import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:punch_detection_demo/core/services/storage_service.dart';
import 'package:punch_detection_demo/core/services/usage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<UsageService> _startApp() async {
  Get.reset();
  await Get.putAsync<StorageService>(() => StorageService().init());
  return Get.put(UsageService());
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('every punch is saved as it happens', () async {
    final usage = await _startApp();
    final punchCount = 0.obs;
    final worker = usage.trackSession(punchCount);

    punchCount.value = 1;
    punchCount.value = 2;
    punchCount.value = 5; // a quick combo
    await Future<void>.delayed(Duration.zero);

    expect(usage.todayPunches.value, 5);
    expect(StorageService.to.todayPunches, 5);
    worker.dispose();
  });

  test('killing the app mid-session keeps the punches used', () async {
    var usage = await _startApp();
    final punchCount = 0.obs;
    usage.trackSession(punchCount);
    punchCount.value = 100;
    await Future<void>.delayed(Duration.zero);

    // App killed: no Results, no dispose. Next launch reads storage.
    usage = await _startApp();
    expect(usage.todayPunches.value, 100);
    expect(usage.remaining, usage.dailyLimit - 100);
  });

  test('resetting the count does not give punches back', () async {
    final usage = await _startApp();
    final punchCount = 0.obs;
    usage.trackSession(punchCount);
    punchCount.value = 40;
    punchCount.value = 0; // Reset count in the pause menu
    punchCount.value = 10;
    await Future<void>.delayed(Duration.zero);
    expect(usage.todayPunches.value, 50);
  });

  test('two sessions add up; the limit is reached', () async {
    final usage = await _startApp();
    final first = 0.obs;
    final firstWorker = usage.trackSession(first);
    first.value = usage.dailyLimit - 10;
    await Future<void>.delayed(Duration.zero);
    firstWorker.dispose();
    final second = 0.obs;
    usage.trackSession(second);
    second.value = 10;
    await Future<void>.delayed(Duration.zero);
    expect(usage.limitReached, isTrue);
    expect(usage.remaining, 0);
  });

  test('usage never goes past the limit for free users', () async {
    final usage = await _startApp();
    final punchCount = 0.obs;
    usage.trackSession(punchCount);
    punchCount.value = usage.dailyLimit + 3; // punches in flight at the limit
    await Future<void>.delayed(Duration.zero);
    expect(usage.todayPunches.value, usage.dailyLimit);
  });

  test('Pro users have no limit and are not capped', () async {
    final usage = await _startApp();
    usage.isPro.value = true;
    final punchCount = 0.obs;
    usage.trackSession(punchCount);
    punchCount.value = usage.dailyLimit + 50;
    await Future<void>.delayed(Duration.zero);
    expect(usage.limitReached, isFalse);
    expect(usage.todayPunches.value, usage.dailyLimit + 50);
  });

  test('test reset puts today back to 0', () async {
    final usage = await _startApp();
    await StorageService.to.setTodayPunches(usage.dailyLimit);
    usage.refreshFromStorage();
    expect(usage.limitReached, isTrue);

    await usage.resetToday();
    expect(usage.todayPunches.value, 0);
    expect(StorageService.to.todayPunches, 0);
    expect(usage.limitReached, isFalse);
  });
}
