import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:punch_detection_demo/core/services/storage_service.dart';
import 'package:punch_detection_demo/core/services/usage_service.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import 'package:punch_detection_demo/features/history/data/datasources/local_history_datasource.dart';
import 'package:punch_detection_demo/features/history/data/repositories/history_repository_impl.dart';
import 'package:punch_detection_demo/features/history/domain/repositories/history_repository.dart';
import 'package:punch_detection_demo/features/home/presentation/controllers/home_controller.dart';
import 'package:punch_detection_demo/features/learn/data/learn_service.dart';
import 'package:punch_detection_demo/features/home/presentation/pages/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpHome(WidgetTester tester, {int usedToday = 0}) async {
  Get.reset();
  SharedPreferences.setMockInitialValues({});
  await Get.putAsync<StorageService>(
    () => StorageService().init(),
    permanent: true,
  );
  await StorageService.to.setTodayPunches(usedToday);
  Get.put(UsageService(), permanent: true);
  Get.put<HistoryRepository>(
    HistoryRepositoryImpl(localDatasource: LocalHistoryDatasource()),
    permanent: true,
  );
  Get.put(LearnService(), permanent: true);
  Get.put(HomeController());

  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, _) => const GetMaterialApp(home: HomePage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // Catches "improper use of GetX" (an Obx with no observable read) and
  // layout errors on Home.
  testWidgets('Home builds cleanly with free punches left', (tester) async {
    await _pumpHome(tester, usedToday: 210);
    expect(tester.takeException(), isNull);
    expect(find.text('PRO'), findsOneWidget); // top-bar button
    expect(find.text(' / ${AppConstants.freeDailyPunchLimit}'), findsOneWidget);
    expect(
      find.text('${AppConstants.freeDailyPunchLimit - 210} punches left today'),
      findsOneWidget,
    );
  });

  testWidgets('Home builds cleanly with the limit used up', (tester) async {
    await _pumpHome(tester, usedToday: AppConstants.freeDailyPunchLimit);
    expect(tester.takeException(), isNull);
    expect(find.text('All free punches used'), findsOneWidget);
    expect(find.text('Go unlimited'), findsOneWidget);
  });

  testWidgets('the Pro card and meter react to new punches', (tester) async {
    await _pumpHome(tester, usedToday: 0);
    UsageService.to.todayPunches.value = 7;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('test reset button clears today\'s count', (tester) async {
    if (!AppConstants.showTestUsageReset) return;
    await _pumpHome(tester, usedToday: AppConstants.freeDailyPunchLimit);
    await tester.tap(find.text('Reset to 0 (test)'));
    await tester.pumpAndSettle();
    expect(UsageService.to.todayPunches.value, 0);
    expect(find.text('All free punches used'), findsNothing);
    // Let the "Test reset" snackbar show and slide away.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
