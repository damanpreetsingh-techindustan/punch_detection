import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_colors.dart';

/// Animated horizontal progress bar (daily free-tier meter, setup progress).
class MeterBar extends StatelessWidget {
  /// 0.0 – 1.0
  final double value;
  final double? height;
  final Gradient gradient;

  const MeterBar({
    super.key,
    required this.value,
    this.height,
    this.gradient = AppColors.primaryGradient,
  });

  @override
  Widget build(BuildContext context) {
    final h = height ?? 8.h;
    return ClipRRect(
      borderRadius: BorderRadius.circular(h),
      child: Container(
        height: h,
        color: AppColors.surfaceRaised,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => FractionallySizedBox(
            widthFactor: v,
            // Without this the fill gets 0 height (the aligned parent passes
            // loose constraints) and the bar looks empty.
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(h),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
