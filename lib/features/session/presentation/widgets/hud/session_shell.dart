import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../../core/services/storage_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/common_function.dart';
import '../../../../../core/widgets/ui/app_buttons.dart';
import '../../../../../core/widgets/ui/glass_card.dart';
import '../../../../../core/widgets/ui/hold_to_confirm_button.dart';
import '../../controllers/free_session_controller.dart';
import '../session_camera_panel.dart';
import '../session_sensor_stats_panel.dart';
import 'daily_limit_guard.dart';
import 'punch_ripple.dart';
import 'session_hud.dart';
import 'session_pause_sheet.dart';

/// Frame shared by the Free and Prompt sessions: camera with the punch
/// ripple, a top bar (pause, title, timer), the mode's own HUD and a
/// hold-to-finish button.
///
/// Portrait lays the HUD over the bottom of the camera; landscape puts it in a
/// glass side panel next to the camera. Back opens the pause menu.
class SessionShell extends StatelessWidget {
  final FreeSessionController controller;
  final String title;

  /// Extra round buttons in the top bar (e.g. the drill's sound toggle).
  final List<Widget> actions;

  /// The mode's HUD: counter, pace, prompt ring…
  final Widget Function(BuildContext context, bool isLandscape) hud;

  const SessionShell({
    super.key,
    required this.controller,
    required this.title,
    required this.hud,
    this.actions = const [],
  });

  void _pause(BuildContext context) =>
      showSessionPauseSheet(context, controller);

  @override
  Widget build(BuildContext context) {
    final isLandscape = CommonFunction.checkOrientationLandscape(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pause(context);
      },
      // Today's free punches: counted live; at the limit counting stops
      // through the same gate the pause menu uses.
      child: DailyLimitGuard(
        punchCount: controller.punchCount,
        onStopCounting: controller.notifySettingsViewOpened,
        onResumeCounting: controller.notifySettingsViewClosed,
        onEndSession: controller.finishSession,
        child: Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: isLandscape ? _landscape(context) : _portrait(context),
          ),
        ),
      ),
    );
  }

  Widget _portrait(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _topBar(context),
          SizedBox(height: 10.h),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: SessionCameraPanel(
                    controller: controller,
                    isLandscape: false,
                  ),
                ),
                Positioned.fill(child: _bottomShade()),
                Positioned.fill(
                  child: PunchRipple(punchCount: controller.punchCount),
                ),
                Positioned(
                  left: 16.w,
                  right: 16.w,
                  bottom: 16.h,
                  child: hud(context, false),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          HoldToConfirmButton(
            label: 'Hold to finish',
            icon: Icons.flag_rounded,
            onConfirmed: controller.finishSession,
          ),
        ],
      ),
    );
  }

  Widget _landscape(BuildContext context) {
    final panelWidth = (MediaQuery.sizeOf(context).width * 0.3).clamp(
      220.0,
      320.0,
    );
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: SessionCameraPanel(
                    controller: controller,
                    isLandscape: true,
                  ),
                ),
                Positioned.fill(
                  child: PunchRipple(punchCount: controller.punchCount),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: panelWidth,
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _topBar(context, compact: true),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Obx(
                      () => StorageService.to.developerMode.value
                          ? Column(
                              children: [
                                hud(context, true),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: SessionSensorStatsPanel(
                                    controller: controller,
                                  ),
                                ),
                              ],
                            )
                          : Center(
                              child: SingleChildScrollView(
                                child: hud(context, true),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  HoldToConfirmButton(
                    label: 'Hold to finish',
                    icon: Icons.flag_rounded,
                    height: 44,
                    onConfirmed: controller.finishSession,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context, {bool compact = false}) {
    final buttonSize = compact ? 38.0 : 44.r;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GlassIconButton(
              icon: Icons.pause_rounded,
              size: buttonSize,
              onPressed: () => _pause(context),
            ),
            if (!compact) ...[
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.heading3(),
                ),
              ),
            ] else
              const Spacer(),
            for (final action in actions) ...[action, SizedBox(width: 8.r)],
            SessionTimerPill(controller: controller),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: SessionDevTools(controller: controller),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2);
  }

  /// Dark fade at the bottom of the camera so the HUD reads over any scene.
  Widget _bottomShade() {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.r),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.45, 1],
              colors: [
                AppColors.bg.withValues(alpha: 0),
                AppColors.bg.withValues(alpha: 0.85),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
