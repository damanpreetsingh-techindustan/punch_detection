import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/common_function.dart';
import '../../../../core/utils/size_box.dart';
import '../controllers/onboarding_controller.dart';

class OnboardingFlowPage extends GetView<OnboardingController> {
  const OnboardingFlowPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.w),
          child: Column(
            children: [
              12.height,

              // Top Header with Back button and Step indicator
              Obx(
                () => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: controller.previousStep,
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Step ${controller.currentStep.value + 1} of 3',
                      style: AppTextStyles.bodyMedium(
                        context,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),

              8.height,

              // 3-Segment Progress Bar
              Obx(
                () => Row(
                  children: List.generate(
                    3,
                    (index) => Expanded(
                      child: Container(
                        height: 4.h,
                        margin: EdgeInsets.symmetric(horizontal: 2.w),
                        decoration: BoxDecoration(
                          color: index <= controller.currentStep.value
                              ? AppColors.primary
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              16.height,

              // 3-Step PageView
              Expanded(
                child: PageView(
                  controller: controller.pageController,
                  onPageChanged: controller.onPageChanged,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildStep1AppInfo(context),
                    _buildStep2Permissions(context),
                    _buildStep3MountGuide(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // STEP 1: APP INFO & OVERVIEW
  Widget _buildStep1AppInfo(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PUNCH DETECTION ENGINE',
                    style: AppTextStyles.tag(context),
                  ),
                  8.height,
                  Text(
                    'Turn your mounted phone into a real-time punch detector.',
                    style: AppTextStyles.heading2(context),
                  ),
                  10.height,
                  Text(
                    'Hyper Hitter combines impact audio and camera-based motion confirmation to count punches and measure reaction time directly on your device.',
                    style: AppTextStyles.bodyMedium(context),
                  ),
                  20.height,

                  // Hero Graphic Box
                  Container(
                    height: CommonFunction.checkOrientationLandscape(context)
                        ? 0.4.sh
                        : 180.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1218),
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sports_kabaddi,
                            size: 54.r,
                            color: AppColors.primary,
                          ),
                          8.height,
                          Text(
                            'On-Device Audio + Vision Fusion',
                            style: AppTextStyles.heading3(
                              context,
                            ).copyWith(fontSize: 15.ts(context)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  16.height,
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: const [
                      _Chip(label: 'Works offline'),
                      _Chip(label: 'No external sensors'),
                      _Chip(label: 'iOS & Android'),
                    ],
                  ),

                  const Spacer(),
                  16.height,
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: Size(double.infinity, 54.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    onPressed: controller.nextStep,
                    child: Text(
                      'Set up punch detection',
                      style: AppTextStyles.buttonLabel(context).copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  16.height,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // STEP 2: PERMISSIONS
  Widget _buildStep2Permissions(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Allow on-device detection',
                    style: AppTextStyles.heading2(context),
                  ),
                  8.height,
                  Text(
                    'Microphone audio is the primary punch signal. Camera motion provides secondary confirmation.',
                    style: AppTextStyles.bodyMedium(context),
                  ),
                  20.height,

                  Obx(
                    () => _permissionCard(
                      context: context,
                      icon: '🎙',
                      title: 'Microphone access (Required)',
                      subtitle:
                          'Detects energy spikes, impact frequency and impact shape.',
                      isGranted: controller.micGranted.value,
                      onTap: controller.requestMicrophone,
                    ),
                  ),
                  12.height,
                  Obx(
                    () => _permissionCard(
                      context: context,
                      icon: '◉',
                      title: 'Camera access (Required)',
                      subtitle:
                          'Confirms shoulder, elbow and wrist movement using pose estimation.',
                      isGranted: controller.cameraGranted.value,
                      onTap: controller.requestCamera,
                    ),
                  ),
                  12.height,
                  Obx(
                    () => _permissionCard(
                      context: context,
                      icon: '▣',
                      title: 'Local session storage',
                      subtitle:
                          'Saves prompts, punches, timestamps on device storage.',
                      isGranted: controller.storageGranted.value,
                      onTap: () {},
                    ),
                  ),

                  const Spacer(),
                  16.height,
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: Size(double.infinity, 54.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    onPressed: controller.nextStep,
                    child: Text(
                      'Continue',
                      style: AppTextStyles.buttonLabel(context).copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  16.height,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // STEP 3: MOUNT GUIDE
  Widget _buildStep3MountGuide(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mount the phone',
                    style: AppTextStyles.heading2(context),
                  ),
                  8.height,
                  Text(
                    'Secure your phone on the Hyper Hitter bracket. Keep the microphone facing the bag and the camera view clear.',
                    style: AppTextStyles.bodyMedium(context),
                  ),
                  16.height,

                  Container(
                    height: CommonFunction.checkOrientationLandscape(context)
                        ? 0.4.sh
                        : 180.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E141B),
                      borderRadius: BorderRadius.circular(23.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 68.w,
                          height: 120.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13.r),
                            border: Border.all(color: AppColors.primary, width: 3),
                          ),
                        ),
                        Positioned(
                          left: 14.w,
                          bottom: 12.h,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 11.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D2838),
                              borderRadius: BorderRadius.circular(999.r),
                              border: Border.all(
                                color: const Color(0xFF1C5364),
                              ),
                            ),
                            child: Text(
                              'Fixed phone-to-bag distance',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11.ts(context),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  16.height,
                  _guideRow(
                    context,
                    '1',
                    'Use the Hyper Hitter bracket',
                    'Supports wall, rack and post installations.',
                  ),
                  10.height,
                  _guideRow(
                    context,
                    '2',
                    'Keep the mount stable',
                    'A stable position improves audio and vision consistency.',
                  ),

                  const Spacer(),
                  16.height,
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: Size(double.infinity, 54.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    onPressed: controller.nextStep,
                    child: Text(
                      'Complete setup & Go to Home',
                      style: AppTextStyles.buttonLabel(context).copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  16.height,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helpers
  Widget _permissionCard({
    required BuildContext context,
    required String icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isGranted
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                color: AppColors.panel2,
                borderRadius: BorderRadius.circular(13.r),
              ),
              child: Center(
                child: Text(icon, style: TextStyle(fontSize: 18.ts(context))),
              ),
            ),
            12.width,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.heading3(
                      context,
                    ).copyWith(fontSize: 14.ts(context)),
                  ),
                  2.height,
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium(
                      context,
                    ).copyWith(fontSize: 12.ts(context)),
                  ),
                ],
              ),
            ),
            8.width,
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46.w,
              height: 26.h,
              padding: EdgeInsets.all(3.r),
              decoration: BoxDecoration(
                color: isGranted ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(999.r),
              ),
              child: Align(
                alignment: isGranted
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 20.r,
                  height: 20.r,
                  decoration: BoxDecoration(
                    color: isGranted ? AppColors.ink : Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _guideRow(
    BuildContext context,
    String num,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        Container(
          width: 36.r,
          height: 36.r,
          decoration: BoxDecoration(
            color: AppColors.panel2,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Center(
            child: Text(
              num,
              style: AppTextStyles.heading3(
                context,
              ).copyWith(fontSize: 15.ts(context)),
            ),
          ),
        ),
        12.width,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.heading3(
                  context,
                ).copyWith(fontSize: 14.ts(context)),
              ),
              2.height,
              Text(
                subtitle,
                style: AppTextStyles.bodyMedium(
                  context,
                ).copyWith(fontSize: 12.ts(context)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.ts(context),
          color: const Color(0xFFD5DAE2),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
