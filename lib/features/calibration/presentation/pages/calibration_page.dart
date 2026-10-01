import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../controllers/calibration_controller.dart';

class CalibrationPage extends GetView<CalibrationController> {
  const CalibrationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Column(
            children: [
              // Header
              Text(
                'Ambient & Phone Mount Calibration',
                style: AppTextStyles.heading2(context),
                textAlign: TextAlign.center,
              ),
              12.height,
              Text(
                'Measuring ambient gym noise floor and validating phone mount framing...',
                style: AppTextStyles.bodyMedium(context),
                textAlign: TextAlign.center,
              ),
              32.height,

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Countdown Progress Ring
                        Obx(() {
                          final seconds = controller.secondsRemaining.value;
                          final progress = controller.progressRatio.value;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: isLandscape ? 140.w : 180.w,
                                height: isLandscape ? 140.w : 180.w,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 10.w,
                                  backgroundColor: AppColors.surface,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$seconds',
                                    style: AppTextStyles.heading1(context).copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    'SECONDS',
                                    style: AppTextStyles.tag(context),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }),
                        32.height,

                        // Real-time RMS Noise Indicator
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Ambient Noise Floor:',
                                    style: AppTextStyles.bodyLarge(context),
                                  ),
                                  Obx(() {
                                    final rms = controller.currentRms.value;
                                    return Text(
                                      '${(rms * 100).toStringAsFixed(1)} dB RMS',
                                      style: AppTextStyles.bodyLarge(context).copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  }),
                                ],
                              ),
                              12.height,

                              // Simulated Audio Level Bar
                              Obx(() {
                                return LinearProgressIndicator(
                                  value: controller.currentRms.value.clamp(0.0, 1.0),
                                  backgroundColor: AppColors.background,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                  minHeight: 8.h,
                                );
                              }),
                            ],
                          ),
                        ),
                        24.height,

                        // Status Badge
                        Obx(() {
                          final isDone = !controller.isCalibrating.value;
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                            decoration: BoxDecoration(
                              color: isDone ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: isDone ? AppColors.primary : AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isDone ? Icons.check_circle : Icons.graphic_eq,
                                  color: isDone ? AppColors.primary : AppColors.textMuted,
                                  size: 20.w,
                                ),
                                8.width,
                                Text(
                                  isDone ? 'Calibration Complete!' : 'Calibrating Sensors...',
                                  style: AppTextStyles.bodyLarge(context).copyWith(
                                    color: isDone ? AppColors.primary : AppColors.textMuted,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
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
