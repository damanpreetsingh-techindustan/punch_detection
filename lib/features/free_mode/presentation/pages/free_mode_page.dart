import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../../domain/entities/free_mode_stats.dart';
import '../controllers/free_mode_controller.dart';
import '../../../../core/widgets/animated_punch_count_text.dart';

class FreeModePage extends GetView<FreeModeController> {
  const FreeModePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Column(
            children: [
              // Header Control Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
                    onPressed: () => controller.endSession(),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Text(
                      'FREE MODE',
                      style: AppTextStyles.tag(context),
                    ),
                  ),
                  Obx(() {
                    final isPaused = controller.isPaused.value;
                    return IconButton(
                      icon: Icon(
                        isPaused ? Icons.play_arrow : Icons.pause,
                        color: AppColors.primary,
                        size: 28.w,
                      ),
                      onPressed: () => controller.togglePause(),
                    );
                  }),
                ],
              ),
              16.height,

              // PPM Cadence Meter Dial
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Obx(() {
                          final stats = controller.stats.value;
                          final ppm = stats.punchesPerMinute;
                          return Container(
                            width: 200.w,
                            height: 200.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surface,
                              border: Border.all(
                                color: _getIntensityColor(stats.intensityLevel),
                                width: 8.w,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$ppm',
                                  style: AppTextStyles.heading1(context).copyWith(
                                    fontSize: 56.sp,
                                    color: _getIntensityColor(stats.intensityLevel),
                                  ),
                                ),
                                Text(
                                  'PPM CADENCE',
                                  style: AppTextStyles.tag(context),
                                ),
                              ],
                            ),
                          );
                        }),
                        24.height,

                        // Intensity Meter Bar
                        Obx(() {
                          final intensity = controller.stats.value.intensityLevel;
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                            decoration: BoxDecoration(
                              color: _getIntensityColor(intensity).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(color: _getIntensityColor(intensity)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt, color: _getIntensityColor(intensity), size: 20.w),
                                8.width,
                                Text(
                                  'INTENSITY: ${intensity.name.toUpperCase()}',
                                  style: AppTextStyles.bodyLarge(context).copyWith(
                                    color: _getIntensityColor(intensity),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        32.height,

                        // Total Punches & Session Timer Tiles
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(16.w),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  children: [
                                    Text('TOTAL PUNCHES', style: AppTextStyles.tag(context)),
                                    8.height,
                                    Obx(() {
                                      return AnimatedPunchCountText(
                                        count: controller.stats.value.totalPunches,
                                        style: AppTextStyles.heading1(context).copyWith(fontSize: 36.sp),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                            16.width,
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(16.w),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  children: [
                                    Text('ELAPSED TIME', style: AppTextStyles.tag(context)),
                                    8.height,
                                    Obx(() {
                                      final sec = controller.elapsedSeconds.value;
                                      final minStr = (sec ~/ 60).toString().padLeft(2, '0');
                                      final secStr = (sec % 60).toString().padLeft(2, '0');
                                      return Text(
                                        '$minStr:$secStr',
                                        style: AppTextStyles.heading1(context).copyWith(fontSize: 36.sp),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // End Workout Button
              16.height,
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  onPressed: () => controller.endSession(),
                  child: Text('END FREE MODE', style: AppTextStyles.buttonLabel(context).copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getIntensityColor(WorkoutIntensity intensity) {
    switch (intensity) {
      case WorkoutIntensity.moderate:
        return AppColors.secondary;
      case WorkoutIntensity.high:
        return AppColors.primary;
      case WorkoutIntensity.peak:
        return AppColors.red;
    }
  }
}
