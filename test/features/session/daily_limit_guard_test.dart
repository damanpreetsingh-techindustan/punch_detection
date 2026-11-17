import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:punch_detection_demo/core/services/storage_service.dart';
import 'package:punch_detection_demo/core/services/usage_service.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import 'package:punch_detection_demo/features/session/presentation/widgets/hud/daily_limit_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Calls {
  int stop = 0;
  int resume = 0;
  int end = 0;
}

Future<(RxInt, _Calls)> _pumpGuard(
  WidgetTester tester, {
  required int usedBefore,
}) async {
  Get.reset();
  SharedPreferences.setMockInitialValues({});
  await Get.putAsync<StorageService>(() => StorageService().init());
  await StorageService.to.setTodayPunches(usedBefore);
  Get.put(UsageService());

  final punchCount = 0.obs;
  final calls = _Calls();
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => GetMaterialApp(
        home: DailyLimitGuard(
          punchCount: punchCount,
          onStopCounting: () => calls.stop++,
          onResumeCounting: () => calls.resume++,
          onEndSession: () => calls.end++,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (punchCount, calls);
}

void main() {
  testWidgets('stops counting once at the limit and shows the sheet', (
    tester,
  ) async {
    const limit = AppConstants.freeDailyPunchLimit;
    final (punches, calls) = await _pumpGuard(tester, usedBefore: limit - 2);
    expect(calls.stop, 0);

    punches.value = 1;
    await tester.pumpAndSettle();
    expect(calls.stop, 0);

    punches.value = 2;
    await tester.pumpAndSettle();
    expect(calls.stop, 1);
    expect(UsageService.to.countingStopped.value, isTrue);
    expect(find.text('That\'s today\'s $limit free punches'), findsOneWidget);

    // A punch already in flight: still not charged past the limit, and the
    // sheet does not open twice.
    punches.value = 3;
    await tester.pumpAndSettle();
    expect(calls.stop, 1);
    expect(UsageService.to.todayPunches.value, limit);

    await tester.ensureVisible(find.text('End session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End session'));
    await tester.pumpAndSettle();
    expect(calls.end, 1);
  });

  testWidgets('limit already used up: stops at the start', (tester) async {
    const limit = AppConstants.freeDailyPunchLimit;
    final (_, calls) = await _pumpGuard(tester, usedBefore: limit);
    expect(calls.stop, 1);
    expect(find.text('Keep training (not counted)'), findsOneWidget);

    await tester.ensureVisible(find.text('Keep training (not counted)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep training (not counted)'));
    await tester.pumpAndSettle();
    expect(UsageService.to.countingStopped.value, isTrue);
  });

  testWidgets('going Pro mid-session resumes counting', (tester) async {
    const limit = AppConstants.freeDailyPunchLimit;
    final (_, calls) = await _pumpGuard(tester, usedBefore: limit);
    expect(calls.stop, 1);

    UsageService.to.isPro.value = true;
    await tester.pumpAndSettle();
    expect(calls.resume, 1);
    expect(UsageService.to.countingStopped.value, isFalse);
  });

  testWidgets('under the limit nothing is stopped', (tester) async {
    final (punches, calls) = await _pumpGuard(tester, usedBefore: 0);
    punches.value = 50;
    await tester.pumpAndSettle();
    expect(calls.stop, 0);
    expect(UsageService.to.todayPunches.value, 50);
  });
}
