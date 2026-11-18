// Renders the Reaction Drill session screen without a camera, for a visual
// check of the layout (macOS only, like render_screens_test.dart):
//   flutter test tool/render_drill_session_test.dart --dart-define=OUT=build/screens
// ignore_for_file: invalid_use_of_visible_for_testing_member, must_call_super
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:punch_detection_demo/core/services/storage_service.dart';
import 'package:punch_detection_demo/core/services/usage_service.dart';
import 'package:punch_detection_demo/core/theme/app_theme.dart';
import 'package:punch_detection_demo/features/drills/domain/round_clock.dart';
import 'package:punch_detection_demo/features/session/presentation/controllers/prompt_session_controller.dart';
import 'package:punch_detection_demo/features/session/presentation/pages/prompt_session_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/screens');

/// No camera, mic or timers: just the observables the screen reads.
class _ScreenOnlyPrompt extends PromptSessionController {
  @override
  void onInit() {}
  @override
  void onClose() {}
}

Future<void> _fonts() async {
  final regular = File(
    '/System/Library/Fonts/Supplemental/Arial.ttf',
  ).readAsBytesSync();
  final bold = File(
    '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
  ).readAsBytesSync();
  for (final family in ['Sora', 'Inter', 'SpaceGrotesk']) {
    for (final v in ['regular', '500', '600', '700', '800', '900']) {
      final b = v != 'regular' && v != '500';
      await (FontLoader('${family}_$v')
            ..addFont(Future.value(ByteData.sublistView(b ? bold : regular))))
          .load();
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
  bool rest = false,
}) async {
  Get.reset();
  SharedPreferences.setMockInitialValues({});
  await Get.putAsync<StorageService>(() => StorageService().init());
  Get.put(UsageService());
  final c = _ScreenOnlyPrompt();
  Get.put<PromptSessionController>(c);
  c
    ..difficulty.value = 'Jab Master'
    ..punchCount.value = 47
    ..promptNumber.value = 2
    ..nextNumber.value = 3
    ..currentComboSequence.assignAll([1, 2, 3])
    ..promptTick.value = 5
    ..streak.value = 6
    ..roundsTotal.value = 3
    ..round.value = 1
    ..roundPhase.value = rest ? RoundPhase.rest : RoundPhase.work
    ..roundSecondsLeft.value = rest ? 27 : 84
    ..isCameraUnavailable.value = true;

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
          home: const PromptSessionPage(),
        ),
      ),
    ),
  );
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/images/punching_bag.png'),
      key.currentContext!,
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  final error = tester.takeException();
  await tester.runAsync(() async {
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 1);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(png!.buffer.asUint8List());
  });
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
  expect(error, isNull, reason: '$name: $error');
}

void main() {
  setUpAll(_fonts);
  testWidgets(
    'drill landscape',
    (t) => _shot(t, 'drill_land', const Size(844, 390)),
  );
  testWidgets(
    'drill landscape rest',
    (t) => _shot(t, 'drill_land_rest', const Size(844, 390), rest: true),
  );
  testWidgets(
    'drill portrait',
    (t) => _shot(t, 'drill_phone', const Size(390, 844)),
  );
}
