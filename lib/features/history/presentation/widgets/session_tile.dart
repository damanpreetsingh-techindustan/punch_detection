import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../../../../core/widgets/ui/press_scale.dart';
import '../../domain/entities/workout_record.dart';
import '../../domain/history_insights.dart';

/// One saved session in a list: mode icon, mode and when, punches, time.
class SessionTile extends StatelessWidget {
  final WorkoutRecord record;
  final VoidCallback? onTap;

  /// false under a day heading (History), so the day isn't repeated.
  final bool showDay;

  const SessionTile({
    super.key,
    required this.record,
    this.onTap,
    this.showDay = true,
  });

  static String modeLabel(WorkoutRecord r) {
    if (!r.isDrill) return 'Free Fight';
    final d = r.difficulty;
    if (d == null || d.isEmpty) return 'Reaction Drill';
    return 'Drill · ${d[0].toUpperCase()}${d.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final r = record;
    final now = DateTime.now();
    return PressScale(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: AppColors.glassStroke),
        ),
        child: Row(
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                color: (r.isDrill ? AppColors.gold : AppColors.primary)
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                r.isDrill ? Icons.bolt_rounded : Icons.sports_mma_rounded,
                color: r.isDrill ? AppColors.gold : AppColors.primary,
                size: 20.r,
              ),
            ),
            SizedBox(width: 12.r),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modeLabel(r),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLarge().copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2.r),
                  Text(
                    [
                      if (showDay) DateLabels.relativeDay(r.date, now),
                      DateLabels.time(r.date),
                      DateLabels.duration(r.durationSeconds),
                    ].join(' · '),
                    style: AppTextStyles.bodyMedium(),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${r.totalPunches}',
                  style: AppTextStyles.number(null, 22),
                ),
                Text(
                  'punches',
                  style: AppTextStyles.bodyMedium().copyWith(fontSize: 11.fs),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
