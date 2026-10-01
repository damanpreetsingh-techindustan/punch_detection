import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../controllers/workout_setup_controller.dart';

class WorkoutSetupPage extends GetView<WorkoutSetupController> {
  const WorkoutSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 16.w : 22.w,
            vertical: isLandscape ? 6.h : 10.h,
          ),
          child: Column(
            children: [
              // Header bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: AppNavigator.back,
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      color: AppColors.textPrimary,
                      size: isLandscape ? 18.w : 22.w,
                    ),
                  ),
                  Text(
                    'Workout Setup',
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: isLandscape ? 14.ts(context) : 16.ts(context),
                    ),
                  ),
                  SizedBox(width: isLandscape ? 18.w : 22.w),
                ],
              ),
              SizedBox(height: isLandscape ? 6.h : 16.h),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prompt Difficulty Cadence',
                        style: AppTextStyles.heading2(context).copyWith(
                          fontSize: isLandscape
                              ? 16.ts(context)
                              : 20.ts(context),
                        ),
                      ),
                      SizedBox(height: isLandscape ? 4.h : 8.h),
                      Text(
                        'Select prompt callout speed. This affects prompt interval (does not change detection).',
                        style: AppTextStyles.bodyMedium(context).copyWith(
                          fontSize: isLandscape
                              ? 10.5.ts(context)
                              : 13.ts(context),
                        ),
                      ),
                      SizedBox(height: isLandscape ? 10.h : 20.h),

                      if (isLandscape)
                        // Landscape 3-Column Cards Grid Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Obx(
                                () => _buildDiffCard(
                                  context: context,
                                  id: 'beginner',
                                  title: 'Beginner',
                                  subtitle:
                                      'Slow callouts (1.2s). Form practice.',
                                  isSelected:
                                      controller.difficulty.value == 'beginner',
                                  onTap: () =>
                                      controller.selectDifficulty('beginner'),
                                  isLandscape: true,
                                ),
                              ),
                            ),
                            8.width,
                            Expanded(
                              child: Obx(
                                () => _buildDiffCard(
                                  context: context,
                                  id: 'intermediate',
                                  title: 'Intermediate',
                                  subtitle:
                                      'Medium callouts (0.6s). Balanced pacing.',
                                  isSelected:
                                      controller.difficulty.value ==
                                      'intermediate',
                                  onTap: () => controller.selectDifficulty(
                                    'intermediate',
                                  ),
                                  isLandscape: true,
                                ),
                              ),
                            ),
                            8.width,
                            Expanded(
                              child: Obx(
                                () => _buildDiffCard(
                                  context: context,
                                  id: 'advanced',
                                  title: 'Advanced',
                                  subtitle:
                                      'Rapid-fire (0.3s). High-intensity.',
                                  isSelected:
                                      controller.difficulty.value == 'advanced',
                                  onTap: () =>
                                      controller.selectDifficulty('advanced'),
                                  isLandscape: true,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        // Portrait Vertical List Cards
                        Column(
                          children: [
                            Obx(
                              () => _buildDiffCard(
                                context: context,
                                id: 'beginner',
                                title: 'Beginner',
                                subtitle:
                                    'Slow prompt callouts (every 1.2s). Great for practicing form.',
                                isSelected:
                                    controller.difficulty.value == 'beginner',
                                onTap: () =>
                                    controller.selectDifficulty('beginner'),
                                isLandscape: false,
                              ),
                            ),
                            12.height,
                            Obx(
                              () => _buildDiffCard(
                                context: context,
                                id: 'intermediate',
                                title: 'Intermediate',
                                subtitle:
                                    'Medium prompt callouts (every 0.6s). Balanced reaction pacing.',
                                isSelected:
                                    controller.difficulty.value ==
                                    'intermediate',
                                onTap: () =>
                                    controller.selectDifficulty('intermediate'),
                                isLandscape: false,
                              ),
                            ),
                            12.height,
                            Obx(
                              () => _buildDiffCard(
                                context: context,
                                id: 'advanced',
                                title: 'Advanced',
                                subtitle:
                                    'Rapid-fire prompt callouts (every 0.3s). High-intensity challenge.',
                                isSelected:
                                    controller.difficulty.value == 'advanced',
                                onTap: () =>
                                    controller.selectDifficulty('advanced'),
                                isLandscape: false,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: isLandscape ? 6.h : 16.h),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: Size(double.infinity, isLandscape ? 38.h : 54.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                onPressed: () =>
                    AppNavigator.toSessionPreCheck(sessionType: 'prompt'),
                child: Text(
                  'Continue to Pre-Session Checks',
                  style: AppTextStyles.buttonLabel(context).copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: isLandscape ? 11.5.ts(context) : 14.ts(context),
                  ),
                ),
              ),
              SizedBox(height: isLandscape ? 4.h : 12.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiffCard({
    required BuildContext context,
    required String id,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    bool isLandscape = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(isLandscape ? 10.r : 16.r),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.selectedBg : AppColors.panel,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.heading3(context).copyWith(
                      fontSize: isLandscape ? 13.ts(context) : 15.ts(context),
                    ),
                  ),
                  SizedBox(height: isLandscape ? 2.h : 4.h),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      fontSize: isLandscape ? 9.5.ts(context) : 12.ts(context),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: isLandscape ? 6.w : 10.w),
            Container(
              width: isLandscape ? 10.r : 12.r,
              height: isLandscape ? 10.r : 12.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
