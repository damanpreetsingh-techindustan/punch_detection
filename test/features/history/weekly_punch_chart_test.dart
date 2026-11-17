import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/history/domain/history_insights.dart';
import 'package:punch_detection_demo/features/history/presentation/widgets/weekly_punch_chart.dart';

void main() {
  for (final height in [120.0, 150.0, 150.3, 177.7]) {
    testWidgets('no overflow at height $height with a full-height bar', (
      tester,
    ) async {
      final today = DateTime(2026, 11, 17);
      final days = [
        for (var i = 6; i >= 0; i--)
          DayTotal(
            DateTime(today.year, today.month, today.day - i),
            i == 0 ? 500 : i * 37,
          ),
      ];
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            home: Scaffold(
              body: Center(
                child: WeeklyPunchChart(days: days, height: height),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
