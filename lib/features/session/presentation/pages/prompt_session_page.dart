import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/widgets/ui/app_buttons.dart';
import '../controllers/prompt_session_controller.dart';
import '../widgets/hud/prompt_call_display.dart';
import '../widgets/hud/session_hud.dart';
import '../widgets/hud/session_shell.dart';

/// Reaction Drill: a combo number is called, the user throws it. Call ring,
/// streak and punch counter.
class PromptSessionPage extends GetView<PromptSessionController> {
  const PromptSessionPage({super.key});

  String get _title {
    final d = controller.difficulty.value;
    if (d.isEmpty) return 'Reaction Drill';
    return 'Reaction Drill · ${d[0].toUpperCase()}${d.substring(1)}';
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
      hud: (context, isLandscape) => isLandscape
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PromptCallDisplay(controller: controller, size: 104),
                const SizedBox(height: 10),
                PunchCounter(
                  punchCount: controller.punchCount,
                  size: 30,
                  alignment: CrossAxisAlignment.center,
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: PunchCounter(
                    punchCount: controller.punchCount,
                    size: 56,
                  ),
                ),
                PromptCallDisplay(controller: controller, size: 132.r),
              ],
            ),
    );
  }
}
