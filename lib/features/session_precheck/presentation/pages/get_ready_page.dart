import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/common_function.dart';
import '../../../../core/utils/size_box.dart';
import '../../../../core/widgets/dev_only.dart';
import '../../../../core/widgets/ui/app_buttons.dart';
import '../../../../core/widgets/ui/glass_card.dart';
import '../../../../core/widgets/ui/ring_progress.dart';
import '../../../session/presentation/widgets/pose_skeleton_painter.dart';
import '../../../vision_detection/data/subject_enrollment/subject_capture_service.dart';
import '../controllers/session_precheck_controller.dart';

/// One-screen setup before a session: live camera, "I'm ready", reference
/// photo + room-noise check together, then 3-2-1 and the session opens.
class GetReadyPage extends GetView<SessionPreCheckController> {
  const GetReadyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isLandscape = CommonFunction.checkOrientationLandscape(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.previousStep();
      },
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 12.w : 20.w,
                vertical: isLandscape ? 8.h : 12.h,
              ),
              child: isLandscape
                  ? Row(
                      children: [
                        Expanded(flex: 6, child: _cameraView(context, true)),
                        12.width,
                        Expanded(
                          flex: 4,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _topBar(context),
                                10.height,
                                _statusCard(context),
                                10.height,
                                _actions(context),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _topBar(context),
                        14.height,
                        Expanded(child: _cameraView(context, false)),
                        14.height,
                        _statusCard(context),
                        14.height,
                        _actions(context),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  String get _modeTitle {
    if (controller.sessionType != 'prompt') return 'Free Fight';
    final d = controller.difficulty;
    if (d == null) return 'Reaction Drill';
    return 'Reaction Drill · ${d[0].toUpperCase()}${d.substring(1)}';
  }

  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        GlassIconButton(
          icon: Icons.close_rounded,
          onPressed: controller.previousStep,
        ),
        12.width,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Get ready', style: AppTextStyles.heading3(context)),
              Text(
                _modeTitle,
                style: AppTextStyles.bodyMedium(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        DevOnly(
          child: TextButton(
            onPressed: () {
              Get.back();
              AppNavigator.toSessionPreCheck(
                sessionType: controller.sessionType,
              );
            },
            child: Text('Advanced', style: AppTextStyles.tag(context)),
          ),
        ),
      ],
    );
  }

  // ─── Camera ────────────────────────────────────────────────────────────────

  Widget _cameraView(BuildContext context, bool isLandscape) {
    final service = controller.captureService;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: AppColors.glassStroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: Obx(() {
        if (!controller.cameraGranted.value) {
          return _cameraMessage(
            context,
            Icons.videocam_off_rounded,
            'Camera access is off',
          );
        }
        if (service.isCameraUnavailable.value) {
          return _cameraMessage(
            context,
            Icons.videocam_off_rounded,
            'Camera unavailable',
          );
        }
        final CameraController? camera = service.cameraController;
        if (!service.isCameraReady.value ||
            camera == null ||
            !camera.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        final Size? previewSize = camera.value.previewSize;
        double width = 300;
        double height = 400;
        if (previewSize != null) {
          if (isLandscape) {
            width = max(previewSize.width, previewSize.height);
            height = min(previewSize.width, previewSize.height);
          } else {
            width = min(previewSize.width, previewSize.height);
            height = max(previewSize.width, previewSize.height);
          }
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: isLandscape ? BoxFit.contain : BoxFit.cover,
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  children: [
                    CameraPreview(camera),
                    Obx(() {
                      final pose = service.livePose.value;
                      if (pose == null) return const SizedBox.shrink();
                      return CustomPaint(
                        size: Size(width, height),
                        painter: PoseSkeletonPainter(
                          pose: pose,
                          absoluteImageSize: service.cameraImageSize,
                          isFrontCamera: service.isFrontCamera,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const IgnorePointer(child: _Vignette()),
            Positioned.fill(child: _overlay(context)),
          ],
        );
      }),
    );
  }

  Widget _cameraMessage(BuildContext context, IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 40.r),
          10.height,
          Text(text, style: AppTextStyles.bodyMedium(context)),
        ],
      ),
    );
  }

  /// Centre of the preview: 3-2-1 > photo countdown > room check > done.
  Widget _overlay(BuildContext context) {
    final service = controller.captureService;
    return IgnorePointer(
      child: Obx(() {
        final int launch = controller.launchCountdown.value;
        final CaptureStep step = service.step.value;
        final double capProgress = service.progress.value.clamp(0.0, 1.0);
        final int leftMs = service.countdownMs.value;
        Widget centre = const SizedBox.shrink(key: ValueKey('none'));

        if (launch > 0) {
          // The room check usually finishes during the 3-2-1.
          final bool listening = !controller.calibrationDone.value;
          centre = Column(
            key: ValueKey('go$launch'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                    '$launch',
                    style: AppTextStyles.number(context, 120).copyWith(
                      shadows: [
                        Shadow(
                          color: AppColors.primary.withValues(alpha: 0.8),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .scale(
                    begin: const Offset(1.8, 1.8),
                    duration: 350.ms,
                    curve: Curves.easeOutBack,
                  )
                  .fadeIn(duration: 200.ms),
              if (listening)
                Text(
                  'LISTENING…',
                  style: AppTextStyles.tag(
                    context,
                  ).copyWith(color: AppColors.gold),
                ),
            ],
          );
        } else if (controller.isLaunching.value &&
            controller.calibrationDone.value) {
          centre = Column(
            key: const ValueKey('go'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GO!',
                style: AppTextStyles.number(
                  context,
                  80,
                ).copyWith(color: AppColors.primary),
              ).animate().scale(duration: 250.ms),
              if (controller.isStartingSession.value) ...[
                12.height,
                SizedBox(
                  width: 22.r,
                  height: 22.r,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                8.height,
                Text(
                  'STARTING CAMERA…',
                  style: AppTextStyles.tag(
                    context,
                  ).copyWith(color: AppColors.textPrimary),
                ),
              ],
            ],
          );
        } else if (step == CaptureStep.prepare) {
          centre = _ring(
            context,
            key: 'prepare',
            progress: capProgress,
            label: '${(leftMs / 1000).ceil()}',
            caption: 'Get in position',
          );
        } else if (step == CaptureStep.holdStill) {
          centre = _ring(
            context,
            key: 'hold',
            progress: capProgress,
            label: (leftMs / 1000).toStringAsFixed(1),
            caption: 'Hold still',
          );
        } else if (step == CaptureStep.learning) {
          centre = _ring(
            context,
            key: 'learn',
            progress: capProgress,
            label: '${(capProgress * 100).round()}%',
            caption: 'Learning you',
          );
        } else if (controller.isCalibrating.value) {
          final double p = controller.calibrationProgress.value;
          centre = _ring(
            context,
            key: 'quiet',
            progress: p,
            label: '${(5 - p * 5).ceil()}',
            caption: controller.roomRechecking.value
                ? 'Once more'
                : 'Stay quiet',
            gradient: AppColors.goldGradient,
          );
        } else if (controller.captureDone.value) {
          centre = Icon(
            Icons.check_circle_rounded,
            key: const ValueKey('done'),
            color: AppColors.success,
            size: 84.r,
          ).animate().scale(curve: Curves.easeOutBack, duration: 400.ms);
        } else if (!controller.expressStarted.value) {
          centre = const _BodyGuide(key: ValueKey('guide'));
        }

        return Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: centre,
          ),
        );
      }),
    );
  }

  Widget _ring(
    BuildContext context, {
    required String key,
    required double progress,
    required String label,
    required String caption,
    Gradient gradient = AppColors.primaryGradient,
  }) {
    final double size = 132.r;
    return Container(
      key: ValueKey(key),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
      child: RingProgress(
        value: progress,
        size: size,
        strokeWidth: 7.r,
        gradient: gradient,
        trackColor: Colors.white.withValues(alpha: 0.12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppTextStyles.number(context, 36)),
            4.height,
            Text(
              caption.toUpperCase(),
              style: AppTextStyles.tag(context).copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.8),
                fontSize: 9.ts(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Status + actions ─────────────────────────────────────────────────────

  Widget _statusCard(BuildContext context) {
    final service = controller.captureService;
    return Obx(() {
      final step = service.step.value;
      final hint = service.hint.value;
      final IconData icon;
      final String title;
      final String subtitle;
      Color accent = AppColors.primary;

      if (controller.roomRechecking.value) {
        icon = Icons.volume_off_rounded;
        title = 'A bit noisy — stay quiet';
        subtitle = 'Checking the room once more so soft punches still count.';
        accent = AppColors.warning;
      } else if (controller.isLaunching.value &&
          !controller.calibrationDone.value) {
        icon = Icons.hearing_rounded;
        title = 'Stay still and quiet';
        subtitle = 'Listening to the room. Start punching on GO.';
        accent = AppColors.gold;
      } else if (controller.isLaunching.value &&
          controller.launchCountdown.value > 3) {
        icon = Icons.directions_walk_rounded;
        title = 'Step back into position';
        subtitle = 'Face and shoulders in view. Start punching on GO.';
      } else if (controller.isLaunching.value) {
        icon = Icons.sports_mma_rounded;
        title = 'Here we go!';
        subtitle = controller.isStartingSession.value
            ? 'Opening your session… start punching when the counter appears.'
            : 'Start punching when the counter appears.';
      } else if (!controller.expressStarted.value &&
          controller.quickStartAvailable.value &&
          controller.useQuickStart.value) {
        icon = Icons.bolt_rounded;
        title = 'Quick start ready';
        subtitle =
            'Same spot as your last session: no photo or room check. You get '
            '${SessionPreCheckController.quickStartCountdown} seconds to step back.';
        accent = AppColors.gold;
      } else if (!controller.expressStarted.value) {
        icon = Icons.accessibility_new_rounded;
        title = 'Stand where you will train';
        subtitle =
            'Put the phone at chest height, 1–2 m away. Face and shoulders in view.';
        accent = AppColors.textSecondary;
      } else if (!controller.captureDone.value) {
        icon = Icons.center_focus_strong_rounded;
        switch (step) {
          case CaptureStep.prepare:
            title = 'Get in position';
            subtitle = 'Step back to your spot.';
          case CaptureStep.findUser:
            title = 'Looking for you';
            subtitle = hint.isEmpty ? 'Face and shoulders in view.' : hint;
            accent = AppColors.warning;
          case CaptureStep.holdStill:
            title = 'Hold still';
            subtitle = 'Taking your photo and checking the room noise.';
          case CaptureStep.learning:
          case CaptureStep.ready:
          case CaptureStep.idle:
            title = 'Learning you';
            subtitle = 'Almost there…';
        }
      } else if (!controller.calibrationDone.value) {
        icon = Icons.hearing_rounded;
        title = 'Stay quiet for a moment';
        subtitle = 'Measuring the room noise so only punches count.';
        accent = AppColors.gold;
      } else {
        icon = Icons.check_rounded;
        title = 'All set';
        subtitle = 'Starting your session…';
        accent = AppColors.success;
      }

      return GlassCard(
        padding: EdgeInsets.all(14.r),
        child: Row(
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: accent, size: 22.r),
            ),
            12.width,
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Column(
                  key: ValueKey(title),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.heading3(context)),
                    2.height,
                    Text(subtitle, style: AppTextStyles.bodyMedium(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _actions(BuildContext context) {
    return Obx(() {
      if (!controller.expressStarted.value) {
        final quick =
            controller.quickStartAvailable.value &&
            controller.useQuickStart.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrimaryButton(
                  label: quick ? 'Quick start' : "I'm ready",
                  icon: quick ? Icons.bolt_rounded : Icons.play_arrow_rounded,
                  onPressed: controller.startExpress,
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(end: 1.02, duration: 900.ms, curve: Curves.easeInOut),
            if (controller.quickStartAvailable.value)
              Center(
                child: TextButton(
                  onPressed: controller.useQuickStart.toggle,
                  child: Text(
                    quick
                        ? 'Full setup instead (photo + room check)'
                        : 'Use Quick start',
                    style: AppTextStyles.bodyMedium(
                      context,
                    ).copyWith(decoration: TextDecoration.underline),
                  ),
                ),
              ),
          ],
        );
      }
      if (!controller.captureDone.value) {
        return Center(
          child: TextButton(
            onPressed: controller.skipReferencePhoto,
            child: Text(
              'Skip photo',
              style: AppTextStyles.bodyMedium(
                context,
              ).copyWith(decoration: TextDecoration.underline),
            ),
          ),
        );
      }
      return SizedBox(height: 48.h);
    });
  }
}

/// Body outline shown before the user starts, so they know how to stand.
class _BodyGuide extends StatelessWidget {
  const _BodyGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(
          Icons.accessibility_new_rounded,
          size: 160.r,
          color: Colors.white.withValues(alpha: 0.18),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fade(begin: 0.5, end: 1, duration: 1200.ms);
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: 0.95,
          colors: [Color(0x00000000), Color(0x99000000)],
          stops: [0.6, 1.0],
        ),
      ),
    );
  }
}
