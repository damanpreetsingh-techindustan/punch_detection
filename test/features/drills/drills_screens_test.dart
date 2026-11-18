import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:punch_detection_demo/core/navigation/app_pages.dart';
import 'package:punch_detection_demo/core/navigation/app_routes.dart';
import 'package:punch_detection_demo/core/services/storage_service.dart';
import 'package:punch_detection_demo/core/services/usage_service.dart';
import 'package:punch_detection_demo/features/drills/data/drill_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _open(WidgetTester tester, String route, Size size) async {
  // The asset cache would hand this test a load started in the previous
  // test's fake clock, which never completes.
  rootBundle.clear();
  Get.reset();
  SharedPreferences.setMockInitialValues({});
  await Get.putAsync<StorageService>(
    () => StorageService().init(),
    permanent: true,
  );
  Get.put(UsageService(), permanent: true);
  Get.put(DrillService(), permanent: true);
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, _) =>
          GetMaterialApp(initialRoute: route, getPages: AppPages.pages),
    ),
  );
  // Asset loading is real I/O: let it finish outside fake time.
  await tester.runAsync(() => DrillService.to.ensureLoaded());
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1)); // entrance animations
}

void main() {
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('drills page lists all programs at $size', (tester) async {
      await _open(tester, AppRoutes.drills, size);
      expect(tester.takeException(), isNull);
      expect(DrillService.to.builtIn.length, greaterThanOrEqualTo(3));
      expect(find.text('Reaction Drills'), findsOneWidget);
      expect(find.text('Jab Master'), findsOneWidget);
    });
  }

  testWidgets('southpaw toggle flips the stance', (tester) async {
    await _open(tester, AppRoutes.drills, const Size(390, 844));
    await tester.tap(find.text('Orthodox'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(StorageService.to.southpaw.value, isTrue);
    expect(find.text('Southpaw'), findsOneWidget);
  });

  testWidgets('editor: build a combo by tapping the bag and save', (
    tester,
  ) async {
    await _open(tester, AppRoutes.drillEditor, const Size(390, 844));
    expect(tester.takeException(), isNull);
    // Saving empty shows the name error.
    await tester.tap(find.text('Save drill'));
    await tester.pump();
    expect(find.text('Give your drill a name.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'My 1-2');
    // Tap the bag badges "1" then "2".
    await tester.tap(find.text('1').first);
    await tester.tap(find.text('2').first);
    await tester.pump();
    expect(find.text('1 - 2'), findsOneWidget);

    await tester.ensureVisible(find.text('Save drill'));
    await tester.tap(find.text('Save drill'));
    await tester.pump(const Duration(milliseconds: 500));
    final saved = DrillService.to.custom.single;
    expect(saved.title, 'My 1-2');
    expect(saved.combos, [
      [1, 2],
    ]);
  });

  testWidgets('detail sheet shows the drill and the round choices', (
    tester,
  ) async {
    await _open(tester, AppRoutes.drills, const Size(390, 844));
    await tester.ensureVisible(find.text('Jab Master'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Jab Master'));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Start drill'), findsOneWidget);
    expect(find.text('ROUND LENGTH'), findsOneWidget);

    // "Open" hides the length and rest choices.
    await tester.ensureVisible(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ROUND LENGTH'), findsNothing);
    expect(tester.takeException(), isNull);

    // The close button in the sheet header closes it.
    await tester.ensureVisible(find.byIcon(Icons.close_rounded));
    await tester.tap(find.byIcon(Icons.close_rounded));
    // The close animation starts on the next frame, then runs ~250 ms.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Start drill'), findsNothing);
  });
}
