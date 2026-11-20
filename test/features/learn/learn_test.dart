import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:punch_detection_demo/core/navigation/app_pages.dart';
import 'package:punch_detection_demo/core/navigation/app_routes.dart';
import 'package:punch_detection_demo/core/services/storage_service.dart';
import 'package:punch_detection_demo/core/services/usage_service.dart';
import 'package:punch_detection_demo/core/widgets/ui/app_buttons.dart';
import 'package:punch_detection_demo/features/drills/data/drill_service.dart';
import 'package:punch_detection_demo/features/learn/data/learn_service.dart';
import 'package:punch_detection_demo/features/learn/domain/boxer_moves.dart';
import 'package:punch_detection_demo/features/learn/domain/lesson.dart';
import 'package:punch_detection_demo/features/learn/presentation/controllers/lesson_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Course _course() => Course.tryParse(
  jsonDecode(File('assets/learn/basics.json').readAsStringSync()),
)!;

Future<void> _services({Map<String, Object> prefs = const {}}) async {
  Get.reset();
  SharedPreferences.setMockInitialValues(prefs);
  await Get.putAsync<StorageService>(
    () => StorageService().init(),
    permanent: true,
  );
  Get.put(UsageService(), permanent: true);
  Get.put(DrillService(), permanent: true);
  Get.put(LearnService(), permanent: true);
}

Future<void> _open(
  WidgetTester tester,
  String route,
  Size size, {
  Object? arguments,
  Map<String, Object> prefs = const {},
}) async {
  rootBundle.clear();
  await _services(prefs: prefs);
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() => LearnService.to.ensureLoaded());
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, _) => GetMaterialApp(
        initialRoute: arguments == null ? route : '/blank',
        getPages: [
          ...AppPages.pages,
          GetPage(name: '/blank', page: () => const SizedBox()),
        ],
      ),
    ),
  );
  if (arguments != null) Get.toNamed(route, arguments: arguments);
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

/// Runs a PrimaryButton's action. The test font is much wider than the real
/// one, so long sheets wrap far below the screen and a positional tap misses
/// (on a phone they fit: see tool/render_screens_test.dart).
void _press(WidgetTester tester, String label) {
  final button = tester.widget<PrimaryButton>(
    find.ancestor(of: find.text(label), matching: find.byType(PrimaryButton)),
  );
  button.onPressed!();
}

void main() {
  group('course content', () {
    test('basics.json: 10 lessons in order, every move exists', () {
      final c = _course();
      expect(c.lessons.length, 10);
      expect(c.lessons.map((l) => l.number), List.generate(10, (i) => i + 1));
      for (final l in c.lessons) {
        expect(BoxerMoves.all.containsKey(l.move), isTrue, reason: l.id);
        expect(l.steps, isNotEmpty, reason: l.id);
        if (l.practice.type == 'drill') {
          expect(l.practice.drill, isNotNull, reason: l.id);
          expect(l.practice.drill!.id, 'lesson_${l.id}');
          expect(l.practice.drill!.roundPlan.isOpen, isFalse);
        } else {
          expect(l.practice.cues, isNotEmpty, reason: l.id);
        }
      }
      // Suggested split: first three free.
      expect(c.lessons.take(3).every((l) => !l.proOnly), isTrue);
    });

    test('a broken lesson is skipped, not fatal', () {
      final c = Course.tryParse({
        'lessons': [
          {
            'id': 'x',
            'title': 'Bad drill',
            'practice': {
              'type': 'drill',
              'drill': {
                'combos': [
                  [9],
                ],
              },
            },
          },
          {'id': 'ok', 'number': 1, 'title': 'Fine', 'move': 'jab'},
        ],
      })!;
      expect(c.lessons.map((l) => l.id), ['ok']);
    });
  });

  group('LearnService', () {
    test(
      'practice drill completes the lesson only with enough punches',
      () async {
        await _services();
        final svc = LearnService.to..course.value = _course();
        expect(await svc.onDrillFinished('lesson_jab', 3), isNull);
        expect(svc.completed, isEmpty);
        final done = await svc.onDrillFinished('lesson_jab', 25);
        expect(done?.id, 'jab');
        // A normal drill never completes a lesson.
        expect(await svc.onDrillFinished('jab_master', 99), isNull);
        // Second time: already done, nothing new.
        expect(await svc.onDrillFinished('lesson_jab', 25), isNull);
      },
    );

    test('progress survives a restart', () async {
      await _services();
      await LearnService.to.markComplete('stance');
      await LearnService.to.acceptSafety();
      final saved = StorageService.to;
      Get.reset();
      Get.put(saved, permanent: true);
      final again = Get.put(LearnService(), permanent: true);
      expect(again.completed, {'stance'});
      expect(again.safetyAccepted.value, isTrue);
    });
  });

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('learn page at $size', (tester) async {
      await _open(tester, AppRoutes.learn, size);
      expect(tester.takeException(), isNull);
      expect(find.text('Start lesson 1'), findsOneWidget);
    });

    testWidgets('lesson page at $size', (tester) async {
      await _open(tester, AppRoutes.lesson, size, arguments: 'jab');
      expect(tester.takeException(), isNull);
      expect(find.text('The jab'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('first lesson asks for the safety screen once', (tester) async {
    await _open(tester, AppRoutes.learn, const Size(390, 844));
    await tester.tap(find.text('Start lesson 1'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Train safely'), findsOneWidget);
    _press(tester, 'I understand, let\'s train');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(LearnService.to.safetyAccepted.value, isTrue);
    expect(find.text('Stance & guard'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('follow-along runs to the end and completes the lesson', (
    tester,
  ) async {
    await _open(
      tester,
      AppRoutes.lesson,
      const Size(390, 844),
      arguments: 'stance',
    );
    // The practice card is further down the (lazily built) lesson list.
    Get.find<LessonController>().startPractice();
    await tester.pump();
    expect(Get.find<LessonController>().cue.value, 'Hands up');
    for (var i = 0; i < 46; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(LearnService.to.completed.contains('stance'), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
