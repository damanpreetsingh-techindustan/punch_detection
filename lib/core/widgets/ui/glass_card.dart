import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_colors.dart';

/// Frosted surface card. Set [blur] when it sits over the camera feed.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  final bool blur;
  final Gradient? gradient;
  final Color? borderColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius,
    this.blur = false,
    this.gradient,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius ?? 22.r);
    final box = Container(
      padding: padding ?? EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: gradient == null
            ? (blur ? AppColors.bg.withValues(alpha: 0.45) : AppColors.surface)
            : null,
        gradient: gradient,
        borderRadius: r,
        border: Border.all(color: borderColor ?? AppColors.glassStroke),
      ),
      child: child,
    );
    if (!blur) return box;
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: box,
      ),
    );
  }
}

/// Screen background: near-black with a soft ember glow from the top.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.bg),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGlow),
        child: child,
      ),
    );
  }
}
