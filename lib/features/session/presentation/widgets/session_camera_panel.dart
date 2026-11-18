import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/utils/size_box.dart';
import '../../../../core/widgets/dev_only.dart';
import '../controllers/free_session_controller.dart';
import 'hud/session_hud.dart';
import 'pose_skeleton_painter.dart';
import 'subject_lock_pill.dart';

/// Live camera view shared by the Free and Prompt sessions: camera feed with
/// the pose skeleton and, along the top, the camera hint, reference photo
/// card and subject lock pill. MIC / ARM badges and the raw detector status
/// are Developer mode only. The bottom is left free for the session HUD.
class SessionCameraPanel extends StatelessWidget {
  const SessionCameraPanel({
    super.key,
    required this.controller,
    required this.isLandscape,
    this.compact = false,
  });

  final FreeSessionController controller;
  final bool isLandscape;

  /// Small picture-in-picture (drill landscape): only the camera hint is
  /// shown on top of the feed.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(compact ? 16 : 28.r),
        border: Border.all(color: AppColors.glassStroke),
      ),
      clipBehavior: compact ? Clip.antiAlias : Clip.none,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Native Camera Feed + Pose Skeleton Overlay in SAME FittedBox
          Obx(() {
            final bool isCameraDisabled =
                !controller.isVisionConfirmationRequired.value ||
                !controller.sessionMode.value.requiresCamera;

            if (isCameraDisabled) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: isLandscape ? 44.r : 60.r,
                      height: isLandscape ? 44.r : 60.r,
                      decoration: BoxDecoration(
                        color: AppColors.panel,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(
                        Icons.videocam_off,
                        size: isLandscape ? 22.w : 28.w,
                        color: AppColors.textMuted,
                      ),
                    ),
                    10.height,
                    Text(
                      'Camera off',
                      style: AppTextStyles.heading3(context).copyWith(
                        fontSize: isLandscape ? 12.ts(context) : 14.ts(context),
                      ),
                    ),
                    4.height,
                    Text(
                      'Counting punches by sound and impact.',
                      style: AppTextStyles.bodyMedium(context).copyWith(
                        color: AppColors.textMuted,
                        fontSize: isLandscape
                            ? 9.5.ts(context)
                            : 11.ts(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            if (controller.isCameraUnavailable.value) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videocam_off,
                      size: isLandscape ? 32.w : 48.w,
                      color: AppColors.textMuted,
                    ),
                    8.height,
                    Text(
                      'Camera unavailable',
                      style: AppTextStyles.bodyMedium(context),
                    ),
                  ],
                ),
              );
            }

            if (!controller.isCameraInitialized.value ||
                controller.cameraController == null) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final previewSize = controller.cameraController!.value.previewSize;
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

            return ClipRRect(
              borderRadius: BorderRadius.circular(27.r),
              child: SizedBox.expand(
                child: FittedBox(
                  fit: isLandscape ? BoxFit.contain : BoxFit.cover,
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: Stack(
                      children: [
                        CameraPreview(controller.cameraController!),
                        Obx(() {
                          if (controller.livePose.value == null) {
                            return const SizedBox.shrink();
                          }
                          return CustomPaint(
                            size: Size(width, height),
                            painter: PoseSkeletonPainter(
                              pose: controller.livePose.value,
                              absoluteImageSize: controller.cameraImageSize,
                              isFrontCamera: controller.isFrontCamera,
                              // Grey skeleton = user too far (punch rejected).
                              isInvalid: controller.isUserTooFar,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          // 2. Top overlays: dev MIC / ARM badges, camera hint, reference
          //    photo card (until the photo is taken), subject lock pill
          //    afterwards (tap = retake) and the dev raw status.
          Positioned(
            top: 10.h,
            left: 10.w,
            right: 10.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 6.h,
              children: [
                if (!compact)
                  DevOnly(
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                controller.showAudioTelemetrySheet(context),
                            child: Obx(() {
                              bool isHit = controller.isAudioHitActive.value;
                              bool isPassing =
                                  controller.liveDecibelLevel.value >=
                                  controller.minPunchAudioDb.value;
                              bool isHighlighted = isHit || isPassing;
                              if (!AppConstants.showAllFeatures) {
                                isHit = false;
                                isPassing = false;
                                isHighlighted = false;
                              }

                              final Color accentColor = isHit
                                  ? AppColors.lime
                                  : (isPassing
                                        ? AppColors.amber
                                        : AppColors.lime);
                              final Color bgColor = isHit
                                  ? AppColors.lime.withValues(alpha: 0.25)
                                  : (isPassing
                                        ? AppColors.amber.withValues(
                                            alpha: 0.15,
                                          )
                                        : AppColors.panel.withValues(
                                            alpha: 0.90,
                                          ));
                              final Color borderColor = isHit
                                  ? AppColors.lime.withValues(alpha: 0.4)
                                  : (isPassing
                                        ? AppColors.amber
                                        : AppColors.border);

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: EdgeInsets.all(5.r),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: borderColor,
                                    width: isHighlighted ? 1.8 : 1.0,
                                  ),
                                  boxShadow: isHit
                                      ? [
                                          BoxShadow(
                                            color: AppColors.lime.withValues(
                                              alpha: 0.50,
                                            ),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'MIC ⚙',
                                              style: TextStyle(
                                                fontSize: 8.ts(context),
                                                color: accentColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (isHit) ...[
                                              2.width,
                                              Text(
                                                '⚡ HIT',
                                                style: TextStyle(
                                                  fontSize: 7.ts(context),
                                                  color: AppColors.lime,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Flexible(
                                          child: Text(
                                            '+${controller.liveSpikeThresholdDb.value.toStringAsFixed(1)}dB',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 7.5.ts(context),
                                              color: isHighlighted
                                                  ? accentColor
                                                  : AppColors.textMuted,
                                              fontWeight: isHighlighted
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // ---------------------------------------------------------------------
                                    // PREVIOUS (Instantaneous live dB — showed jitter too fast):
                                    // Text(
                                    //   '${controller.liveDecibelLevel.value.round()} dB (Base: ${controller.liveBaselineDb.value.round()} dB)',
                                    //   style: TextStyle(
                                    //     color: isHighlighted
                                    //         ? accentColor
                                    //         : AppColors.textMuted,
                                    //     fontSize: 11.ts(context),
                                    //     fontWeight: FontWeight.bold,
                                    //   ),
                                    // ),
                                    // ---------------------------------------------------------------------
                                    // CURRENT (Rolling average dB matching waveform graph to remove jitter):
                                    () {
                                      final double displayDb =
                                          controller.decibelHistory.isNotEmpty
                                          ? (controller.decibelHistory.reduce(
                                                  (a, b) => a + b,
                                                ) /
                                                controller
                                                    .decibelHistory
                                                    .length)
                                          : controller.liveDecibelLevel.value;
                                      return Text(
                                        '${displayDb.round()} dB',
                                        // '${displayDb.round()} dB (Base: ${controller.liveBaselineDb.value.round()} dB)',
                                        style: TextStyle(
                                          color: isHighlighted
                                              ? accentColor
                                              : AppColors.textMuted,
                                          fontSize: 11.ts(context),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    }(),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                        6.width,
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                controller.showLiveTelemetrySheet(context),
                            child: Obx(() {
                              bool isHit = controller.isVisionHitActive.value;
                              bool isPassing =
                                  controller.visionConfidence.value >=
                                  controller.minPunchVisionConfidence.value;
                              bool isHighlighted = isHit || isPassing;
                              if (!AppConstants.showAllFeatures) {
                                isHit = false;
                                isPassing = false;
                                isHighlighted = false;
                              }

                              final Color accentColor = isHit
                                  ? AppColors.green
                                  : (isPassing
                                        ? AppColors.blue
                                        : AppColors.blue);
                              final Color bgColor = isHit
                                  ? AppColors.green.withValues(alpha: 0.25)
                                  : (isPassing
                                        ? AppColors.blue.withValues(alpha: 0.15)
                                        : AppColors.panel.withValues(
                                            alpha: 0.90,
                                          ));
                              final Color borderColor = isHit
                                  ? AppColors.green
                                  : (isPassing
                                        ? AppColors.blue
                                        : AppColors.border);

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: EdgeInsets.all(5.r),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: borderColor,
                                    width: isHighlighted ? 1.8 : 1.0,
                                  ),
                                  boxShadow: isHit
                                      ? [
                                          BoxShadow(
                                            color: AppColors.green.withValues(
                                              alpha: 0.50,
                                            ),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'ARM 📊',
                                              style: TextStyle(
                                                fontSize: 8.ts(context),
                                                color: accentColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (isHit) ...[
                                              2.width,
                                              Text(
                                                '⚡ HIT',
                                                style: TextStyle(
                                                  fontSize: 7.ts(context),
                                                  color: AppColors.green,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Flexible(
                                          child: Text(
                                            '${controller.minPunchVisionConfidence.value.round()}%',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 7.5.ts(context),
                                              color: isHighlighted
                                                  ? accentColor
                                                  : AppColors.textMuted,
                                              fontWeight: isHighlighted
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      (controller.isCameraUnavailable.value ||
                                              !controller
                                                  .isVisionConfirmationRequired
                                                  .value ||
                                              !controller
                                                  .sessionMode
                                                  .value
                                                  .requiresCamera)
                                          ? 'DISABLED'
                                          : '${controller.visionConfidence.value}%',
                                      style: TextStyle(
                                        color: isHighlighted
                                            ? accentColor
                                            : AppColors.textMuted,
                                        fontSize: 11.ts(context),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                SessionStatusChip(controller: controller),
                if (!compact) ...[
                  ReferencePhotoCard(
                    state: controller.subjectLockState,
                    holdStillSeconds: controller.subjectHoldStillSeconds,
                    photo: controller.subjectReferencePhoto,
                    onSkip: controller.skipReferencePhoto,
                    isVisible: () =>
                        controller.isSubjectLockEnabled.value &&
                        controller.isCameraInitialized.value,
                  ),
                  SubjectLockPill(
                    state: controller.subjectLockState,
                    onTap: controller.relockSubject,
                    isVisible: () =>
                        controller.isSubjectLockEnabled.value &&
                        controller.isCameraInitialized.value,
                    photo: controller.subjectReferencePhoto,
                    referenceColor: controller.subjectReferenceColor,
                    liveColor: controller.subjectLiveColor,
                  ),
                  DevStatusText(controller: controller),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
