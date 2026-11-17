import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import 'package:punch_detection_demo/features/paywall/presentation/bindings/paywall_binding.dart';
import 'package:punch_detection_demo/features/paywall/presentation/pages/paywall_page.dart';

Future<void> _open(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Get.reset();
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, _) => GetMaterialApp(
        initialRoute: '/paywall',
        getPages: [
          GetPage(
            name: '/paywall',
            page: () => const PaywallPage(),
            binding: PaywallBinding(),
          ),
        ],
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('yearly is selected; choosing a plan changes the button', (
    tester,
  ) async {
    await _open(tester, const Size(390, 844));
    expect(
      find.text('Start ${AppConstants.yearlyTrialDays}-day free trial'),
      findsOneWidget,
    );
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('SAVE 50%'),
      100,
      scrollable: list,
    );
    expect(find.text('SAVE 50%'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('MONTHLY'),
      100,
      scrollable: list,
    );
    await tester.tap(find.text('MONTHLY'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Subscribe monthly'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('LIFETIME'),
      100,
      scrollable: list,
    );
    await tester.tap(find.text('LIFETIME'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Buy lifetime access'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape renders without overflow', (tester) async {
    await _open(tester, const Size(844, 390));
    await tester.scrollUntilVisible(
      find.text('Restore purchases'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Let the staggered entrance timers of rows scrolled into view finish.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
