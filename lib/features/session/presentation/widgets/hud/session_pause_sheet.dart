import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/size_box.dart';
import '../../../../../core/widgets/ui/app_buttons.dart';
import '../../../../../core/widgets/ui/stat_tile.dart';
import '../../controllers/free_session_controller.dart';

enum _PauseAction { resume, reset, end }

/// Pause menu: resume, reset the count or end the session. Punches are not
/// counted while it is open (the same gate the detection settings sheet uses).
Future<void> showSessionPauseSheet(
  BuildContext context,
  FreeSessionController controller,
) async {
  controller.notifySettingsViewOpened();
  controller.onSessionPaused();
  final _PauseAction? action = await showModalBottomSheet<_PauseAction>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PauseSheet(controller: controller),
  );
  // Close the gate before acting, so finishSession() never runs with it open.
  controller.notifySettingsViewClosed();
  switch (action) {
    case _PauseAction.reset:
      controller.resetPunchCount();
      controller.onSessionResumed();
    case _PauseAction.end:
      controller.finishSession();
    case _PauseAction.resume:
    case null:
      controller.onSessionResumed();
  }
}

class _PauseSheet extends StatelessWidget {
  final FreeSessionController controller;

  const _PauseSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Paused', style: AppTextStyles.heading2()),
              4.height,
              Text(
                'Punches aren\'t counted while this menu is open.',
                style: AppTextStyles.bodyMedium(),
              ),
              16.height,
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Punches',
                      value: '${controller.punchCount.value}',
                      icon: Icons.sports_mma_rounded,
                    ),
                  ),
                  12.width,
                  Expanded(
                    child: StatTile(
                      label: 'Time',
                      value: controller.formattedElapsedTime,
                      icon: Icons.timer_outlined,
                      accent: AppColors.gold,
                    ),
                  ),
                ],
              ),
              20.height,
              PrimaryButton(
                label: 'Resume',
                icon: Icons.play_arrow_rounded,
                onPressed: () => Navigator.pop(context, _PauseAction.resume),
              ),
              10.height,
              Row(
                children: [
                  Expanded(
                    child: GhostButton(
                      label: 'Reset count',
                      icon: Icons.refresh_rounded,
                      onPressed: () =>
                          Navigator.pop(context, _PauseAction.reset),
                    ),
                  ),
                  10.width,
                  Expanded(
                    child: GhostButton(
                      label: 'End session',
                      icon: Icons.flag_rounded,
                      color: AppColors.danger,
                      onPressed: () => Navigator.pop(context, _PauseAction.end),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
