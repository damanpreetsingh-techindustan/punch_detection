import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../../../../core/widgets/ui/app_buttons.dart';
import '../../../../core/widgets/ui/glass_card.dart';
import '../../../../core/widgets/ui/stat_tile.dart';
import '../../domain/entities/workout_record.dart';
import '../../domain/history_insights.dart';
import '../controllers/history_controller.dart';
import '../widgets/session_tile.dart';
import '../widgets/weekly_punch_chart.dart';

/// Progress: totals, this week's chart, personal bests and every saved
/// session, newest first.
class HistoryPage extends GetView<HistoryController> {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Obx(() {
                if (controller.isLoading.value && controller.records.isEmpty) {
                  return Column(
                    children: [
                      _header(context, canClear: false),
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  );
                }
                if (controller.records.isEmpty) return _empty(context);
                return _content(context);
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, {required bool canClear}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
      child: Row(
        children: [
          GlassIconButton(icon: Icons.arrow_back_rounded, onPressed: Get.back),
          14.width,
          Expanded(child: Text('Progress', style: AppTextStyles.heading2())),
          if (canClear)
            GlassIconButton(
              icon: Icons.delete_outline_rounded,
              color: AppColors.textSecondary,
              onPressed: () => _confirmClear(context),
            ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Column(
      children: [
        _header(context, canClear: false),
        Expanded(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.insights_rounded,
                    size: 72.r,
                    color: AppColors.primary.withValues(alpha: 0.6),
                  ),
                  16.height,
                  Text('No sessions yet', style: AppTextStyles.heading2()),
                  8.height,
                  Text(
                    'Finish a Free Fight or a Reaction Drill and your progress '
                    'shows up here.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium(),
                  ),
                  24.height,
                  PrimaryButton(
                    label: 'Start training',
                    icon: Icons.sports_mma_rounded,
                    onPressed: Get.back,
                  ),
                ],
              ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _content(BuildContext context) {
    final records = controller.records;
    final week = controller.week;
    final weekTotal = week.fold<int>(0, (s, d) => s + d.punches);
    final bests = controller.bests;

    final sections = <Widget>[
      _summary(context, records.length),
      16.height,
      _sectionLabel('This week'),
      GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$weekTotal', style: AppTextStyles.number(null, 28)),
                6.width,
                Text('punches this week', style: AppTextStyles.bodyMedium()),
              ],
            ),
            12.height,
            WeeklyPunchChart(days: week, height: 150.r),
          ],
        ),
      ),
      20.height,
      _sectionLabel('Personal bests'),
      _bests(bests),
      20.height,
      _sectionLabel('Sessions'),
      ..._sessionList(records),
    ];

    return Column(
      children: [
        _header(context, canClear: true),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: controller.loadHistory,
            child: ListView(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
              children: sections
                  .animate(interval: 40.ms)
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.06),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context, int sessions) {
    final streak = controller.dayStreak;
    Widget item(String value, String label, {Color? color}) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.number(
              null,
              24,
            ).copyWith(color: color ?? AppColors.textPrimary),
          ),
          2.height,
          Text(
            label,
            style: AppTextStyles.bodyMedium().copyWith(fontSize: 12.fs),
          ),
        ],
      ),
    );
    return GlassCard(
      padding: EdgeInsets.symmetric(vertical: 16.r, horizontal: 8.r),
      child: Row(
        children: [
          item('$sessions', 'sessions'),
          item('${controller.totalPunches}', 'punches'),
          item(
            '$streak',
            streak == 1 ? 'day streak' : 'days streak',
            color: streak > 0 ? AppColors.gold : null,
          ),
        ],
      ),
    );
  }

  Widget _bests(PersonalBests b) {
    final tiles = <Widget>[
      StatTile(
        label: 'Most punches',
        value: '${b.mostPunches}',
        icon: Icons.emoji_events_rounded,
        accent: AppColors.gold,
      ),
      StatTile(
        label: 'Best pace',
        value: b.bestPace == 0 ? '–' : b.bestPace.round().toString(),
        unit: b.bestPace == 0 ? null : '/ min',
        icon: Icons.bolt_rounded,
      ),
      StatTile(
        label: 'Longest',
        value: DateLabels.duration(b.longestSessionSeconds),
        icon: Icons.timer_outlined,
        accent: AppColors.gold,
      ),
      StatTile(
        label: 'Best streak',
        value: b.longestStreak == 0 ? '–' : '${b.longestStreak}',
        unit: b.longestStreak == 0 ? null : 'in a row',
        icon: Icons.local_fire_department_rounded,
        accent: AppColors.success,
      ),
    ];
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tiles[0]),
            12.width,
            Expanded(child: tiles[1]),
          ],
        ),
        12.height,
        Row(
          children: [
            Expanded(child: tiles[2]),
            12.width,
            Expanded(child: tiles[3]),
          ],
        ),
      ],
    );
  }

  /// Sessions grouped under "Today", "Yesterday", "Mon 12 Nov"…
  List<Widget> _sessionList(List<WorkoutRecord> records) {
    final now = DateTime.now();
    final widgets = <Widget>[];
    String? currentDay;
    for (final r in records) {
      final day = DateLabels.relativeDay(r.date, now);
      if (day != currentDay) {
        currentDay = day;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: 4.w, top: 6.h, bottom: 8.h),
            child: Text(
              day,
              style: AppTextStyles.bodyMedium().copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
      widgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: SessionTile(
            record: r,
            showDay: false,
            onTap: () => controller.openSession(r),
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 10.h),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.tag().copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear all history?', style: AppTextStyles.heading3()),
        content: Text(
          'Every saved session and personal best will be deleted. This '
          'can\'t be undone.',
          style: AppTextStyles.bodyMedium(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTextStyles.bodyLarge()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.clearAllHistory();
            },
            child: Text(
              'Delete',
              style: AppTextStyles.bodyLarge().copyWith(
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
