import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:punch_detection_demo/core/navigation/app_navigator.dart';
import 'package:punch_detection_demo/core/services/storage_service.dart';
import 'package:punch_detection_demo/features/history/data/datasources/local_history_datasource.dart';
import 'package:punch_detection_demo/features/history/data/repositories/history_repository_impl.dart';
import 'package:punch_detection_demo/features/history/domain/entities/workout_record.dart';
import 'package:punch_detection_demo/features/history/domain/repositories/history_repository.dart';
import 'package:punch_detection_demo/features/results/presentation/bindings/results_binding.dart';
import 'package:punch_detection_demo/features/results/presentation/pages/results_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openResults(
  WidgetTester tester,
  SessionResultModel result, {
  Size size = const Size(390, 844),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, _) => GetMaterialApp(
        initialRoute: '/start',
        getPages: [
          GetPage(name: '/start', page: () => const SizedBox()),
          GetPage(
            name: '/results',
            page: () => const ResultsPage(),
            binding: ResultsBinding(),
          ),
        ],
      ),
    ),
  );
  Get.toNamed('/results', arguments: result);
  // Let the confetti, count-up and history save finish.
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

void main() {
  setUp(() async {
    Get.reset();
    SharedPreferences.setMockInitialValues({});
    await Get.putAsync<StorageService>(
      () => StorageService().init(),
      permanent: true,
    );
    Get.put<HistoryRepository>(
      HistoryRepositoryImpl(localDatasource: LocalHistoryDatasource()),
      permanent: true,
    );
  });

  testWidgets('saves the session once', (tester) async {
    await _openResults(
      tester,
      SessionResultModel(totalPunches: 42, durationSeconds: 90),
    );
    expect(find.text('Train again'), findsOneWidget);
    expect(find.text('First session saved!'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final saved = await Get.find<HistoryRepository>().getWorkoutHistory();
    expect(saved.single.totalPunches, 42);
    // Today's usage is counted live in the session (UsageService), not here.
    expect(StorageService.to.todayPunches, 0);
  });

  testWidgets('drill: new record and "vs last time" chips', (tester) async {
    // An earlier drill today.
    await Get.find<HistoryRepository>().saveWorkoutRecord(
      WorkoutRecord(
        id: 'earlier',
        dateIso: DateTime.now()
            .subtract(const Duration(minutes: 30))
            .toIso8601String(),
        durationSeconds: 60,
        totalPunches: 30,
        averageReactionMs: 0,
        bestReactionMs: 0,
        detectionMode: 'fusion',
        sessionType: 'prompt',
        bestStreak: 4,
      ),
    );
    await _openResults(
      tester,
      SessionResultModel(
        totalPunches: 38,
        durationSeconds: 60,
        sessionType: 'prompt',
        drill: const DrillScore(
          difficulty: 'beginner',
          bestStreak: 9,
          callsAnswered: 30,
          callsMade: 40,
        ),
      ),
    );
    expect(find.text('New record: most punches'), findsOneWidget);
    expect(find.text('New best streak'), findsOneWidget);
    expect(find.text('+8 vs last time'), findsOneWidget);
    expect(
      find.text('75% 30/40', findRichText: true),
      findsOneWidget,
    ); // calls answered
    expect(find.text('Today  68 punches', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape renders without overflow', (tester) async {
    await _openResults(
      tester,
      SessionResultModel(
        totalPunches: 1234,
        durationSeconds: 1800,
        sessionType: 'prompt',
        drill: const DrillScore(difficulty: 'intermediate', bestStreak: 25),
      ),
      size: const Size(844, 390),
    );
    expect(find.text('Train again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no punches: nothing saved, no share button', (tester) async {
    await _openResults(
      tester,
      SessionResultModel(totalPunches: 0, durationSeconds: 20),
    );
    expect(find.text('Share'), findsNothing);
    expect(await Get.find<HistoryRepository>().getWorkoutHistory(), isEmpty);
    expect(StorageService.to.todayPunches, 0);
  });
}
