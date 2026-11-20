import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/common_function.dart';
import '../../../../core/utils/size_box.dart';
import '../../../../core/widgets/knockup_logo.dart';
import '../../../../core/widgets/ui/app_buttons.dart';
import '../../../../core/widgets/ui/glass_card.dart';
import '../../../../core/widgets/ui/meter_bar.dart';
import '../../../../core/widgets/ui/press_scale.dart';
import '../../../history/presentation/widgets/session_tile.dart';
import '../controllers/home_controller.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isLandscape = CommonFunction.checkOrientationLandscape(context);
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: isLandscape ? _landscape(context) : _portrait(context),
        ),
      ),
    );
  }

  List<Widget> _modes(BuildContext context) => [
    _ModeCard(
      title: 'Free Fight',
      subtitle: 'Punch at your own pace. Every hit is counted.',
      icon: Icons.sports_mma_rounded,
      highlighted: true,
      onTap: controller.startFreeMode,
    ),
    12.height,
    _ModeCard(
      title: 'Reaction Drill',
      subtitle:
          'Hit the spot on the bag when it\'s called. Fight-style drills or '
          'build your own.',
      icon: Icons.bolt_rounded,
      onTap: controller.openDrills,
    ),
    12.height,
    _learnTeaser(context),
  ];

  Widget _animatedColumn(List<Widget> children, {EdgeInsets? padding}) {
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children
            .animate(interval: 60.ms)
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.12, curve: Curves.easeOutCubic),
      ),
    );
  }

  Widget _portrait(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: _animatedColumn([
          _header(context),
          22.height,
          _greeting(context),
          20.height,
          _todayCard(context),
          16.height,
          ..._modes(context),
          _recent(context),
          24.height,
        ], padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h)),
      ),
    );
  }

  /// Left: who you are today (greeting, today's punches, recent sessions).
  /// Right: what to do next (the training modes). Each side scrolls alone.
  Widget _landscape(BuildContext context) {
    const gap = 20.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(gap, 8, gap, 0),
          child: Column(
            children: [
              _header(context),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _animatedColumn([
                        _greeting(context),
                        16.height,
                        _todayCard(context),
                        _recent(context),
                        16.height,
                      ]),
                    ),
                    const SizedBox(width: gap),
                    Expanded(
                      child: _animatedColumn([..._modes(context), 16.height]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        // The logo gives way first when the top bar is tight (small phones,
        // large system text, the PRO button showing).
        const Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: KnockUpLogo(scale: 0.9),
            ),
          ),
        ),
        Obx(
          () => controller.showProButton
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ProButton(onTap: controller.openPaywall),
                    10.width,
                  ],
                )
              : const SizedBox.shrink(),
        ),
        GlassIconButton(
          icon: Icons.history_rounded,
          onPressed: controller.openHistory,
        ),
        10.width,
        GlassIconButton(
          icon: Icons.settings_rounded,
          onPressed: controller.openSettings,
        ),
      ],
    );
  }

  Widget _greeting(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(controller.greeting, style: AppTextStyles.bodyMedium(context)),
        4.height,
        Text('Ready to train?', style: AppTextStyles.display(context)),
      ],
    );
  }

  /// Today's punches. Free users: "210 / 300", a meter and how many are
  /// left (or "Go unlimited" once used up). Pro users: just the count.
  Widget _todayCard(BuildContext context) {
    return GlassCard(
      child: Obx(() {
        final used = controller.todayPunches.value;
        final limit = controller.dailyLimit;
        final unlimited = controller.isUnlimited;
        final reached = controller.limitReached;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    unlimited ? 'TODAY' : 'TODAY\'S FREE PUNCHES',
                    style: AppTextStyles.tag(
                      context,
                    ).copyWith(color: AppColors.textSecondary),
                  ),
                ),
                if (unlimited)
                  _chip(context, 'UNLIMITED', AppColors.gold)
                else
                  Text(
                    'Resets at midnight',
                    style: AppTextStyles.bodyMedium(
                      context,
                    ).copyWith(fontSize: 12.ts(context)),
                  ),
              ],
            ),
            8.height,
            // Scales down for very large totals (Pro users have no limit).
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  TweenAnimationBuilder<int>(
                    tween: IntTween(end: used),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, v, _) =>
                        Text('$v', style: AppTextStyles.number(context, 44)),
                  ),
                  if (!unlimited)
                    Text(
                      ' / $limit',
                      style: AppTextStyles.number(context, 24).copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 0,
                      ),
                    ),
                  8.width,
                  Text('punches', style: AppTextStyles.bodyMedium(context)),
                ],
              ),
            ),
            if (!unlimited) ...[
              12.height,
              MeterBar(
                value: limit == 0 ? 0 : (used / limit).clamp(0.0, 1.0),
                gradient: reached
                    ? AppColors.goldGradient
                    : AppColors.primaryGradient,
              ),
              12.height,
              reached ? _limitReachedRow(context) : _leftRow(context),
            ],
            if (controller.showTestReset) _testResetButton(context),
          ],
        );
      }),
    );
  }

  /// Testing only ([AppConstants.showTestUsageReset]).
  Widget _testResetButton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 10.h),
      child: Align(
        alignment: Alignment.centerRight,
        child: PressScale(
          onTap: controller.resetTodayForTesting,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.restart_alt_rounded,
                  color: AppColors.warning,
                  size: 14.r,
                ),
                4.width,
                Text(
                  'Reset to 0 (test)',
                  style: AppTextStyles.tag(
                    context,
                  ).copyWith(color: AppColors.warning, letterSpacing: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _leftRow(BuildContext context) {
    final left = controller.remaining;
    return Row(
      children: [
        Icon(
          Icons.local_fire_department_rounded,
          color: AppColors.gold,
          size: 16.r,
        ),
        6.width,
        Expanded(
          child: Text(
            '$left ${left == 1 ? 'punch' : 'punches'} left today',
            style: AppTextStyles.bodyMedium(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  /// Used up: say so, and offer Pro right here instead of a separate card.
  Widget _limitReachedRow(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.lock_clock_rounded, color: AppColors.gold, size: 16.r),
        6.width,
        Expanded(
          child: Text(
            'All free punches used',
            style: AppTextStyles.bodyMedium(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
        ),
        PressScale(
          onTap: controller.openPaywall,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Go unlimited',
                  style: AppTextStyles.tag(
                    context,
                  ).copyWith(color: AppColors.gold, letterSpacing: 0.4),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.gold,
                  size: 18.r,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTextStyles.tag(
          context,
        ).copyWith(color: color, fontSize: 9.ts(context)),
      ),
    );
  }

  /// Last sessions + "See all". Hidden until the first session is saved.
  Widget _recent(BuildContext context) {
    return Obx(() {
      if (controller.recent.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(top: 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 4.w),
                  child: Text(
                    'RECENT',
                    style: AppTextStyles.tag(
                      context,
                    ).copyWith(color: AppColors.textSecondary),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: controller.openHistory,
                  child: Text('See all', style: AppTextStyles.tag(context)),
                ),
              ],
            ),
            for (final r in controller.recent)
              Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: SessionTile(
                  record: r,
                  onTap: () => controller.openSession(r),
                ),
              ),
          ],
        ),
      );
    });
  }

  /// Learn Boxing course with progress ("3/10 lessons").
  Widget _learnTeaser(BuildContext context) {
    return PressScale(
      onTap: controller.openLearn,
      child: GlassCard(
        padding: EdgeInsets.all(16.r),
        child: Row(
          children: [
            Container(
              width: 44.r,
              height: 44.r,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(
                Icons.school_rounded,
                color: AppColors.gold,
                size: 22.r,
              ),
            ),
            14.width,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Learn Boxing', style: AppTextStyles.heading3(context)),
                  2.height,
                  Text(
                    'Stance, jab, cross, hook and uppercut lessons.',
                    style: AppTextStyles.bodyMedium(context),
                  ),
                ],
              ),
            ),
            Obx(
              () => Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  controller.learnProgressLabel,
                  style: AppTextStyles.tag(
                    context,
                  ).copyWith(color: AppColors.gold, fontSize: 9.ts(context)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small gold "PRO" button in the top bar (opens the plans). Same height as
/// the round History / Settings buttons next to it.
class _ProButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ProButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final h = 44.r;
    return PressScale(
      onTap: onTap,
      child: Container(
        height: h,
        padding: EdgeInsets.symmetric(horizontal: 12.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(h),
          gradient: LinearGradient(
            colors: [
              AppColors.gold.withValues(alpha: 0.22),
              AppColors.primary.withValues(alpha: 0.14),
            ],
          ),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.gold,
              size: 18.r,
            ),
            SizedBox(width: 5.r),
            Text(
              'PRO',
              style: AppTextStyles.tag(
                context,
              ).copyWith(color: AppColors.gold, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool highlighted;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = highlighted ? AppColors.onPrimary : AppColors.textPrimary;
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(18.r),
        decoration: BoxDecoration(
          gradient: highlighted ? AppColors.primaryGradient : null,
          color: highlighted ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(24.r),
          border: highlighted ? null : Border.all(color: AppColors.glassStroke),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 52.r,
              height: 52.r,
              decoration: BoxDecoration(
                color: highlighted
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.accentBg,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Icon(
                icon,
                color: highlighted ? fg : AppColors.primary,
                size: 28.r,
              ),
            ),
            16.width,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.heading2(
                      context,
                    ).copyWith(color: fg, fontSize: 21.ts(context)),
                  ),
                  4.height,
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: highlighted
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            8.width,
            Icon(Icons.arrow_forward_rounded, color: fg, size: 22.r),
          ],
        ),
      ),
    );
  }
}
