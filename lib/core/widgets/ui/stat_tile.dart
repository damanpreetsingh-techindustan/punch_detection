import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'glass_card.dart';

/// Small label + big number tile (results, history, home).
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final Color accent;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.accent = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14.r, color: accent),
                SizedBox(width: 6.w),
              ],
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.tag(
                    context,
                  ).copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: value,
                style: AppTextStyles.number(context, 28),
                children: [
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      // Reset the number style's tight letter spacing.
                      style: AppTextStyles.bodyMedium(
                        context,
                      ).copyWith(letterSpacing: 0),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
