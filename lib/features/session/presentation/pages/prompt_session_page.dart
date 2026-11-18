import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/ui/app_buttons.dart';
import '../controllers/prompt_session_controller.dart';
import '../widgets/hud/drill_hud.dart';
import '../widgets/hud/prompt_call_display.dart';
import '../widgets/hud/session_hud.dart';
import '../widgets/hud/session_shell.dart';

/// Reaction Drill: a combo number is called and lights up on the bag; the
/// user throws it. Landscape: the bag fills the left side and the camera is a
/// small window in its corner. Portrait: the bag sits next to the call ring
/// over the camera.
class PromptSessionPage extends GetView<PromptSessionController> {
  const PromptSessionPage({super.key});

  String get _title {
    final d = controller.difficulty.value;
    if (d.isEmpty) return 'Reaction Drill';
    return '${d[0].toUpperCase()}${d.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    return SessionShell(
      controller: controller,
      title: _title,
      actions: [
        Obx(
          () => GlassIconButton(
            icon: controller.isTtsEnabled.value
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            size: 44.r,
            onPressed: controller.isTtsEnabled.toggle,
          ),
        ),
      ],
      landscapeStage: (context) => Stack(
        children: [
          // Leaves room at the bottom-left for the camera window.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Center(child: DrillBag(controller: controller)),
            ),
          ),
          Positioned.fill(child: RestOverlay(controller: controller)),
          // Drill name + round on the stage (the landscape top bar is
          // compact and has no title).
          Positioned(
            left: 8,
            top: 4,
            right: 8,
            child: Row(
              children: [
                Flexible(
                  child: Obx(
                    () => Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.heading3(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                RoundBanner(controller: controller),
              ],
            ),
          ),
        ],
      ),
      hud: (context, isLandscape) =>
          isLandscape ? _landscapeHud() : _portraitHud(),
    );
  }

  /// Call ring and punch count side by side, round banner on top. The
  /// shell scales this down if the panel is short, so nothing scrolls.
  Widget _landscapeHud() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PromptCallDisplay(controller: controller, size: 110),
            const SizedBox(width: 16),
            PunchCounter(
              punchCount: controller.punchCount,
              size: 40,
              alignment: CrossAxisAlignment.center,
            ),
          ],
        ),
      ],
    );
  }

  Widget _portraitHud() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: RoundBanner(controller: controller),
        ),
        SizedBox(height: 10.r),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: 112.r,
              child: DrillBag(controller: controller),
            ),
            SizedBox(width: 8.r),
            Expanded(
              child: PunchCounter(punchCount: controller.punchCount, size: 48),
            ),
            PromptCallDisplay(controller: controller, size: 112.r),
          ],
        ),
      ],
    );
  }
}
