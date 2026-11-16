import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/enums/detection_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/common_function.dart';
import '../../../../core/utils/size_box.dart';
import '../controllers/prompt_session_controller.dart';
import '../widgets/session_camera_panel.dart';
import '../widgets/session_sensor_stats_panel.dart';
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
          Expanded(
            child: SessionCameraPanel(
              controller: controller,
              isLandscape: false,
            ),
          ),
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
          Expanded(
            child: SessionCameraPanel(
              controller: controller,
              isLandscape: true,
            ),
          ),
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
                _buildLandscapePunchCount(context),
                4.height,
                Expanded(
                  child: SessionSensorStatsPanel(controller: controller),
                ),
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

  // Landscape punch count row (the sensor panel below has no count)
  Widget _buildLandscapePunchCount(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'PUNCHES',
            style: AppTextStyles.tag(context).copyWith(fontSize: 8.ts(context)),
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
    );
  }
}
