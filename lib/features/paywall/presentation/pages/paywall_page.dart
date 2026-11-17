import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../../../../core/utils/common_function.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/widgets/knockup_logo.dart';
import '../../../../core/widgets/ui/app_buttons.dart';
import '../../../../core/widgets/ui/glass_card.dart';
import '../../../../core/widgets/ui/press_scale.dart';
import '../controllers/paywall_controller.dart';

/// KnockUp Pro. Built so the three plans are on screen without scrolling:
/// a compact header, one-line benefits, the plans side by side (Yearly in the
/// middle, preselected), a line saying exactly what the selected plan costs,
/// and a slim pinned buy button. The store's renewal terms follow below.
///
/// Sizes use `.sp` / `.r` without context so landscape doesn't shrink them.
class PaywallPage extends GetView<PaywallController> {
  const PaywallPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isLandscape = CommonFunction.checkOrientationLandscape(context);
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isLandscape ? 900 : 520),
              child: isLandscape ? _landscape() : _portrait(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _portrait() {
    return Column(
      children: [
        _topBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.r, 0, 20.r, 16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children:
                  [
                        _header(),
                        SizedBox(height: 18.r),
                        _benefits(),
                        SizedBox(height: 22.r),
                        _planRow(),
                        SizedBox(height: 14.r),
                        _summary(),
                        SizedBox(height: 18.r),
                        _terms(),
                      ]
                      .animate(interval: 50.ms)
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.06, curve: Curves.easeOutCubic),
            ),
          ),
        ),
        _buyBar(),
      ],
    );
  }

  Widget _landscape() {
    return Column(
      children: [
        _topBar(),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.r, 0, 20.r, 8.r),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(),
                        SizedBox(height: 16.r),
                        _benefits(),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 20.r),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _planRow(),
                        SizedBox(height: 12.r),
                        _summary(),
                        SizedBox(height: 12.r),
                        _buyButton(),
                        _links(),
                        _terms(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Top ─────────────────────────────────────────────────────────────────

  Widget _topBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.r, 8.r, 16.r, 8.r),
      child: Row(
        children: [
          if (!AppConstants.purchasesConnected)
            Flexible(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 5.r),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'PREVIEW MODE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.tag().copyWith(
                    color: AppColors.warning,
                    fontSize: 9.fs,
                  ),
                ),
              ),
            ),
          const Spacer(),
          GlassIconButton(
            icon: Icons.close_rounded,
            size: 40.r,
            onPressed: Get.back,
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        KnockUpMark(size: 56.r)
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(end: 1.06, duration: 1400.ms, curve: Curves.easeInOut),
        SizedBox(height: 12.r),
        Text.rich(
          TextSpan(
            style: AppTextStyles.heading1().copyWith(fontSize: 30.fs),
            children: const [
              TextSpan(text: 'KnockUp '),
              TextSpan(
                text: 'Pro',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
        SizedBox(height: 4.r),
        Text(
          controller.fromLimit
              ? 'You\'ve used today\'s ${AppConstants.freeDailyPunchLimit} '
                    'free punches. Go unlimited, or come back tomorrow.'
              : 'Train without limits.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLarge().copyWith(
            fontSize: 14.fs,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _benefits() {
    const benefits = [
      (Icons.all_inclusive_rounded, 'Unlimited punches, every day'),
      (Icons.timer_outlined, 'Never stopped mid-session'),
      (Icons.auto_awesome_rounded, 'New lessons and drills as they launch'),
    ];
    return GlassCard(
      padding: EdgeInsets.symmetric(horizontal: 16.r, vertical: 12.r),
      child: Column(
        children: [
          for (final (icon, text) in benefits)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 5.r),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.primary, size: 18.r),
                  SizedBox(width: 12.r),
                  Expanded(
                    child: Text(
                      text,
                      style: AppTextStyles.bodyLarge().copyWith(
                        fontSize: 14.fs,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.check_rounded,
                    color: AppColors.success,
                    size: 18.r,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Plans ───────────────────────────────────────────────────────────────

  Widget _planRow() {
    return Padding(
      // Room for the badge that sits on the Yearly tile's top edge.
      padding: EdgeInsets.only(top: 10.r),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < controller.plans.length; i++) ...[
              if (i > 0) SizedBox(width: 10.r),
              Expanded(
                child: _PlanTile(
                  plan: controller.plans[i],
                  controller: controller,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Exactly what the selected plan costs, in one line.
  Widget _summary() {
    return Obx(
      () => AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(
          controller.selectedPlan.summary,
          key: ValueKey(controller.selected.value),
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLarge().copyWith(
            fontSize: 14.fs,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ─── Buy ─────────────────────────────────────────────────────────────────

  Widget _buyBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20.r, 12.r, 20.r, 4.r),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.92),
        border: const Border(top: BorderSide(color: AppColors.stroke)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_buyButton(), _links()],
      ),
    );
  }

  Widget _buyButton() {
    return Obx(
      () => PrimaryButton(
        label: controller.selectedPlan.cta,
        icon: Icons.workspace_premium_rounded,
        loading: controller.busy.value,
        onPressed: controller.purchase,
      ),
    );
  }

  Widget _links() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _link('Restore purchases', controller.restore),
        _dot(),
        _link(
          'Terms',
          () => controller.openLegal('Terms', AppConstants.termsUrl),
        ),
        _dot(),
        _link(
          'Privacy',
          () => controller.openLegal('Privacy', AppConstants.privacyUrl),
        ),
      ],
    );
  }

  Widget _link(String label, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 6.r),
        minimumSize: Size(0, 36.r),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyMedium().copyWith(fontSize: 12.fs),
      ),
    );
  }

  Widget _dot() =>
      Text('·', style: AppTextStyles.bodyMedium().copyWith(fontSize: 12.fs));

  /// Store renewal terms for the selected plan (required for subscriptions).
  Widget _terms() {
    return Obx(
      () => Text(
        controller.finePrint,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium().copyWith(fontSize: 11.fs),
      ),
    );
  }
}

/// One plan, side by side with the others: title, price, period and a short
/// note. Selected = ember border and tint; Yearly carries a badge.
class _PlanTile extends StatelessWidget {
  final PaywallPlan plan;
  final PaywallController controller;

  const _PlanTile({required this.plan, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = controller.selected.value == plan.id;
      return PressScale(
        onTap: () => controller.select(plan.id),
        pressedScale: 0.97,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(8.r, 20.r, 8.r, 14.r),
              decoration: BoxDecoration(
                color: selected ? AppColors.accentBg : AppColors.surface,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.glassStroke,
                  width: selected ? 2 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 18,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    plan.title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.tag().copyWith(
                      fontSize: 10.fs,
                      color: selected
                          ? AppColors.primaryLight
                          : AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8.r),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      plan.price,
                      style: AppTextStyles.number(null, 22),
                    ),
                  ),
                  SizedBox(height: 2.r),
                  Text(
                    plan.period,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium().copyWith(fontSize: 11.fs),
                  ),
                  if (plan.equivalent != null) ...[
                    SizedBox(height: 2.r),
                    Text(
                      plan.equivalent!,
                      maxLines: 1,
                      style: AppTextStyles.bodyMedium().copyWith(
                        fontSize: 11.fs,
                        color: AppColors.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  SizedBox(height: 10.r),
                  Text(
                    plan.tileNote,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium().copyWith(
                      fontSize: 11.fs,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (plan.badge != null)
              Positioned(
                top: -10.r,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 3.r),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    plan.badge!,
                    style: AppTextStyles.tag().copyWith(
                      color: AppColors.ink,
                      fontSize: 9.fs,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 8.r,
              right: 8.r,
              child: AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 16.r,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
