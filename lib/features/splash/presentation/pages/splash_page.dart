import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/utils/size_box.dart';
import '../../../../core/widgets/knockup_logo.dart';
import '../../../../core/widgets/ui/glass_card.dart';
import '../controllers/splash_controller.dart';

class SplashPage extends GetView<SplashController> {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    controller;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KnockUpMark(size: 96.r)
                        .animate()
                        .scale(
                          begin: const Offset(0.4, 0.4),
                          duration: 650.ms,
                          curve: Curves.easeOutBack,
                        )
                        .fadeIn(duration: 300.ms)
                        .then(delay: 150.ms)
                        .shake(hz: 3, rotation: 0.05, duration: 350.ms),
                    28.height,
                    Text.rich(
                          TextSpan(
                            style: AppTextStyles.display(context),
                            children: const [
                              TextSpan(text: 'Knock'),
                              TextSpan(
                                text: 'Up',
                                style: TextStyle(color: AppColors.primary),
                              ),
                            ],
                          ),
                        )
                        .animate(delay: 350.ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.4, curve: Curves.easeOutCubic),
                    10.height,
                    Text(
                      AppConstants.tagline,
                      style: AppTextStyles.bodyMedium(context),
                    ).animate(delay: 600.ms).fadeIn(duration: 400.ms),
                  ],
                ),
              ),
              Positioned(
                bottom: 24.h,
                left: 0,
                right: 0,
                child: Obx(
                  () => Text(
                    controller.versionDisplay.value,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.tag(
                      context,
                    ).copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
