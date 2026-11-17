import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'press_scale.dart';

/// Ember-gradient call-to-action button.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double? height;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: loading ? null : onPressed,
      child: Container(
        height: height ?? 56.h,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: loading
            ? SizedBox(
                width: 22.r,
                height: 22.r,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.onPrimary,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: AppColors.onPrimary, size: 20.r),
                    SizedBox(width: 8.w),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.buttonLabel(context),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Quiet outlined button for secondary actions.
class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final double? height;

  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color = AppColors.textPrimary,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onPressed,
      child: Container(
        height: height ?? 56.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: AppColors.glassStroke),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: color, size: 20.r),
              SizedBox(width: 8.w),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.buttonLabel(
                  context,
                ).copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round translucent icon button for HUD bars (close, pause, sound).
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double? size;
  final Color color;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size,
    this.color = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final s = size ?? 44.r;
    return PressScale(
      onTap: onPressed,
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          color: AppColors.bg.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.glassStroke),
        ),
        child: Icon(icon, color: color, size: s * 0.48),
      ),
    );
  }
}
