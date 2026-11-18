import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../../core/enums/detection_enums.dart';
import '../../../../../core/navigation/models/session_arguments.dart';
import '../../../../../core/services/usage_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/size_box.dart';
import '../../../../../core/widgets/animated_punch_count_text.dart';
import '../../../../../core/widgets/dev_only.dart';
import '../../../../fusion/domain/services/impact_gate_evaluator.dart';
import '../../controllers/free_session_controller.dart';

// Shared pieces of the Free / Prompt session HUD. Text sizes use `.sp`
// (no context) so they stay readable in landscape, where `.ts` shrinks text.

/// Translucent rounded pill used for every small HUD readout.
class HudPill extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final EdgeInsetsGeometry? padding;

  const HudPill({
    super.key,
    required this.child,
    this.borderColor = AppColors.glassStroke,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? EdgeInsets.symmetric(horizontal: 12.r, vertical: 7.r),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

/// Elapsed time, e.g. "03:42".
class SessionTimerPill extends StatelessWidget {
  final FreeSessionController controller;

  const SessionTimerPill({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return HudPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, color: AppColors.gold, size: 15.r),
          SizedBox(width: 6.r),
          Obx(
            () => Text(
              controller.formattedElapsedTime,
              style: AppTextStyles.number(
                null,
                14,
              ).copyWith(letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Big punch total that pops on every punch.
class PunchCounter extends StatelessWidget {
  final RxInt punchCount;
  final double size;
  final String label;
  final CrossAxisAlignment alignment;

  const PunchCounter({
    super.key,
    required this.punchCount,
    required this.size,
    this.label = 'PUNCHES',
    this.alignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: AppTextStyles.tag().copyWith(color: AppColors.textSecondary),
        ),
        // Scales down instead of wrapping when a 3–4 digit count is wider
        // than the space next to the drill's call ring.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Obx(
            () => AnimatedPunchCountText(
              count: punchCount.value,
              duration: const Duration(milliseconds: 260),
              style: AppTextStyles.number(null, size).copyWith(
                shadows: [
                  Shadow(
                    color: AppColors.primary.withValues(alpha: 0.55),
                    blurRadius: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Punches per minute over the last 30 seconds.
class PaceChip extends StatefulWidget {
  final FreeSessionController controller;

  const PaceChip({super.key, required this.controller});

  @override
  State<PaceChip> createState() => _PaceChipState();
}

class _PaceChipState extends State<PaceChip> {
  static const int _windowSec = 30;

  final List<int> _hitTimesMs = <int>[];
  late int _lastCount = widget.controller.punchCount.value;
  late final List<Worker> _workers;

  @override
  void initState() {
    super.initState();
    _workers = [
      ever<int>(widget.controller.punchCount, _onCount),
      // The session clock ticks every second: drop punches that left the window.
      ever<int>(widget.controller.elapsedSeconds, (_) => _prune()),
    ];
  }

  void _onCount(int count) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (count < _lastCount) {
      _hitTimesMs.clear(); // Count was reset.
    } else {
      for (var i = _lastCount; i < count; i++) {
        _hitTimesMs.add(now);
      }
    }
    _lastCount = count;
    _prune();
  }

  void _prune() {
    final cutoff = DateTime.now().millisecondsSinceEpoch - _windowSec * 1000;
    _hitTimesMs.removeWhere((t) => t < cutoff);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = widget.controller.elapsedSeconds.value;
    final window = elapsed.clamp(5, _windowSec);
    final ppm = (_hitTimesMs.length * 60 / window).round();
    return HudPill(
      borderColor: ppm > 0
          ? AppColors.primary.withValues(alpha: 0.5)
          : AppColors.glassStroke,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, color: AppColors.primaryLight, size: 16.r),
          SizedBox(width: 4.r),
          Text(
            elapsed < 5 ? '--' : '$ppm',
            style: AppTextStyles.number(null, 15),
          ),
          SizedBox(width: 4.r),
          Text(
            '/ min',
            style: AppTextStyles.bodyMedium().copyWith(fontSize: 12.fs),
          ),
        ],
      ),
    );
  }
}

/// Plain-language hint about the camera ("Step into view", "Move a little
/// closer") or, for the first seconds, a loud room found by the Get Ready
/// room check. Hidden while everything is fine.
class SessionStatusChip extends StatefulWidget {
  final FreeSessionController controller;

  const SessionStatusChip({super.key, required this.controller});

  @override
  State<SessionStatusChip> createState() => _SessionStatusChipState();
}

class _SessionStatusChipState extends State<SessionStatusChip> {
  static const int _noisyHintSeconds = 10;

  /// Read once, while the session route is still the current one.
  late final bool _noisyRoom = SessionArguments.fromArguments(
    Get.arguments,
  ).noisyRoom;

  FreeSessionController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final (String, IconData, Color)? status = _status();
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: anim, child: child),
        ),
        child: status == null
            ? const SizedBox.shrink(key: ValueKey('none'))
            : HudPill(
                key: ValueKey(status.$1),
                borderColor: status.$3.withValues(alpha: 0.6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(status.$2, color: status.$3, size: 15.r),
                    SizedBox(width: 6.r),
                    // Shrinks with "…" in the small drill camera window.
                    Flexible(
                      child: Text(
                        status.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyLarge().copyWith(
                          fontSize: 13.fs,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      );
    });
  }

  (String, IconData, Color)? _status() {
    if (UsageService.to.countingStopped.value) {
      return (
        'Free limit reached · not counting',
        Icons.lock_clock_rounded,
        AppColors.gold,
      );
    }
    if (controller.isCameraUnavailable.value) {
      return (
        'Camera off · counting by sound',
        Icons.videocam_off_rounded,
        AppColors.warning,
      );
    }
    final (String, IconData, Color)? camera = _cameraStatus();
    if (camera != null) return camera;
    if (_noisyRoom && controller.elapsedSeconds.value < _noisyHintSeconds) {
      return (
        'Noisy room · punch firmly',
        Icons.volume_up_rounded,
        AppColors.warning,
      );
    }
    return null;
  }

  (String, IconData, Color)? _cameraStatus() {
    if (!controller.isCameraGateShownOnScreen) return null;
    switch (controller.liveCameraGateState.value) {
      case CameraGateState.notReady:
        return (
          'Starting camera…',
          Icons.hourglass_top_rounded,
          AppColors.textSecondary,
        );
      case CameraGateState.noPerson:
        return (
          'Step into view',
          Icons.person_search_rounded,
          AppColors.warning,
        );
      case CameraGateState.tooFar:
        return (
          'Move a little closer',
          Icons.zoom_in_rounded,
          AppColors.warning,
        );
      case CameraGateState.valid:
      case CameraGateState.notRequired:
        return null;
    }
  }
}

/// Developer-mode tools: detection mode (tap to cycle), tune sheet and
/// auto-configure. Hidden for normal users.
class SessionDevTools extends StatelessWidget {
  final FreeSessionController controller;

  const SessionDevTools({super.key, required this.controller});

  static String _modeLabel(DetectionMode mode) {
    switch (mode) {
      case DetectionMode.fusion:
        return 'FUSION';
      case DetectionMode.audio:
        return 'AUDIO';
      case DetectionMode.audioVibration:
        return 'AUDIO+VIBE';
      case DetectionMode.vibration:
        return 'VIBE';
      case DetectionMode.camera:
        return 'CAMERA';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DevOnly(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: controller.cycleDetectionMode,
            child: HudPill(
              borderColor: AppColors.warning.withValues(alpha: 0.6),
              padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 5.r),
              child: Obx(
                () => Text(
                  _modeLabel(controller.sessionMode.value),
                  style: AppTextStyles.tag().copyWith(
                    color: AppColors.warning,
                    fontSize: 10.fs,
                  ),
                ),
              ),
            ),
          ),
          _devIcon(
            Icons.tune_rounded,
            () => controller.showAudioSettingsSheet(context),
          ),
          _devIcon(
            Icons.auto_awesome_rounded,
            () => controller.autoConfigureSettings(context),
          ),
        ],
      ),
    );
  }

  Widget _devIcon(IconData icon, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: AppColors.warning, size: 20.r),
    );
  }
}

/// Raw detector status ("Candidate Impact (…)") for Developer mode.
class DevStatusText extends StatelessWidget {
  final FreeSessionController controller;

  const DevStatusText({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return DevOnly(
      child: HudPill(
        borderColor: AppColors.warning.withValues(alpha: 0.5),
        padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 4.r),
        child: Obx(
          () => Text(
            controller.detectionStatusText.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium().copyWith(
              color: AppColors.warning,
              fontSize: 10.fs,
            ),
          ),
        ),
      ),
    );
  }
}
