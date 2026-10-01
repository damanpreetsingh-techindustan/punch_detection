import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/enums/detection_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/common_function.dart';
import '../../../../core/utils/size_box.dart';
import '../controllers/prompt_session_controller.dart';
import '../widgets/live_telemetry_sheet.dart';
import '../widgets/pose_skeleton_painter.dart';
import '../../../../core/widgets/animated_punch_count_text.dart';

class PromptSessionPage extends GetView<PromptSessionController> {
  const PromptSessionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isLandscape = CommonFunction.checkOrientationLandscape(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: isLandscape
            ? _buildLandscapeLayout(context)
            : _buildPortraitLayout(context),
      ),
    );
  }

  // --- PORTRAIT LAYOUT ---
  Widget _buildPortraitLayout(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 22.w),
      child: Column(
        children: [
          12.height,
          _buildHeaderRow(context, isLandscape: false),
          12.height,
          _buildPromptHeader(context, isLandscape: false),
          12.height,
          Expanded(child: _buildCameraContainer(context, isLandscape: false)),
          12.height,
          _buildPortraitBottomStatsTile(context),
          12.height,
        ],
      ),
    );
  }

  // --- LANDSCAPE LAYOUT (Maximized Camera Width) ---
  Widget _buildLandscapeLayout(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      child: Row(
        children: [
          // Left Column: Maximized Wide Camera View with Skeleton Overlay
          Expanded(child: _buildCameraContainer(context, isLandscape: true)),
          8.width,
          // Right Column: Compact Control & Stats HUD Panel
          SizedBox(
            width: 170.w,
            child: Column(
              children: [
                SizedBox(
                  height: 35.h,
                  child: _buildHeaderRow(context, isLandscape: true),
                ),
                4.height,
                _buildPromptHeader(context, isLandscape: true),
                4.height,
                Expanded(child: _buildLandscapeStatsCard(context)),
                4.height,
                SizedBox(
                  height: 32.h,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: AppColors.amber,
                              width: 1.w,
                            ),
                            minimumSize: Size(0, 32.h),
                            padding: EdgeInsets.symmetric(vertical: 4.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          onPressed: controller.resetPunchCount,
                          icon: Icon(
                            Icons.refresh,
                            color: AppColors.amber,
                            size: 12.w,
                          ),
                          label: Text(
                            'RESET',
                            style: TextStyle(
                              color: AppColors.amber,
                              fontSize: 9.5.ts(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      6.width,
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.red,
                            minimumSize: Size(0, 32.h),
                            padding: EdgeInsets.symmetric(vertical: 4.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          onPressed: () => controller.finishSession(),
                          child: Text(
                            'FINISH',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5.ts(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Header Row (Back button, Mode pill, Mode switcher icon)
  Widget _buildHeaderRow(BuildContext context, {required bool isLandscape}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            Icons.arrow_back_ios,
            color: AppColors.textPrimary,
            size: isLandscape ? 16.w : 22.w,
          ),
          onPressed: () => controller.finishSession(),
        ),
        Obx(() {
          final mode = controller.sessionMode.value;
          String label = isLandscape
              ? 'FUSION'
              : 'AUDIO + VIBRATION + CAMERA FUSION';
          Color color = AppColors.lime;
          if (mode == DetectionMode.audio) {
            label = isLandscape ? 'AUDIO' : 'AUDIO ONLY MODE';
            color = AppColors.amber;
          } else if (mode == DetectionMode.audioVibration) {
            label = isLandscape ? 'AUDIO+VIBE' : 'AUDIO + VIBRATION MODE';
            color = Colors.cyanAccent;
          } else if (mode == DetectionMode.vibration) {
            label = isLandscape ? 'VIBE' : 'VIBRATION ONLY MODE';
            color = Colors.purpleAccent;
          } else if (mode == DetectionMode.camera) {
            label = isLandscape ? 'CAMERA' : 'CAMERA ONLY MODE';
            color = AppColors.blue;
          }

          return GestureDetector(
            onTap: controller.cycleDetectionMode,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 8.w : 14.w,
                vertical: isLandscape ? 3.h : 6.h,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999.r),
                border: Border.all(color: color),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: isLandscape ? 9.ts(context) : 6.ts(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        }),
        Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                Icons.refresh,
                color: AppColors.amber,
                size: isLandscape ? 18.w : 22.w,
              ),
              tooltip: 'Reset Count',
              onPressed: controller.resetPunchCount,
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                Icons.tune,
                color: AppColors.lime,
                size: isLandscape ? 18.w : 22.w,
              ),
              tooltip: 'Detection Settings',
              onPressed: () => controller.showAudioSettingsSheet(context),
            ),
            10.width,
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                Icons.auto_awesome,
                color: AppColors.cyan,
                size: isLandscape ? 18.w : 22.w,
              ),
              tooltip: 'Auto Configure Settings',
              onPressed: () => controller.autoConfigureSettings(context),
            ),
            // Obx(
            //   () => IconButton(
            //     padding: EdgeInsets.zero,
            //     constraints: const BoxConstraints(),
            //     icon: Icon(
            //       controller.sessionMode.value == DetectionMode.audio
            //           ? Icons.volume_up
            //           : (controller.sessionMode.value ==
            //                     DetectionMode.audioVibration
            //                 ? Icons.ring_volume
            //                 : (controller.sessionMode.value ==
            //                           DetectionMode.vibration
            //                       ? Icons.vibration
            //                       : (controller.sessionMode.value ==
            //                                 DetectionMode.camera
            //                             ? Icons.videocam
            //                             : Icons.bolt))),
            //       color: AppColors.lime,
            //       size: isLandscape ? 18.w : 24.w,
            //     ),
            //     onPressed: () => controller.cycleDetectionMode(),
            //   ),
            // ),
          ],
        ),
      ],
    );
  }

  // Prompt Callout Banner / Card
  Widget _buildPromptHeader(BuildContext context, {required bool isLandscape}) {
    if (isLandscape) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Row(
              children: [
                Text(
                  'PUNCH WHEN YOU SEE',
                  style: AppTextStyles.tag(
                    context,
                  ).copyWith(fontSize: 8.ts(context)),
                ),
                45.width,
                Obx(
                  () => Text(
                    controller.promptText.value,
                    style: AppTextStyles.heading1(context).copyWith(
                      fontSize: 30.ts(context),
                      height: 1.0,
                      color: AppColors.lime,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            45.width,
            Obx(
              () => Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(999.r),
                  border: Border.all(
                    color: AppColors.cyan.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      color: AppColors.cyan,
                      size: 10.w,
                    ),
                    3.width,
                    Text(
                      controller.formattedElapsedTime,
                      style: TextStyle(
                        color: AppColors.cyan,
                        fontSize: 9.ts(context),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text('PUNCH WHEN YOU SEE', style: AppTextStyles.tag(context)),
            4.width,
            Obx(
              () => Text(
                controller.promptText.value,
                style: AppTextStyles.heading1(context).copyWith(
                  fontSize: 70.ts(context),
                  height: 0.95,
                  color: AppColors.lime,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        6.height,
        Obx(
          () => Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(999.r),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, color: AppColors.cyan, size: 14.w),
                5.width,
                Text(
                  controller.formattedElapsedTime,
                  style: TextStyle(
                    color: AppColors.cyan,
                    fontSize: 13.ts(context),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Live Camera Container & Skeleton Overlay (BoxFit.contain in Landscape for Full Wide Uncropped View)
  Widget _buildCameraContainer(
    BuildContext context, {
    required bool isLandscape,
  }) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF070D14),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border, width: 2.w),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Native Camera Feed + ML Kit Pose Overlay inside SAME FittedBox
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
                      'Camera View Disabled',
                      style: AppTextStyles.heading3(context).copyWith(
                        fontSize: isLandscape ? 12.ts(context) : 14.ts(context),
                      ),
                    ),
                    4.height,
                    Text(
                      'Detecting punches via acoustic audio & impact shockwaves.',
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
                      'Camera Offline — Audio Only',
                      style: AppTextStyles.bodyMedium(context),
                    ),
                  ],
                ),
              );
            }

            if (!controller.isCameraInitialized.value ||
                controller.cameraController == null) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.lime),
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
              borderRadius: BorderRadius.circular(18.r),
              child: SizedBox.expand(
                child: FittedBox(
                  // In landscape mode: contain shows 100% of wide uncropped camera field of view
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

          // 2. Top Telemetry Badges Bar
          Positioned(
            top: 8.h,
            left: 8.w,
            right: 8.w,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => controller.showAudioTelemetrySheet(context),
                    child: Obx(() {
                      final bool isHit = controller.isAudioHitActive.value;
                      final bool isPassing =
                          controller.liveDecibelLevel.value >=
                          controller.minPunchAudioDb.value;
                      final bool isHighlighted = isHit || isPassing;

                      final Color accentColor = isHit
                          ? AppColors.lime
                          : (isPassing ? AppColors.amber : AppColors.lime);
                      final Color bgColor = isHit
                          ? AppColors.lime.withValues(alpha: 0.25)
                          : (isPassing
                                ? AppColors.amber.withValues(alpha: 0.15)
                                : AppColors.panel.withValues(alpha: 0.90));
                      final Color borderColor = isHit
                          ? AppColors.lime
                          : (isPassing ? AppColors.amber : AppColors.border);

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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    '${controller.minPunchAudioDb.value.round()}dB',
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
                              '${controller.liveDecibelLevel.value.round()} dB → ${controller.audioConfidence.value}%',
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
                6.width,
                Expanded(
                  child: GestureDetector(
                    onTap: () => controller.showLiveTelemetrySheet(context),
                    child: Obx(() {
                      final bool isHit = controller.isVisionHitActive.value;
                      final bool isPassing =
                          controller.visionConfidence.value >=
                          controller.minPunchVisionConfidence.value;
                      final bool isHighlighted = isHit || isPassing;

                      final Color accentColor = isHit
                          ? AppColors.green
                          : (isPassing ? AppColors.blue : AppColors.blue);
                      final Color bgColor = isHit
                          ? AppColors.green.withValues(alpha: 0.25)
                          : (isPassing
                                ? AppColors.blue.withValues(alpha: 0.15)
                                : AppColors.panel.withValues(alpha: 0.90));
                      final Color borderColor = isHit
                          ? AppColors.green
                          : (isPassing ? AppColors.blue : AppColors.border);

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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

          // 3. Bottom Live Status Badge
          Positioned(
            bottom: 8.h,
            child: Obx(
              () => Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1E2E).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999.r),
                  border: Border.all(color: AppColors.blue),
                ),
                child: Text(
                  controller.detectionStatusText.value,
                  style: TextStyle(
                    color: AppColors.blue,
                    fontSize: 9.ts(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Portrait Bottom Stats Tile
  Widget _buildPortraitBottomStatsTile(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text('PUNCHES', style: AppTextStyles.tag(context)),
              4.height,
              Obx(
                () => AnimatedPunchCountText(
                  count: controller.punchCount.value,
                  style: AppTextStyles.heading2(
                    context,
                  ).copyWith(color: AppColors.lime, fontSize: 24.ts(context)),
                ),
              ),
            ],
          ),
          Container(height: 32.h, width: 1.w, color: AppColors.border),
          Column(
            children: [
              Text('LIVE MIC', style: AppTextStyles.tag(context)),
              4.height,
              Obx(
                () => Text(
                  '${controller.liveDecibelLevel.value.round()} dB',
                  style: AppTextStyles.heading2(context).copyWith(
                    color: controller.liveDecibelLevel.value >= 75
                        ? AppColors.lime
                        : AppColors.textMuted,
                    fontSize: 18.ts(context),
                  ),
                ),
              ),
            ],
          ),
          Container(height: 32.h, width: 1.w, color: AppColors.border),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.amber, width: 1.5.w),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            onPressed: controller.resetPunchCount,
            icon: Icon(Icons.refresh, color: AppColors.amber, size: 16.w),
            label: Text(
              'RESET',
              style: TextStyle(
                color: AppColors.amber,
                fontSize: 12.ts(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            onPressed: () => controller.finishSession(),
            child: Text(
              'FINISH',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.ts(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Landscape Stats Card
  Widget _buildLandscapeStatsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(8.r),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Flexible(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PUNCHES',
                      style: AppTextStyles.tag(
                        context,
                      ).copyWith(fontSize: 8.ts(context)),
                    ),
                    Obx(
                      () => AnimatedPunchCountText(
                        count: controller.punchCount.value,
                        style: TextStyle(
                          color: AppColors.lime,
                          fontSize: 12.ts(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 14.h,
                child: const VerticalDivider(
                  color: AppColors.border,
                  thickness: 1,
                ),
              ),
              Flexible(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MIC',
                      style: AppTextStyles.tag(
                        context,
                      ).copyWith(fontSize: 8.ts(context)),
                    ),
                    Obx(() {
                      // ---------------------------------------------------------------------
                      // PREVIOUS (Instantaneous live dB — showed jitter too fast):
                      // final double db = controller.liveDecibelLevel.value;
                      // ---------------------------------------------------------------------
                      // CURRENT (Rolling average dB matching real-time graph samples):
                      final double db = controller.decibelHistory.isNotEmpty
                          ? (controller.decibelHistory.reduce((a, b) => a + b) /
                                controller.decibelHistory.length)
                          : controller.liveDecibelLevel.value;
                      final double baseline = controller.liveBaselineDb.value;
                      final double spike = db - baseline;
                      final bool isHot =
                          spike >= controller.liveSpikeThresholdDb.value;
                      return Text(
                        isHot
                            ? '${db.round()} dB (+${spike.round()})'
                            : '${db.round()} dB',
                        style: TextStyle(
                          color: isHot ? AppColors.lime : AppColors.textMuted,
                          fontSize: 10.ts(context),
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              SizedBox(
                height: 14.h,
                child: const VerticalDivider(
                  color: AppColors.border,
                  thickness: 1,
                ),
              ),
              Flexible(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'VIB',
                      style: AppTextStyles.tag(
                        context,
                      ).copyWith(fontSize: 8.ts(context)),
                    ),
                    Obx(() {
                      final bool isVibeDisabled =
                          controller.mountType.value.isVibrationDisabled ||
                          !controller.isVibrationGateEnabled.value ||
                          !controller.sessionMode.value.requiresVibration;
                      if (isVibeDisabled) {
                        return Flexible(
                          child: Text(
                            controller.mountType.value.isVibrationDisabled
                                ? '⛔ DISABLED (POLE)'
                                : '⛔ DISABLED',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 9.ts(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      final double mag =
                          controller.liveVibrationMagnitude.value;
                      final bool isVibe =
                          controller.isVibrationGateEnabled.value &&
                          mag >= controller.minVibrationThreshold.value;
                      return Text(
                        isVibe
                            ? '📳 ${mag.toStringAsFixed(2)} HIT'
                            : '${mag.toStringAsFixed(2)} IDLE',
                        style: TextStyle(
                          color: isVibe
                              ? const Color(0xFFA78BFA)
                              : AppColors.textMuted,
                          fontSize: 9.5.ts(context),
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
          6.height,

          // Real-Time Audio Telemetry: MIN, AVG, MAX (PEAK), TARGET & VOICE STATUS
          Obx(() {
            final double currentDb = controller.liveDecibelLevel.value;
            final double minDb = controller.minAudioDbRecorded.value > 0
                ? controller.minAudioDbRecorded.value
                : (controller.decibelHistory.isNotEmpty
                      ? controller.decibelHistory.reduce(min)
                      : controller.liveBaselineDb.value);
            final double avgDb = controller.decibelHistory.isNotEmpty
                ? (controller.decibelHistory.reduce((a, b) => a + b) /
                      controller.decibelHistory.length)
                : controller.liveBaselineDb.value;
            final double maxDb = controller.peakAudioDbRecorded.value;
            final double targetDb = controller.customTargetAudioDb.value > 0
                ? controller.customTargetAudioDb.value
                : controller.minPunchAudioDb.value;

            // Real-time Voice / Sound Classification
            final String voiceStatus;
            final Color voiceColor;
            if (currentDb >= targetDb) {
              voiceStatus = '💥 HIT';
              voiceColor = AppColors.lime;
            } else if (currentDb >= 55.0) {
              voiceStatus = '🗣️ VOICE';
              voiceColor = AppColors.amber;
            } else {
              voiceStatus = '⚪ QUIET';
              voiceColor = AppColors.textMuted;
            }

            return Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 6.h),
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: const Color(0xFF070D18),
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAudioStatItem(
                    context,
                    'MIN',
                    '${minDb.round()}dB',
                    AppColors.cyan,
                  ),
                  _buildAudioStatDivider(),
                  _buildAudioStatItem(
                    context,
                    'AVG',
                    '${avgDb.round()}dB',
                    AppColors.blue,
                  ),
                  _buildAudioStatDivider(),
                  _buildAudioStatItem(
                    context,
                    'MAX',
                    '${maxDb.round()}dB',
                    AppColors.amber,
                  ),
                  _buildAudioStatDivider(),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 1.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: voiceColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(4.r),
                      border: Border.all(
                        color: voiceColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      voiceStatus,
                      style: TextStyle(
                        color: voiceColor,
                        fontSize: 7.5.ts(context),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Embedded Real-Time Audio Spike Waveform Line Graph
          Expanded(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(4.r),
              decoration: BoxDecoration(
                color: const Color(0xFF030712),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6.r),
                child: Obx(
                  () => CustomPaint(
                    painter: AudioSpikeWaveformPainter(
                      decibelSamples: controller.decibelHistory,
                      thresholdDb: controller.customTargetAudioDb.value > 0
                          ? controller.customTargetAudioDb.value
                          : controller.minPunchAudioDb.value,
                      calibrationDb: controller.staticCalibratedAudioDb.value,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioStatItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 7.5.ts(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        2.width,
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 8.5.ts(context),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildAudioStatDivider() {
    return Container(width: 1, height: 10.h, color: const Color(0xFF1E293B));
  }
}
