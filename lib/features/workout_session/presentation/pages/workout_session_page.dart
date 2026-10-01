import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../../domain/entities/workout_state.dart';
import '../controllers/workout_session_controller.dart';

class WorkoutSessionPage extends GetView<WorkoutSessionController> {
  const WorkoutSessionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Obx(() {
          final state = controller.workoutState.value;

          if (state == WorkoutState.countdown) {
            return _buildCountdownView(context);
          }

          return _buildActiveWorkoutView(context);
        }),
      ),
    );
  }

  Widget _buildCountdownView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'GET READY',
            style: AppTextStyles.heading2(context).copyWith(
              letterSpacing: 2.0,
              color: AppColors.textMuted,
            ),
          ),
          24.height,
          Obx(() {
            return Text(
              '${controller.countdownSeconds.value}',
              style: AppTextStyles.heading1(context).copyWith(
                fontSize: 96.sp,
                color: AppColors.primary,
              ),
            );
          }),
          16.height,
          Text(
            'Mount your phone & face the bag',
            style: AppTextStyles.bodyMedium(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveWorkoutView(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: Column(
        children: [
          // Top Control Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
                onPressed: () => controller.finishWorkout(),
              ),
              Obx(() {
                final state = controller.workoutState.value;
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: state == WorkoutState.paused
                        ? AppColors.amber.withValues(alpha: 0.2)
                        : AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: state == WorkoutState.paused ? AppColors.amber : AppColors.primary,
                    ),
                  ),
                  child: Text(
                    state == WorkoutState.paused ? 'PAUSED' : 'ROUND 1 OF 3',
                    style: AppTextStyles.tag(context).copyWith(
                      color: state == WorkoutState.paused ? AppColors.amber : AppColors.primary,
                    ),
                  ),
                );
              }),
              Obx(() {
                final isPaused = controller.workoutState.value == WorkoutState.paused;
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
          12.height,

          // Current Callout Banner
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 20.h),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.border, width: 2.w),
            ),
            child: Column(
              children: [
                Text(
                  'CURRENT CALL-OUT',
                  style: AppTextStyles.tag(context),
                ),
                8.height,
                Obx(() {
                  return Text(
                    controller.currentCallout.value,
                    style: AppTextStyles.heading1(context).copyWith(
                      fontSize: isLandscape ? 40.sp : 52.sp,
                      color: AppColors.primary,
                    ),
                  );
                }),
              ],
            ),
          ),
          16.height,

          // Main Live Metrics Tiles
          Expanded(
            child: Row(
              children: [
                // Punch Count Tile
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fitness_center, color: AppColors.primary, size: 32.w),
                        8.height,
                        Text('PUNCHES', style: AppTextStyles.tag(context)),
                        8.height,
                        Obx(() {
                          return Text(
                            '${controller.stats.value.totalPunches}',
                            style: AppTextStyles.heading1(context).copyWith(
                              fontSize: 44.sp,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                16.width,

                // Reaction Speed Meter Tile
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.speed, color: AppColors.secondary, size: 32.w),
                        8.height,
                        Text('REACTION TIME', style: AppTextStyles.tag(context).copyWith(color: AppColors.secondary)),
                        8.height,
                        Obx(() {
                          final stats = controller.stats.value;
                          return Column(
                            children: [
                              Text(
                                '${stats.lastReactionMs} ms',
                                style: AppTextStyles.heading1(context).copyWith(
                                  fontSize: 36.sp,
                                  color: AppColors.secondary,
                                ),
                              ),
                              Text(
                                stats.lastRating,
                                style: AppTextStyles.tag(context).copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          16.height,

          // Round Timer & Finish Button
          Row(
            children: [
              Expanded(
                child: Obx(() {
                  final remaining = controller.roundSecondsRemaining.value;
                  final min = (remaining ~/ 60).toString().padLeft(2, '0');
                  final sec = (remaining % 60).toString().padLeft(2, '0');
                  return Container(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Center(
                      child: Text(
                        '$min:$sec REMAINING',
                        style: AppTextStyles.heading3(context),
                      ),
                    ),
                  );
                }),
              ),
              12.width,
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                onPressed: () => controller.finishWorkout(),
                child: Text(
                  'END WORKOUT',
                  style: AppTextStyles.buttonLabel(context).copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
