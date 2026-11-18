import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/size_box.dart';
import '../../../../drills/domain/round_clock.dart';
import '../../../../drills/presentation/widgets/punch_bag_view.dart';
import '../../controllers/prompt_session_controller.dart';
import 'session_hud.dart';

String _clock(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

/// The bag during a drill: the called target lights up (green once a punch
/// is counted), the next call shows as a gold ring, dimmed during rest.
class DrillBag extends StatelessWidget {
  final PromptSessionController controller;

  const DrillBag({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final working = controller.roundPhase.value == RoundPhase.work;
      final started = controller.promptTick.value > 0;
      return PunchBagView(
        highlight: working && started ? controller.promptNumber.value : null,
        next: working ? controller.nextNumber.value : null,
        hitFlash: controller.currentCallHit.value,
        dimmed: !working,
      );
    });
  }
}

/// "Round 2 / 3 · 1:24" while working; a larger gold "Rest" banner during
/// rest. Hidden for open-ended drills.
class RoundBanner extends StatelessWidget {
  final PromptSessionController controller;
  final bool large;

  const RoundBanner({super.key, required this.controller, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.hasRounds) return const SizedBox.shrink();
      final phase = controller.roundPhase.value;
      final left = controller.roundSecondsLeft.value;
      final round = controller.round.value;
      final total = controller.totalRounds;
      if (phase == RoundPhase.rest) {
        return HudPill(
              borderColor: AppColors.gold.withValues(alpha: 0.7),
              padding: EdgeInsets.symmetric(horizontal: 14.r, vertical: 8.r),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.self_improvement_rounded,
                    color: AppColors.gold,
                    size: 18.r,
                  ),
                  8.width,
                  Text(
                    'REST ${_clock(left)}',
                    style: AppTextStyles.number(
                      null,
                      large ? 22 : 17,
                    ).copyWith(color: AppColors.gold, letterSpacing: 0.5),
                  ),
                  8.width,
                  Text(
                    'Round ${round + 1} next',
                    style: AppTextStyles.bodyMedium().copyWith(fontSize: 12.fs),
                  ),
                ],
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fade(begin: 0.75, end: 1, duration: 900.ms);
      }
      return HudPill(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ROUND $round / $total',
              style: AppTextStyles.tag().copyWith(
                color: AppColors.textPrimary,
                fontSize: 11.fs,
              ),
            ),
            8.width,
            Text(
              _clock(left),
              style: AppTextStyles.number(null, 15).copyWith(
                color: left <= 10 ? AppColors.primaryLight : null,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Big rest countdown over the dimmed bag (landscape stage).
class RestOverlay extends StatelessWidget {
  final PromptSessionController controller;

  const RestOverlay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Obx(() {
        if (controller.roundPhase.value != RoundPhase.rest) {
          return const SizedBox.shrink();
        }
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.bg.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'REST',
                  style: AppTextStyles.tag().copyWith(
                    color: AppColors.gold,
                    fontSize: 14.fs,
                    letterSpacing: 4,
                  ),
                ),
                Text(
                  _clock(controller.roundSecondsLeft.value),
                  style: AppTextStyles.number(null, 72),
                ),
                Text(
                  'Breathe. Round ${controller.round.value + 1} of '
                  '${controller.totalRounds} is next.',
                  style: AppTextStyles.bodyMedium(),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
