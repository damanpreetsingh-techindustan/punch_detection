import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/enums/detection_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/common_function.dart';
import '../../../../core/utils/size_box.dart';
import '../controllers/free_session_controller.dart';
import '../../../../core/widgets/animated_punch_count_text.dart';
import '../widgets/session_camera_panel.dart';
import '../widgets/session_sensor_stats_panel.dart';

class FreeSessionPage extends GetView<FreeSessionController> {
  const FreeSessionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isLandscape = CommonFunction.checkOrientationLandscape(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          controller.finishSession();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: isLandscape
              ? _buildLandscapeLayout(context)
              : _buildPortraitLayout(context),
        ),
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
          _buildPunchCountHeader(context, isLandscape: false),
          12.height,
          Expanded(
            child: SessionCameraPanel(
              controller: controller,
              isLandscape: false,
            ),
          ),
          12.height,
          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.amber, width: 1.5.w),
                    minimumSize: Size(0, 54.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  onPressed: controller.resetPunchCount,
                  icon: Icon(Icons.refresh, color: AppColors.amber, size: 18.w),
                  label: Text(
                    'Reset',
                    style: AppTextStyles.buttonLabel(context).copyWith(
                      fontSize: 14.sp,
                      color: AppColors.amber,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              12.width,
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyan,
                    minimumSize: Size(double.infinity, 54.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  onPressed: controller.finishSession,
                  child: Text(
                    'Finish workout session',
                    style: AppTextStyles.buttonLabel(context).copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          16.height,
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
          // Left Side: Maximized Wide Camera Feed with Overlay
          Expanded(
            child: SessionCameraPanel(
              controller: controller,
              isLandscape: true,
            ),
          ),
          8.width,
          // Right Side: Compact Control & Stats HUD Panel
          SizedBox(
            width: 170.w,
            child: Column(
              children: [
                _buildHeaderRow(context, isLandscape: true),
                4.height,
                _buildPunchCountHeader(context, isLandscape: true),
                4.height,
                // audio + vibration + camera view detail view
                Expanded(
                  child: SessionSensorStatsPanel(controller: controller),
                ),
                6.height,
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.amber, width: 1.w),
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
                          'Reset',
                          style: TextStyle(
                            color: AppColors.amber,
                            fontSize: 9.5.ts(context),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    6.width,
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: Size(0, 32.h),
                          padding: EdgeInsets.symmetric(vertical: 4.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        onPressed: controller.finishSession,
                        child: Text(
                          'Finish',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 9.5.ts(context),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Header Row (Back, Mode pill, Mode switcher icon)
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
              : 'FREE MODE — AUDIO + VIBE + CAMERA';
          Color color = AppColors.lime;
          if (mode == DetectionMode.audio) {
            label = isLandscape ? 'AUDIO' : 'FREE MODE — AUDIO ONLY';
            color = AppColors.amber;
          } else if (mode == DetectionMode.audioVibration) {
            label = isLandscape
                ? 'AUDIO+VIBE'
                : 'FREE MODE — AUDIO + VIBRATION';
            color = Colors.cyanAccent;
          } else if (mode == DetectionMode.vibration) {
            label = isLandscape ? 'VIBE' : 'FREE MODE — VIBRATION ONLY';
            color = Colors.purpleAccent;
          } else if (mode == DetectionMode.camera) {
            label = isLandscape ? 'CAMERA' : 'FREE MODE — CAMERA ONLY';
            color = AppColors.blue;
          }

          return GestureDetector(
            onTap: controller.cycleDetectionMode,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 8.w : 10.w,
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
                  fontSize: isLandscape ? 9.ts(context) : 9.ts(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        }),
        Flexible(
          child: Row(
            children: [
              Flexible(
                child: IconButton(
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
              ),
              10.width,
              Flexible(
                child: IconButton(
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
              ),
              10.width,
              Flexible(
                child: IconButton(
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
              ),
              10.width,
              // !AppConstants.showAllFeatures? SizedBox():
              // Flexible(
              //   child: Obx(
              //     () => IconButton(
              //       padding: EdgeInsets.zero,
              //       constraints: const BoxConstraints(),
              //       icon: Icon(
              //         controller.sessionMode.value == 'audio'
              //             ? Icons.volume_up
              //             : (controller.sessionMode.value == 'audio_vibration'
              //                   ? Icons.ring_volume
              //                   : (controller.sessionMode.value == 'vibration'
              //                         ? Icons.vibration
              //                         : (controller.sessionMode.value ==
              //                                   'camera'
              //                               ? Icons.videocam
              //                               : Icons.bolt))),
              //         color: AppColors.lime,
              //         size: isLandscape ? 18.w : 24.w,
              //       ),
              //       onPressed: () => controller.cycleDetectionMode(),
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      ],
    );
  }

  // Punch Count Header Card
  Widget _buildPunchCountHeader(
    BuildContext context, {
    required bool isLandscape,
  }) {
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
            Text(
              'TOTAL PUNCHES',
              style: AppTextStyles.tag(
                context,
              ).copyWith(fontSize: 8.ts(context)),
            ),
            Obx(
              () => Expanded(
                child: AnimatedPunchCountText(
                  count: controller.punchCount.value,
                  style: AppTextStyles.heading1(context).copyWith(
                    fontSize: 30.ts(context),
                    height: 1.0,
                    color: AppColors.blue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            2.height,
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

    return Column(
      children: [
        Text('TOTAL PUNCHES DETECTED', style: AppTextStyles.tag(context)),
        4.height,
        Obx(
          () => AnimatedPunchCountText(
            count: controller.punchCount.value,
            style: AppTextStyles.heading1(context).copyWith(
              fontSize: 64.ts(context),
              height: 0.95,
              color: AppColors.blue,
              fontWeight: FontWeight.w900,
            ),
          ),
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
}
