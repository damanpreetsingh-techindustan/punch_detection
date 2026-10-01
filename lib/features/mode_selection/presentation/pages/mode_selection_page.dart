import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../controllers/mode_selection_controller.dart';

class ModeSelectionPage extends GetView<ModeSelectionController> {
  const ModeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.w),
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    16.height,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: AppNavigator.back,
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Select Mode',
                          style: AppTextStyles.bodyMedium(
                            context,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    24.height,
                    Text(
                      'Choose Session Mode',
                      style: AppTextStyles.heading2(context),
                    ),
                    8.height,
                    Text(
                      'Prompt Mode tracks reaction time per hit. Free Mode offers open punch counting.',
                      style: AppTextStyles.bodyMedium(context),
                    ),
                    24.height,

                    Obx(
                      () => _buildModeCard(
                        context: context,
                        id: 'prompt',
                        title: 'PROMPT MODE',
                        description:
                            'App calls out numbered combos via text-to-speech. Measures reaction speed in ms.',
                        icon: Icons.sports_kabaddi,
                        isSelected: controller.selectedMode.value == 'prompt',
                        onTap: () => controller.selectMode('prompt'),
                      ),
                    ),
                    14.height,
                    Obx(
                      () => _buildModeCard(
                        context: context,
                        id: 'free',
                        title: 'FREE MODE',
                        description:
                            'No prompts or timing. Continuous open punch counting for heavy-bag sessions.',
                        icon: Icons.timer_outlined,
                        isSelected: controller.selectedMode.value == 'free',
                        onTap: () => controller.selectMode('free'),
                      ),
                    ),

                    const Spacer(),
                    24.height,
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: Size(double.infinity, 54.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      onPressed: () {
                        if (controller.selectedMode.value == 'prompt') {
                          AppNavigator.toWorkoutSetup();
                        } else {
                          AppNavigator.toSessionPreCheck(sessionType: 'free');
                        }
                      },
                      child: Text(
                        'Continue',
                        style: AppTextStyles.buttonLabel(context).copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    20.height,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required String id,
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(18.r),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.selectedBg : AppColors.panel,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44.r,
              height: 44.r,
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.panel2,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.border,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6.r),
                child: Image.asset(
                  'assets/images/app_ic.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    icon,
                    color: isSelected ? AppColors.primary : AppColors.textMuted,
                    size: 24.r,
                  ),
                ),
              ),
            ),
            14.width,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.heading3(context).copyWith(
                      fontSize: 16.ts(context),
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  4.height,
                  Text(
                    description,
                    style: AppTextStyles.bodyMedium(
                      context,
                    ).copyWith(fontSize: 12.ts(context)),
                  ),
                ],
              ),
            ),
            Container(
              width: 14.r,
              height: 14.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : AppColors.border,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.6),
                          blurRadius: 10,
                        ),
                      ]
                    : [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
