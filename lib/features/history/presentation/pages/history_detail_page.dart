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
import '../widgets/session_tile.dart';

/// One saved session. Route argument: the [WorkoutRecord].
class HistoryDetailPage extends StatelessWidget {
  const HistoryDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Get.arguments as WorkoutRecord;
    final pace = r.durationSeconds < 10
        ? '–'
        : r.punchesPerMinute.round().toString();
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
      if (r.isDrill) ...[
        StatTile(
          label: 'Best streak',
          value: '${r.bestStreak}',
          unit: 'in a row',
          icon: Icons.local_fire_department_rounded,
          accent: AppColors.gold,
        ),
        StatTile(
          label: 'Answered',
          value: r.callsMade == 0
              ? '–'
              : '${(r.callsAnswered * 100 / r.callsMade).round()}%',
          unit: r.callsMade == 0 ? null : '${r.callsAnswered}/${r.callsMade}',
          icon: Icons.check_circle_outline_rounded,
          accent: AppColors.success,
        ),
      ],
    ];

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                children: [
                  Row(
                    children: [
                      GlassIconButton(
                        icon: Icons.arrow_back_rounded,
                        onPressed: Get.back,
                      ),
                      14.width,
                      Expanded(
                        child: Text(
                          SessionTile.modeLabel(r),
                          style: AppTextStyles.heading2(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  24.height,
                  GlassCard(
                    child: Column(
                      children: [
                        Text(
                          '${DateLabels.relativeDay(r.date, DateTime.now())} · '
                          '${DateLabels.time(r.date)}',
                          style: AppTextStyles.bodyMedium(),
                        ),
                        8.height,
                        Text(
                          '${r.totalPunches}',
                          style: AppTextStyles.number(null, 80),
                        ),
                        Text(
                          'punches',
                          style: AppTextStyles.bodyLarge().copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  16.height,
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
                ].animate(interval: 50.ms).fadeIn(duration: 300.ms).slideY(begin: 0.08),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
