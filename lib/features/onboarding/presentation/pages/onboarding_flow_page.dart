import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/common_function.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/utils/size_box.dart';
import '../../../../core/widgets/knockup_logo.dart';
import '../../../../core/widgets/ui/app_buttons.dart';
import '../../../../core/widgets/ui/glass_card.dart';
import '../../../../core/widgets/ui/press_scale.dart';
import '../controllers/onboarding_controller.dart';

/// First-launch intro: welcome → phone setup → camera & mic access.
class OnboardingFlowPage extends GetView<OnboardingController> {
  const OnboardingFlowPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isLandscape = CommonFunction.checkOrientationLandscape(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && controller.currentStep.value > 0) {
          controller.previousStep();
        }
      },
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: isLandscape ? 8.h : 16.h,
                  ),
                  child: Column(
                    children: [
                      _topRow(context),
                      Expanded(
                        child: PageView(
                          controller: controller.pageController,
                          onPageChanged: controller.onPageChanged,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _welcome(context),
                            _phoneSetup(context),
                            _permissions(context),
                          ],
                        ),
                      ),
                      _bottomBar(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topRow(BuildContext context) {
    return SizedBox(
      height: 44.h,
      child: Row(
        children: [
          const KnockUpLogo(scale: 0.8),
          const Spacer(),
          Obx(
            () => AnimatedOpacity(
              opacity:
                  controller.currentStep.value <
                      OnboardingController.permissionsPage
                  ? 1
                  : 0,
              duration: const Duration(milliseconds: 200),
              child: TextButton(
                onPressed: () => controller.pageController.animateToPage(
                  OnboardingController.permissionsPage,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                ),
                child: Text('Skip', style: AppTextStyles.bodyMedium(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Slides ────────────────────────────────────────────────────────────────

  Widget _slide(
    BuildContext context, {
    required Widget hero,
    required String title,
    required String body,
    List<Widget> extra = const [],
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            [
                  Center(child: hero),
                  28.height,
                  Text(title, style: AppTextStyles.display(context)),
                  10.height,
                  Text(
                    body,
                    style: AppTextStyles.bodyLarge(
                      context,
                    ).copyWith(color: AppColors.textSecondary, height: 1.5),
                  ),
                  ...extra,
                ]
                .animate(interval: 70.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.15, curve: Curves.easeOutCubic),
      ),
    );
  }

  Widget _welcome(BuildContext context) {
    return _slide(
      context,
      hero: KnockUpMark(size: 120.r)
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: -4, end: 4, duration: 1600.ms, curve: Curves.easeInOut),
      title: AppConstants.tagline,
      body:
          'KnockUp turns your phone into a boxing partner. It watches and '
          'listens, counts every punch you throw, and calls combos to train '
          'your reactions.',
      extra: [
        20.height,
        _feature(context, Icons.sports_mma_rounded, 'Counts every punch'),
        _feature(
          context,
          Icons.bolt_rounded,
          'Reaction drills with combo calls',
        ),
        _feature(context, Icons.insights_rounded, 'Track your progress'),
      ],
    );
  }

  Widget _phoneSetup(BuildContext context) {
    return _slide(
      context,
      hero: _heroIcon(Icons.smartphone_rounded),
      title: 'Set up your phone',
      body: 'Do this once before you train. It takes ten seconds.',
      extra: [
        20.height,
        _tip(
          context,
          '1',
          'Stand it up',
          'On a shelf, stand or wall, at chest height.',
        ),
        _tip(
          context,
          '2',
          'Step back',
          'About 1–2 metres away, facing the front camera.',
        ),
        _tip(
          context,
          '3',
          'Stay in view',
          'Face and shoulders visible, in a well-lit space.',
        ),
      ],
    );
  }

  Widget _permissions(BuildContext context) {
    return _slide(
      context,
      hero: _heroIcon(Icons.shield_rounded),
      title: 'Camera and microphone',
      body:
          'KnockUp sees your movement and hears each impact to count punches. '
          'Everything runs on your phone. No video or audio leaves it.',
      extra: [
        20.height,
        Obx(
          () => _permissionRow(
            context,
            icon: Icons.videocam_rounded,
            title: 'Camera',
            subtitle: 'Sees your punches',
            granted: controller.cameraGranted.value,
            onTap: controller.requestCamera,
          ),
        ),
        10.height,
        Obx(
          () => _permissionRow(
            context,
            icon: Icons.mic_rounded,
            title: 'Microphone',
            subtitle: 'Hears each hit',
            granted: controller.micGranted.value,
            onTap: controller.requestMicrophone,
          ),
        ),
      ],
    );
  }

  // ─── Pieces ────────────────────────────────────────────────────────────────

  Widget _heroIcon(IconData icon) {
    return Container(
          width: 120.r,
          height: 120.r,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accentBg,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 40,
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.primary, size: 54.r),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(end: 1.05, duration: 1400.ms, curve: Curves.easeInOut);
  }

  Widget _feature(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20.r),
          12.width,
          Text(text, style: AppTextStyles.bodyLarge(context)),
        ],
      ),
    );
  }

  Widget _tip(BuildContext context, String n, String title, String body) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: GlassCard(
        padding: EdgeInsets.all(14.r),
        child: Row(
          children: [
            Container(
              width: 32.r,
              height: 32.r,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: Text(
                n,
                style: AppTextStyles.buttonLabel(
                  context,
                ).copyWith(fontSize: 14.ts(context)),
              ),
            ),
            12.width,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.heading3(context)),
                  2.height,
                  Text(body, style: AppTextStyles.bodyMedium(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissionRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool granted,
    required VoidCallback onTap,
  }) {
    return PressScale(
      onTap: granted ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: granted
              ? AppColors.success.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: granted ? AppColors.success : AppColors.glassStroke,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: granted ? AppColors.success : AppColors.textPrimary,
              size: 22.r,
            ),
            12.width,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.heading3(context)),
                  Text(subtitle, style: AppTextStyles.bodyMedium(context)),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: granted
                  ? Icon(
                      Icons.check_circle_rounded,
                      key: const ValueKey('ok'),
                      color: AppColors.success,
                      size: 24.r,
                    )
                  : Text(
                      'Allow',
                      key: const ValueKey('allow'),
                      style: AppTextStyles.tag(context),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    return Obx(() {
      final step = controller.currentStep.value;
      final isLast = step == OnboardingController.pageCount - 1;
      final allGranted =
          controller.micGranted.value && controller.cameraGranted.value;
      final label = !isLast
          ? 'Continue'
          : allGranted
          ? 'Start training'
          : 'Allow access';
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < OnboardingController.pageCount; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: EdgeInsets.symmetric(horizontal: 3.w),
                  width: i == step ? 22.w : 7.w,
                  height: 7.w,
                  decoration: BoxDecoration(
                    color: i == step ? AppColors.primary : AppColors.stroke,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
          16.height,
          PrimaryButton(
            label: label,
            icon: isLast && allGranted ? Icons.sports_mma_rounded : null,
            onPressed: controller.nextStep,
          ),
        ],
      );
    });
  }
}
