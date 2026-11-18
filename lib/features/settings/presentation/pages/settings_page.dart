import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/enums/sensitivity_level.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../../../../core/widgets/ui/app_buttons.dart';
import '../../../../core/widgets/ui/glass_card.dart';
import '../../../../core/widgets/ui/press_scale.dart';
import '../controllers/settings_controller.dart';

class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                children:
                    [
                          Row(
                            children: [
                              GlassIconButton(
                                icon: Icons.arrow_back_rounded,
                                onPressed: Get.back,
                              ),
                              14.width,
                              Text(
                                'Settings',
                                style: AppTextStyles.heading2(context),
                              ),
                            ],
                          ),
                          24.height,
                          GlassCard(
                            padding: EdgeInsets.zero,
                            borderColor: AppColors.gold.withValues(alpha: 0.5),
                            child: _row(
                              context,
                              icon: Icons.workspace_premium_rounded,
                              title: 'KnockUp Pro',
                              subtitle:
                                  'Unlimited punches, plans and restore purchases',
                              onTap: controller.openPaywall,
                            ),
                          ),
                          24.height,
                          _sectionLabel(context, 'Punch sensitivity'),
                          _sensitivity(context),
                          24.height,
                          _sectionLabel(context, 'Stance'),
                          Obx(
                            () => GlassCard(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 6.h,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.swap_horiz_rounded,
                                    color: AppColors.primary,
                                    size: 20.r,
                                  ),
                                  14.width,
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Southpaw (left-handed)',
                                          style: AppTextStyles.bodyLarge(
                                            context,
                                          ),
                                        ),
                                        2.height,
                                        Text(
                                          'Mirrors the bag targets for drills',
                                          style: AppTextStyles.bodyMedium(
                                            context,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: StorageService.to.southpaw.value,
                                    onChanged: StorageService.to.setSouthpaw,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          24.height,
                          _sectionLabel(context, 'Setup'),
                          GlassCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                _row(
                                  context,
                                  icon: Icons.replay_rounded,
                                  title: 'Replay intro',
                                  subtitle:
                                      'See the welcome and phone setup tips',
                                  onTap: controller.replayIntro,
                                ),
                              ],
                            ),
                          ),
                          Obx(
                            () => controller.developerMode.value
                                ? _developer(context)
                                : const SizedBox.shrink(),
                          ),
                          32.height,
                          Center(
                            child: PressScale(
                              haptic: false,
                              onTap: controller.onVersionTap,
                              child: Padding(
                                padding: EdgeInsets.all(8.r),
                                child: Text(
                                  'KnockUp ${controller.versionLabel}',
                                  style: AppTextStyles.bodyMedium(context),
                                ),
                              ),
                            ),
                          ),
                        ]
                        .animate(interval: 40.ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.08),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 10.h),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.tag(
          context,
        ).copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _sensitivity(BuildContext context) {
    return Obx(() {
      final current = controller.sensitivity.value;
      return Column(
        children: [
          Container(
            padding: EdgeInsets.all(4.r),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: AppColors.glassStroke),
            ),
            child: Row(
              children: [
                for (final level in SensitivityLevel.values)
                  Expanded(
                    child: PressScale(
                      onTap: () => controller.setSensitivity(level),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        decoration: BoxDecoration(
                          gradient: level == current
                              ? AppColors.primaryGradient
                              : null,
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          level.label,
                          style: AppTextStyles.buttonLabel(context).copyWith(
                            color: level == current
                                ? AppColors.onPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          10.height,
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              current.description,
              key: ValueKey(current),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium(context),
            ),
          ),
        ],
      );
    });
  }

  Widget _developer(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        24.height,
        _sectionLabel(context, 'Developer'),
        GlassCard(
          padding: EdgeInsets.zero,
          borderColor: AppColors.warning.withValues(alpha: 0.4),
          child: Column(
            children: [
              _row(
                context,
                icon: Icons.tune_rounded,
                title: 'Advanced setup',
                subtitle: 'Step-by-step pre-check with every detection mode',
                onTap: controller.openAdvancedSetup,
              ),
              _divider(),
              _row(
                context,
                icon: Icons.monitor_heart_rounded,
                title: 'Diagnostics',
                subtitle: 'Live sensor telemetry',
                onTap: controller.openDiagnostics,
              ),
              _divider(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                child: Row(
                  children: [
                    Icon(
                      Icons.developer_mode_rounded,
                      color: AppColors.warning,
                      size: 20.r,
                    ),
                    14.width,
                    Expanded(
                      child: Text(
                        'Developer mode',
                        style: AppTextStyles.bodyLarge(context),
                      ),
                    ),
                    Switch(value: true, onChanged: controller.setDeveloperMode),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider() =>
      Divider(height: 1, thickness: 1, color: AppColors.stroke, indent: 50.w);

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return PressScale(
      onTap: onTap,
      pressedScale: 0.98,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20.r),
            14.width,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyLarge(context)),
                  2.height,
                  Text(subtitle, style: AppTextStyles.bodyMedium(context)),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20.r,
            ),
          ],
        ),
      ),
    );
  }
}
