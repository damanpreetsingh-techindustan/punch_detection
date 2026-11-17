// Renders screens to PNG for a visual check (not part of the test suite):
//   flutter test tool/render_screens_test.dart --dart-define=OUT=build/screens
// Arial stands in for the Google fonts (tests can't download them), so
// spacing and line breaks are close to a real phone.
// Lives in tool/ (not test/) because it needs macOS system fonts.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:punch_detection_demo/core/navigation/app_navigator.dart';
import 'package:punch_detection_demo/core/navigation/app_pages.dart';
import 'package:punch_detection_demo/core/navigation/app_routes.dart';
import 'package:punch_detection_demo/core/services/storage_service.dart';
import 'package:punch_detection_demo/features/history/data/datasources/local_history_datasource.dart';
import 'package:punch_detection_demo/features/history/data/repositories/history_repository_impl.dart';
import 'package:punch_detection_demo/features/history/domain/entities/workout_record.dart';
import 'package:punch_detection_demo/features/history/domain/repositories/history_repository.dart';
import 'package:punch_detection_demo/core/services/usage_service.dart';
import 'package:punch_detection_demo/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/screens');

Future<void> _loadFonts() async {
  final regular = File(
    '/System/Library/Fonts/Supplemental/Arial.ttf',
  ).readAsBytesSync();
  final bold = File(
    '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
  ).readAsBytesSync();
  for (final family in ['Sora', 'Inter', 'SpaceGrotesk', 'Space Grotesk']) {
    for (final v in ['regular', '500', '600', '700', '800', '900']) {
      final isBold = v != 'regular' && v != '500';
      final loader = FontLoader('${family}_$v')
        ..addFont(Future.value(ByteData.sublistView(isBold ? bold : regular)));
      await loader.load();
    }
  }
  await (FontLoader(
    'Roboto',
  )..addFont(Future.value(ByteData.sublistView(regular)))).load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}

Future<void> _shot(
  WidgetTester tester,
  String name,
  Size size, {
  String route = AppRoutes.paywall,
  Object? arguments,
  int usedToday = 120,
}) async {
  Get.reset();
  SharedPreferences.setMockInitialValues({});
  await Get.putAsync<StorageService>(
    () => StorageService().init(),
    permanent: true,
  );
  await StorageService.to.setTodayPunches(usedToday);
  Get.put(UsageService(), permanent: true);
  final repo = HistoryRepositoryImpl(localDatasource: LocalHistoryDatasource());
  Get.put<HistoryRepository>(repo, permanent: true);
  final now = DateTime.now();
  for (var d = 0; d < 6; d++) {
    if (d == 3) continue;
    final at = DateTime(now.year, now.month, now.day - d, 18, 5 + d);
    await repo.saveWorkoutRecord(
      WorkoutRecord(
        id: 'r$d',
        dateIso: at.toIso8601String(),
        durationSeconds: 240 + d * 30,
        totalPunches: 140 - d * 15,
        averageReactionMs: 0,
        bestReactionMs: 0,
        detectionMode: 'fusion',
        sessionType: d.isOdd ? 'prompt' : 'free',
        difficulty: d.isOdd ? 'intermediate' : null,
        bestStreak: d.isOdd ? 9 : 0,
        callsAnswered: d.isOdd ? 60 : 0,
        callsMade: d.isOdd ? 80 : 0,
      ),
    );
  }
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, _) => GetMaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          initialRoute: arguments == null ? route : '/blank',
          getPages: [
            ...AppPages.pages,
            GetPage(name: '/blank', page: () => const SizedBox()),
          ],
        ),
      ),
    ),
  );
  if (arguments != null) {
    Get.toNamed(route, arguments: arguments);
  }
  // Async loads (saved history) finish over a few frames; then the entrance
  // animations need time to play.
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }
  final error = tester.takeException();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_out/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
  });
  await tester.pump(const Duration(seconds: 5)); // let entrance timers end
  expect(error, isNull, reason: '$name: $error');
}

final _drillResult = SessionResultModel(
  totalPunches: 152,
  durationSeconds: 300,
  sessionType: 'prompt',
  drill: const DrillScore(
    difficulty: 'intermediate',
    bestStreak: 14,
    callsAnswered: 70,
    callsMade: 90,
  ),
);

void main() {
  setUpAll(_loadFonts);

  const phone = Size(390, 844);
  const small = Size(375, 667);
  const land = Size(844, 390);

  testWidgets('paywall phone', (t) => _shot(t, 'paywall_phone', phone));
  testWidgets('paywall small', (t) => _shot(t, 'paywall_small', small));
  testWidgets(
    'paywall from limit',
    (t) => _shot(t, 'paywall_limit', phone, arguments: {'fromLimit': true}),
  );
  testWidgets('paywall landscape', (t) => _shot(t, 'paywall_land', land));
  testWidgets(
    'results phone',
    (t) => _shot(
      t,
      'results_phone',
      phone,
      route: AppRoutes.results,
      arguments: _drillResult,
    ),
  );
  testWidgets(
    'results landscape',
    (t) => _shot(
      t,
      'results_land',
      land,
      route: AppRoutes.results,
      arguments: _drillResult,
    ),
  );
  testWidgets(
    'history phone',
    (t) => _shot(t, 'history_phone', phone, route: AppRoutes.history),
  );
  testWidgets(
    'history landscape',
    (t) => _shot(t, 'history_land', land, route: AppRoutes.history),
  );
  testWidgets(
    'home phone',
    (t) => _shot(t, 'home_phone', phone, route: AppRoutes.home, usedToday: 210),
  );
  testWidgets(
    'home limit reached',
    (t) => _shot(t, 'home_limit', small, route: AppRoutes.home, usedToday: 300),
  );
  testWidgets(
    'home landscape',
    (t) => _shot(t, 'home_land', land, route: AppRoutes.home),
  );
}
