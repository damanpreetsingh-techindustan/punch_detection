import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/common_function.dart';
import '../../../../core/utils/size_box.dart';
import '../../../../core/widgets/dev_only.dart';
import '../../../../core/widgets/ui/app_buttons.dart';
import '../../../../core/widgets/ui/confetti_burst.dart';
import '../../../../core/widgets/ui/glass_card.dart';
import '../../../../core/widgets/ui/stat_tile.dart';
import '../../../history/domain/history_insights.dart';
import '../controllers/results_controller.dart';
import '../widgets/result_share_sheet.dart';
import '../widgets/results_dev_panel.dart';

/// End of a session: the total counts up with confetti, records and "vs last
/// time" chips, the key stats, then Train again / Share / Done. The session
/// is saved to History by [ResultsController].
class ResultsPage extends GetView<ResultsController> {
  const ResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isLandscape = CommonFunction.checkOrientationLandscape(context);
    final hasPunches = controller.result.totalPunches > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.done();
      },
      child: Scaffold(
        body: Stack(
          children: [
            AppBackground(
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isLandscape ? 900 : 560,
                    ),
                    child: isLandscape
                        ? _landscape(context)
                        : _portrait(context),
                  ),
                ),
              ),
            ),
            if (hasPunches) const Positioned.fill(child: ConfettiBurst()),
          ],
        ),
      ),
    );
  }

  Widget _portrait(BuildContext context) {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      children:
          [
                _topBar(),
                8.height,
                _hero(context),
                20.height,
                _stats(context),
                12.height,
                _todayLine(context),
                24.height,
                _actions(context),
                _devPanel(),
              ]
              .animate(interval: 70.ms)
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.1, curve: Curves.easeOutCubic),
    );
  }

  Widget _landscape(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: _hero(context).animate().fadeIn(duration: 350.ms),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ListView(
              children: [
                _topBar(),
                _stats(context),
                10.height,
                _todayLine(context),
                16.height,
                _actions(context),
                _devPanel(),
              ].animate(interval: 60.ms).fadeIn(duration: 300.ms),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Align(
      alignment: Alignment.centerRight,
      child: GlassIconButton(
        icon: Icons.close_rounded,
        onPressed: controller.done,
      ),
    );
  }

  // ─── Hero ────────────────────────────────────────────────────────────────

  Widget _hero(BuildContext context) {
    final total = controller.result.totalPunches;
    return Column(
      children: [
        Text(
          total > 0 ? 'SESSION COMPLETE' : 'SESSION ENDED',
          style: AppTextStyles.tag(),
        ),
        6.height,
        Text(
          controller.title,
          textAlign: TextAlign.center,
          style: AppTextStyles.heading2(),
        ),
        12.height,
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: total),
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Text(
            '$value',
            style: AppTextStyles.number(null, 104).copyWith(
              shadows: [
                Shadow(
                  color: AppColors.primary.withValues(alpha: 0.6),
                  blurRadius: 40,
                ),
              ],
            ),
          ),
        ),
        Text(
          'punches',
          style: AppTextStyles.bodyLarge().copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        16.height,
        if (total == 0)
          Text(
            'No punches were counted this time. Check that your face and '
            'shoulders are in view and try again.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium(),
          )
        else
          _highlightChips(),
      ],
    );
  }

  Widget _highlightChips() {
    return Obx(() {
      final h = controller.highlights.value;
      if (h == null) return SizedBox(height: 34.r);
      final chips = <Widget>[
        if (controller.lessonCompleted.value != null)
          _chip(
            Icons.school_rounded,
            controller.lessonCompleted.value!,
            AppColors.success,
          ),
        if (h.firstSession)
          _chip(
            Icons.celebration_rounded,
            'First session saved!',
            AppColors.gold,
          ),
        if (h.newMostPunches)
          _chip(
            Icons.emoji_events_rounded,
            'New record: most punches',
            AppColors.gold,
          ),
        if (h.newBestPace)
          _chip(Icons.bolt_rounded, 'New best pace', AppColors.gold),
        if (h.newBestStreak)
          _chip(
            Icons.local_fire_department_rounded,
            'New best streak',
            AppColors.gold,
          ),
        if (h.punchesVsLast != null) _vsLastChip(h.punchesVsLast!),
      ];
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 8.r,
        runSpacing: 8.r,
        children: chips
            .animate(interval: 120.ms)
            .fadeIn(duration: 300.ms)
            .scaleXY(begin: 0.8, curve: Curves.easeOutBack),
      );
    });
  }

  Widget _vsLastChip(int diff) {
    if (diff > 0) {
      return _chip(
        Icons.trending_up_rounded,
        '+$diff vs last time',
        AppColors.success,
      );
    }
    if (diff == 0) {
      return _chip(
        Icons.trending_flat_rounded,
        'Same as last time',
        AppColors.textSecondary,
      );
    }
    return _chip(
      Icons.trending_down_rounded,
      '$diff vs last time',
      AppColors.textSecondary,
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 7.r),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15.r),
          SizedBox(width: 6.r),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyLarge().copyWith(
                fontSize: 13.fs,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats ───────────────────────────────────────────────────────────────

  Widget _stats(BuildContext context) {
    final r = controller.result;
    final drill = r.drill;
    // Pace over a few seconds is noise: show it from 10 s.
    final pace = r.durationSeconds < 10
        ? '–'
        : controller.pace.round().toString();
    final tiles = <Widget>[
      StatTile(
        label: 'Time',
        value: DateLabels.duration(r.durationSeconds),
        icon: Icons.timer_outlined,
        accent: AppColors.gold,
      ),
      StatTile(
        label: 'Pace',
        value: pace,
        unit: '/ min',
        icon: Icons.bolt_rounded,
      ),
      if (drill != null) ...[
        StatTile(
          label: 'Best streak',
          value: '${drill.bestStreak}',
          unit: 'in a row',
          icon: Icons.local_fire_department_rounded,
          accent: AppColors.gold,
        ),
        StatTile(
          label: 'Answered',
          value: drill.callsMade == 0
              ? '–'
              : '${(drill.callsAnswered * 100 / drill.callsMade).round()}%',
          unit: drill.callsMade == 0
              ? null
              : '${drill.callsAnswered}/${drill.callsMade}',
          icon: Icons.check_circle_outline_rounded,
          accent: AppColors.success,
        ),
      ],
    ];
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) 12.height,
          Row(
            children: [
              Expanded(child: tiles[i]),
              12.width,
              Expanded(
                child: i + 1 < tiles.length
                    ? tiles[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// "Today 240 punches · 🔥 3-day streak"
  Widget _todayLine(BuildContext context) {
    return Obx(() {
      final h = controller.highlights.value;
      if (h == null || !controller.isSaved) return const SizedBox.shrink();
      return GlassCard(
        padding: EdgeInsets.symmetric(horizontal: 16.r, vertical: 12.r),
        child: Row(
          children: [
            Icon(Icons.today_rounded, color: AppColors.primary, size: 18.r),
            8.width,
            Expanded(
              child: Text.rich(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                TextSpan(
                  style: AppTextStyles.bodyMedium(),
                  children: [
                    const TextSpan(text: 'Today  '),
                    TextSpan(
                      text: '${h.todayPunches}',
                      style: AppTextStyles.number(null, 15),
                    ),
                    const TextSpan(text: ' punches'),
                  ],
                ),
              ),
            ),
            if (h.dayStreak > 0) ...[
              Icon(
                Icons.local_fire_department_rounded,
                color: AppColors.gold,
                size: 18.r,
              ),
              4.width,
              Flexible(
                child: Text(
                  '${h.dayStreak}-day streak',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium().copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  Widget _actions(BuildContext context) {
    final hasPunches = controller.result.totalPunches > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton(
          label: 'Train again',
          icon: Icons.replay_rounded,
          onPressed: controller.trainAgain,
        ),
        10.height,
        Row(
          children: [
            if (hasPunches) ...[
              Expanded(
                child: GhostButton(
                  label: 'Share',
                  icon: Icons.ios_share_rounded,
                  onPressed: () => showResultShareSheet(context, controller),
                ),
              ),
              10.width,
            ],
            Expanded(
              child: GhostButton(
                label: 'Done',
                icon: Icons.check_rounded,
                onPressed: controller.done,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _devPanel() {
    return DevOnly(
      child: Padding(
        padding: EdgeInsets.only(top: 24.h),
        child: ResultsDevPanel(result: controller.result),
      ),
    );
  }
}
