import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../controllers/free_session_controller.dart';
import '../widgets/hud/session_hud.dart';
import '../widgets/hud/session_shell.dart';

/// Free Fight: count every punch. Big counter + punches-per-minute.
class FreeSessionPage extends GetView<FreeSessionController> {
  const FreeSessionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SessionShell(
      controller: controller,
      title: 'Free Fight',
      hud: (context, isLandscape) => isLandscape
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PunchCounter(
                  punchCount: controller.punchCount,
                  size: 56,
                  alignment: CrossAxisAlignment.center,
                ),
                const SizedBox(height: 10),
                PaceChip(controller: controller),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: PunchCounter(
                    punchCount: controller.punchCount,
                    size: 88,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: PaceChip(controller: controller),
                ),
              ],
            ),
    );
  }
}
