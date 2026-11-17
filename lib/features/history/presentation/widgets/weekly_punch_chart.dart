import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../../domain/history_insights.dart';

/// Punches per day for the last 7 days, today on the right. One series: the
/// card title names it, so there is no legend. Today's column and the
/// busiest day carry their value; tap any column to see its value.
class WeeklyPunchChart extends StatefulWidget {
  final List<DayTotal> days;
  final double height;

  const WeeklyPunchChart({super.key, required this.days, this.height = 140});

  @override
  State<WeeklyPunchChart> createState() => _WeeklyPunchChartState();
}

class _WeeklyPunchChartState extends State<WeeklyPunchChart> {
  static const double _baseline = 1;

  int? _selected;

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    final maxValue = days.fold<int>(0, (m, d) => math.max(m, d.punches));
    final busiest = maxValue == 0
        ? -1
        : days.indexWhere((d) => d.punches == maxValue);
    final today = days.length - 1;
    final labelHeight = 18.r;
    // Value label + bar + 1px baseline + day label must fit the height;
    // floored so sub-pixel rounding can't push the tallest column over.
    final barArea = (widget.height - labelHeight * 2 - _baseline)
        .floorToDouble();

    return SizedBox(
      height: widget.height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selected = _selected == i ? null : i);
                },
                child: _column(
                  day: days[i],
                  fraction: maxValue == 0 ? 0 : days[i].punches / maxValue,
                  barArea: barArea,
                  labelHeight: labelHeight,
                  isToday: i == today,
                  showValue:
                      days[i].punches > 0 &&
                      (i == today || i == busiest || i == _selected),
                  selected: i == _selected,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _column({
    required DayTotal day,
    required double fraction,
    required double barArea,
    required double labelHeight,
    required bool isToday,
    required bool showValue,
    required bool selected,
  }) {
    // Empty days keep a 2px stub so the week still reads as seven slots.
    final barHeight = math.max(2.0, barArea * fraction);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: labelHeight,
          child: showValue
              ? Text(
                  '${day.punches}',
                  style: AppTextStyles.number(null, 11).copyWith(
                    color: selected || isToday
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    letterSpacing: 0,
                  ),
                )
              : null,
        ),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: barHeight),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, h, _) => Container(
            width: 22.r,
            height: h,
            decoration: BoxDecoration(
              // Same hue for every day; today is full strength.
              color: day.punches == 0
                  ? AppColors.stroke
                  : AppColors.primary.withValues(
                      alpha: isToday || selected ? 1 : 0.55,
                    ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ),
        ),
        // Baseline under every column.
        Container(height: _baseline, color: AppColors.stroke),
        SizedBox(
          height: labelHeight,
          child: Center(
            child: Text(
              isToday ? 'Today' : DateLabels.weekdayInitial(day.day),
              style: AppTextStyles.bodyMedium().copyWith(
                fontSize: 11.fs,
                color: isToday
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
