import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/utils/size_box.dart';
import '../../../fusion/domain/services/impact_gate_evaluator.dart';
import '../controllers/free_session_controller.dart';
import 'live_telemetry_sheet.dart';

/// Landscape sensor panel shared by the Free and Prompt sessions: MIC / VIB /
/// CAM status, MIN / AVG / MAX audio and the live waveform.
class SessionSensorStatsPanel extends StatelessWidget {
  const SessionSensorStatsPanel({super.key, required this.controller});

  final FreeSessionController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // MIC Column
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MIC',
                          style: AppTextStyles.tag(
                            context,
                          ).copyWith(fontSize: 8.ts(context)),
                        ),
                        Obx(() {
                          final double db = AppConstants.useAvarageAudioFormate
                              ? (controller.decibelHistory.isNotEmpty
                                    ? (controller.decibelHistory.reduce(
                                            (a, b) => a + b,
                                          ) /
                                          controller.decibelHistory.length)
                                    : controller.liveDecibelLevel.value)
                              : controller.liveDecibelLevel.value;
                          return Text(
                            '${db.round()}dB',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 9.ts(context),
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }),
                      ],
                    ),
                    1.height,
                    Obx(() {
                      final double db = AppConstants.useAvarageAudioFormate
                          ? (controller.decibelHistory.isNotEmpty
                                ? (controller.decibelHistory.reduce(
                                        (a, b) => a + b,
                                      ) /
                                      controller.decibelHistory.length)
                                : controller.liveDecibelLevel.value)
                          : controller.liveDecibelLevel.value;
                      final double baseline = controller.liveBaselineDb.value;
                      final double spike = db - baseline;
                      final String text;
                      final Color color;
                      if (spike >= 8.0) {
                        text = '🟢 Strong';
                        color = AppColors.lime;
                      } else if (spike >= 4.0) {
                        text = '🟡 Weak';
                        color = AppColors.amber;
                      } else {
                        text = '⚪ Listen';
                        color = AppColors.textMuted;
                      }
                      return Text(
                        text,
                        style: TextStyle(
                          color: color,
                          fontSize: 8.ts(context),
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              SizedBox(
                height: 24.h,
                child: const VerticalDivider(
                  color: AppColors.border,
                  thickness: 1,
                ),
              ),
              // VIBE Column
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
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
                            return Text(
                              'OFF',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 9.ts(context),
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }
                          final double mag =
                              controller.liveVibrationMagnitude.value;
                          return Text(
                            mag.toStringAsFixed(2),
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 9.ts(context),
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }),
                      ],
                    ),
                    1.height,
                    Obx(() {
                      final bool isVibeDisabled =
                          controller.mountType.value.isVibrationDisabled ||
                          !controller.isVibrationGateEnabled.value ||
                          !controller.sessionMode.value.requiresVibration;
                      if (isVibeDisabled) {
                        return Text(
                          controller.mountType.value.isVibrationDisabled
                              ? '⛔ Pole (Off)'
                              : '⛔ Disabled',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 8.ts(context),
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }
                      final double mag =
                          controller.liveVibrationMagnitude.value;
                      final double thresh =
                          controller.minVibrationThreshold.value;
                      final String text;
                      final Color color;
                      if (mag >= thresh) {
                        text = '🟢 Strong';
                        color = const Color(0xFFA78BFA);
                      } else {
                        text = '⚪ Idle';
                        color = AppColors.textMuted;
                      }
                      return Text(
                        text,
                        style: TextStyle(
                          color: color,
                          fontSize: 8.ts(context),
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              SizedBox(
                height: 24.h,
                child: const VerticalDivider(
                  color: AppColors.border,
                  thickness: 1,
                ),
              ),
              // CAM Column
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CAM',
                          style: AppTextStyles.tag(
                            context,
                          ).copyWith(fontSize: 8.ts(context)),
                        ),
                        Obx(
                          () => Text(
                            controller.isCameraUnavailable.value
                                ? 'OFF'
                                : '${controller.visionConfidence.value}%',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 9.ts(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    1.height,
                    Obx(() {
                      final evalResult = controller.liveEvaluationResult.value;
                      final bool isCamInit =
                          !controller.isCameraUnavailable.value &&
                          controller.isCameraInitialized.value;
                      final bool isBodyVisibleInFrame =
                          isCamInit &&
                          evalResult != null &&
                          evalResult.confidenceScore > 0.0 &&
                          !evalResult.debugTelemetry.contains('Pose Invalid');

                      String text;
                      Color color;
                      if (controller.isCameraGateShownOnScreen) {
                        // Fusion mode: show the SAME person /
                        // distance check a punch must pass, live.
                        // (The old label used the camera's arm-
                        // motion detector, which is "false" between
                        // punches, so a valid user saw "Reject".)
                        switch (controller.liveCameraGateState.value) {
                          case CameraGateState.valid:
                            text = '🟢 Confirm';
                            color = AppColors.cyan;
                          case CameraGateState.tooFar:
                            text = '🔴 Too far';
                            color = Colors.redAccent;
                          case CameraGateState.noPerson:
                            text = '🔴 No user';
                            color = Colors.redAccent;
                          case CameraGateState.notReady:
                          case CameraGateState.notRequired:
                            text = '⚪ Starting';
                            color = AppColors.textMuted;
                        }
                        if (!isCamInit) {
                          text = '⚪ Unavail';
                          color = AppColors.textMuted;
                        }
                      } else if (!isCamInit || !isBodyVisibleInFrame) {
                        text = '⚪ Unavail';
                        color = AppColors.textMuted;
                      } else if (evalResult.isPunchConfirmed) {
                        text = '🟢 Confirm';
                        color = AppColors.cyan;
                      } else {
                        text = '🔴 Reject';
                        color = Colors.redAccent;
                      }

                      return Text(
                        text,
                        style: TextStyle(
                          color: color,
                          fontSize: 8.ts(context),
                          fontWeight: FontWeight.w700,
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
