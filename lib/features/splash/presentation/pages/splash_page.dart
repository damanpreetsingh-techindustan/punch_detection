import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../controllers/splash_controller.dart';

class SplashPage extends GetView<SplashController> {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    controller;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88.r,
                    height: 88.r,
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFF080B2B),
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(color: AppColors.primary, width: 2.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.r),
                      child: Image.asset(
                        'assets/images/app_ic.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.sports_mma_rounded,
                          color: AppColors.cyanHighlight,
                          size: 40.r,
                        ),
                      ),
                    ),
                  ),
                  24.height,
                  Text(
                    'HYPER HITTER',
                    style: AppTextStyles.heading1(context).copyWith(
                      letterSpacing: 2.w,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  8.height,
                  Text(
                    'Punch Detection Engine',
                    style: AppTextStyles.bodyMedium(context),
                  ),
                  48.height,
                  SizedBox(
                    width: 24.r,
                    height: 24.r,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
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
                  style: AppTextStyles.tag(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
