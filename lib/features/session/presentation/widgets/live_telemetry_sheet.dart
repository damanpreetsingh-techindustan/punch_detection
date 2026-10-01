import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/utils/size_box.dart';
import 'audio_spike_waveform_painter.dart';
export 'audio_spike_waveform_painter.dart';
import '../../../../core/services/device_stability/device_stability_models.dart';
import '../../../vision_detection/domain/entities/temporal_punch_detector.dart';

/// Shows a live bottom sheet displaying real-time feature signal scores.
void showLiveTelemetryBottomSheet(
  BuildContext context, {
  required Rx<TemporalPunchEvaluationResult?> liveEvaluationResult,
  required VoidCallback onOpenSettings,
  RxBool? isArmExtensionEnabled,
  Rx<DeviceStabilityMetrics>? deviceStabilityMetrics,
  RxBool? isDeviceStabilityEnabled,
  Function(bool)? onToggleDeviceStability,
  RxBool? isExtraFaceRestrictionsEnabled,
  Function(bool)? onToggleExtraFaceRestrictions,
  RxDouble? minShoulderMovementThreshold,
  Function(double)? onChangedShoulderThreshold,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.panel,
    isScrollControlled: true,
    useSafeArea: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (context) {
      final isLandscape =
          MediaQuery.of(context).orientation == Orientation.landscape;
      final double sheetHeight =
          MediaQuery.of(context).size.height * (isLandscape ? 0.95 : 0.85);

      return Container(
        height: sheetHeight,
        padding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: isLandscape ? 6.h : 12.h,
        ),
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: isLandscape ? 4.h : 10.h),

            // Sheet Title Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      color: AppColors.blue,
                      size: isLandscape ? 16.w : 20.w,
                    ),
                    8.width,
                    Text(
                      'Live Feature Signals 📊',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: isLandscape ? 13.ts(context) : 15.ts(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.close,
                    color: AppColors.textMuted,
                    size: isLandscape ? 18.w : 20.w,
                  ),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            SizedBox(height: isLandscape ? 2.h : 4.h),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Real-time point breakdown calculated frame-by-frame by the AI engine.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: isLandscape ? 8.5.ts(context) : 9.5.ts(context),
                ),
              ),
            ),
            SizedBox(height: isLandscape ? 6.h : 12.h),
            Divider(color: AppColors.border, height: 1.h),
            SizedBox(height: isLandscape ? 6.h : 12.h),

            // Live Content
            Expanded(
              child: Obx(() {
                final result = liveEvaluationResult.value;
                if (result == null) {
                  return Center(
                    child: Text(
                      'Waiting for camera pose stream…',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.ts(context),
                      ),
                    ),
                  );
                }

                final bd = result.signalBreakdown;
                final totalScore = result.confidenceScore;
                final fsmState = result.fsmState;
                final activeArm = bd.activeArm.toUpperCase();
                final debugTelemetry = result.debugTelemetry;

                Color scoreColor = AppColors.textMuted;
                if (totalScore >= 75) {
                  scoreColor = AppColors.lime;
                } else if (totalScore >= 35) {
                  scoreColor = AppColors.blue;
                }

                const double shoulderMaxPoints = 85.0;

                return ListView(
                  children: [
                    // Total Score Header Banner
                    Container(
                      padding: EdgeInsets.all(isLandscape ? 8.r : 12.r),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: scoreColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PUNCH CONFIDENCE SCORE',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 8.5.ts(context),
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  2.height,
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '${totalScore.round()}',
                                        style: TextStyle(
                                          color: scoreColor,
                                          fontSize: isLandscape
                                              ? 20.ts(context)
                                              : 24.ts(context),
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        ' / 100 PTS',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11.ts(context),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              // FSM State Badge
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 5.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.panel,
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(color: scoreColor),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      fsmState.name.toUpperCase(),
                                      style: TextStyle(
                                        color: scoreColor,
                                        fontSize: 9.ts(context),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      '$activeArm ARM DRIVER',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 7.5.ts(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          6.height,
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4.r),
                            child: LinearProgressIndicator(
                              value: (totalScore / 100.0).clamp(0.0, 1.0),
                              backgroundColor: AppColors.border,
                              color: scoreColor,
                              minHeight: 5.h,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isLandscape ? 8.h : 14.h),

                    // Min Shoulder Movement Threshold Live Tune Card & Slider
                    if (minShoulderMovementThreshold != null &&
                        onChangedShoulderThreshold != null)
                      Obx(() {
                        final currentThresh =
                            minShoulderMovementThreshold.value;
                        final currentDisp = bd.rawShoulderMovement;
                        final bool isGateActive = currentDisp >= currentThresh;

                        return Container(
                          margin: EdgeInsets.only(bottom: 10.h),
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            color: AppColors.panel2,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: isGateActive
                                  ? AppColors.lime.withValues(alpha: 0.8)
                                  : AppColors.border,
                              width: isGateActive ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.fitness_center,
                                        color: AppColors.lime,
                                        size: 15.w,
                                      ),
                                      6.width,
                                      Text(
                                        'Min Shoulder Movement Gate (SW)',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 10.5.ts(context),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 2.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.lime.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(8.r),
                                      border: Border.all(color: AppColors.lime),
                                    ),
                                    child: Text(
                                      '${currentThresh.toStringAsFixed(3)} SW (${(currentThresh * 100).toStringAsFixed(1)}% SW)',
                                      style: TextStyle(
                                        color: AppColors.lime,
                                        fontSize: 10.ts(context),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              4.height,
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Live Shoulder Disp: ${currentDisp.toStringAsFixed(3)} SW',
                                    style: TextStyle(
                                      color: isGateActive
                                          ? AppColors.lime
                                          : AppColors.textMuted,
                                      fontSize: 8.5.ts(context),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    isGateActive
                                        ? '⚡ GATE PASSED (Active Motion)'
                                        : '🚫 BELOW GATE (No Punch)',
                                    style: TextStyle(
                                      color: isGateActive
                                          ? AppColors.lime
                                          : AppColors.textMuted,
                                      fontSize: 8.ts(context),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              Slider(
                                value: currentThresh.clamp(0.015, 0.080),
                                min: 0.015,
                                max: 0.080,
                                divisions: 65,
                                activeColor: AppColors.lime,
                                inactiveColor: AppColors.border,
                                label: '${currentThresh.toStringAsFixed(3)} SW',
                                onChanged: onChangedShoulderThreshold,
                              ),
                            ],
                          ),
                        );
                      }),

                    // Live Process Telemetry Debug Card
                    Container(
                      padding: EdgeInsets.all(10.r),
                      margin: EdgeInsets.only(bottom: 10.h),
                      decoration: BoxDecoration(
                        color: AppColors.panel2,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.developer_mode,
                                color: AppColors.blue,
                                size: 14.w,
                              ),
                              6.width,
                              Text(
                                'LIVE ENGINE PROCESS STATUS',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 9.5.ts(context),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                          4.height,
                          Text(
                            debugTelemetry,
                            style: TextStyle(
                              color: AppColors.lime,
                              fontSize: 8.5.ts(context),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),

                    Text(
                      'FEATURE SIGNALS BREAKDOWN',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9.ts(context),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: isLandscape ? 4.h : 8.h),

                    // 1. Pose Validity & Camera Alignment (Max 10 Pts)
                    _buildSignalTile(
                      context,
                      title: '👤 Pose Validity Gate (Nose & Shoulders)',
                      score: bd.scoreValidity,
                      maxPoints: 10.0,
                      rawText:
                          'Nose & Shoulder landmarks present (Facing Camera)',
                      color: const Color(0xFF00E676),
                    ),

                    // 2. Shoulder Movement & Drive (Max 55 Pts)
                    _buildSignalTile(
                      context,
                      title: '🔄 Shoulder Movement & Drive (Primary)',
                      score: bd.scoreShoulder,
                      maxPoints: shoulderMaxPoints,
                      rawText:
                          'Disp: ${bd.rawShoulderMovement.toStringAsFixed(3)} SW (Min: ${(minShoulderMovementThreshold?.value ?? 0.035).toStringAsFixed(3)} SW)',
                      color: AppColors.lime,
                      isDominant: true,
                    ),

                    // 3. Temporal History Buffer (Max 5 Pts)
                    _buildSignalTile(
                      context,
                      title: '⏱️ Temporal History Buffer',
                      score: bd.scoreTemporal,
                      maxPoints: 5.0,
                      rawText: 'Consecutive pose history',
                      color: AppColors.textPrimary,
                    ),

                    if (deviceStabilityMetrics != null)
                      Obx(() {
                        final metrics = deviceStabilityMetrics.value;
                        final isEnabled =
                            isDeviceStabilityEnabled?.value ??
                            AppConstants.enableDeviceStabilityCheck;
                        return _buildDeviceStabilityTelemetryCard(
                          context,
                          metrics: metrics,
                          isEnabled: isEnabled,
                          onToggle: onToggleDeviceStability,
                        );
                      }),
                  ],
                );
              }),
            ),

            SizedBox(height: isLandscape ? 6.h : 10.h),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, isLandscape ? 34.h : 42.h),
                side: const BorderSide(color: AppColors.lime, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              onPressed: () {
                Get.back();
                onOpenSettings();
              },
              icon: Icon(
                Icons.tune,
                color: AppColors.lime,
                size: isLandscape ? 15.w : 18.w,
              ),
              label: Text(
                'Tune Threshold Sliders ⚙️',
                style: TextStyle(
                  color: AppColors.lime,
                  fontSize: isLandscape ? 10.ts(context) : 11.5.ts(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: isLandscape ? 6.h : 16.h),
          ],
        ),
      );
    },
  );
}

Widget _buildSignalTile(
  BuildContext context, {
  required String title,
  required double score,
  required double maxPoints,
  required String rawText,
  required Color color,
  bool isDominant = false,
}) {
  final double ratio = maxPoints > 0
      ? (score / maxPoints).clamp(0.0, 1.0)
      : 0.0;

  return Container(
    margin: EdgeInsets.only(bottom: 8.h),
    padding: EdgeInsets.all(10.r),
    decoration: BoxDecoration(
      color: isDominant
          ? color.withValues(alpha: 0.12)
          : AppColors.surface.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10.r),
      border: Border.all(
        color: isDominant ? color : AppColors.border.withValues(alpha: 0.5),
        width: isDominant ? 1.2 : 1.0,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11.ts(context),
                  fontWeight: isDominant ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  score.toStringAsFixed(1),
                  style: TextStyle(
                    color: color,
                    fontSize: 12.ts(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  ' / ${maxPoints.round()} pts',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9.5.ts(context),
                  ),
                ),
              ],
            ),
          ],
        ),
        3.height,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              rawText,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 8.5.ts(context),
              ),
            ),
            Text(
              '${(ratio * 100).round()}%',
              style: TextStyle(
                color: color,
                fontSize: 8.5.ts(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        4.height,
        ClipRRect(
          borderRadius: BorderRadius.circular(3.r),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: AppColors.border.withValues(alpha: 0.5),
            color: color,
            minHeight: 4.h,
          ),
        ),
      ],
    ),
  );
}

/// Shows a dedicated live bottom sheet displaying real-time audio microphone telemetry & decibel signals.
void showAudioTelemetryBottomSheet(
  BuildContext context, {
  required RxDouble liveDecibelLevel,
  RxList<double>? decibelHistory,
  RxList<String>? recordedSpikesHistory,
  required RxInt audioConfidence,
  required RxDouble minPunchAudioDb,
  required RxDouble minAudioPunchSpikeDb,
  required RxString detectionStatusText,
  required VoidCallback onOpenSettings,
  Rx<DeviceStabilityMetrics>? deviceStabilityMetrics,
  RxBool? isDeviceStabilityEnabled,
  Function(bool)? onToggleDeviceStability,
  RxBool? isVibrationGateEnabled,
  Function(bool)? onToggleVibrationGate,
  RxDouble? minVibrationThreshold,
  Function(double)? onChangedVibrationThreshold,
  RxDouble? liveVibrationMagnitude,
  RxBool? isVibrationDisabled,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.panel,
    isScrollControlled: true,
    useSafeArea: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (context) {
      final isLandscape =
          MediaQuery.of(context).orientation == Orientation.landscape;
      final double sheetHeight =
          MediaQuery.of(context).size.height * (isLandscape ? 0.95 : 0.68);

      return Container(
        height: sheetHeight,
        padding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: isLandscape ? 6.h : 12.h,
        ),
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: isLandscape ? 4.h : 10.h),

            // Sheet Title Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.mic_external_on_outlined,
                      color: AppColors.amber,
                      size: isLandscape ? 16.w : 20.w,
                    ),
                    8.width,
                    Text(
                      'Audio Mic Telemetry 🎙️',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: isLandscape ? 13.ts(context) : 15.ts(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.close,
                    color: AppColors.textMuted,
                    size: isLandscape ? 18.w : 20.w,
                  ),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            SizedBox(height: isLandscape ? 2.h : 4.h),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Real-time microphone input volume, impact spike, and noise threshold monitoring.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: isLandscape ? 8.5.ts(context) : 9.5.ts(context),
                ),
              ),
            ),
            SizedBox(height: isLandscape ? 6.h : 12.h),
            Divider(color: AppColors.border, height: 1.h),
            SizedBox(height: isLandscape ? 6.h : 12.h),

            // Live Content
            Expanded(
              child: Obx(() {
                final db = liveDecibelLevel.value;
                final confidence = audioConfidence.value;
                final thresholdDb = minPunchAudioDb.value;
                final spikeDb = minAudioPunchSpikeDb.value;
                final status = detectionStatusText.value;
                final bool isImpactPass = db >= thresholdDb;

                return ListView(
                  children: [
                    // Main Decibel Gauge Display Card
                    Container(
                      padding: EdgeInsets.all(isLandscape ? 10.r : 16.r),
                      decoration: BoxDecoration(
                        color: AppColors.panel2,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: isImpactPass
                              ? AppColors.amber.withValues(alpha: 0.8)
                              : AppColors.border,
                          width: isImpactPass ? 1.8 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'LIVE MIC LEVEL',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 10.ts(context),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  4.height,
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '${db.round()}',
                                        style: TextStyle(
                                          color: isImpactPass
                                              ? AppColors.amber
                                              : AppColors.textPrimary,
                                          fontSize: isLandscape
                                              ? 24.ts(context)
                                              : 32.ts(context),
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      4.width,
                                      Text(
                                        'dB',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 13.ts(context),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 8.h,
                                ),
                                decoration: BoxDecoration(
                                  color: isImpactPass
                                      ? AppColors.amber.withValues(alpha: 0.15)
                                      : AppColors.panel,
                                  borderRadius: BorderRadius.circular(20.r),
                                  border: Border.all(
                                    color: isImpactPass
                                        ? AppColors.amber
                                        : AppColors.border,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '$confidence%',
                                      style: TextStyle(
                                        color: isImpactPass
                                            ? AppColors.amber
                                            : AppColors.textMuted,
                                        fontSize: isLandscape
                                            ? 14.ts(context)
                                            : 18.ts(context),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      'Confidence',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 8.5.ts(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isLandscape ? 8.h : 14.h),
                          // Animated Decibel Progress Meter
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6.r),
                            child: LinearProgressIndicator(
                              value: (db / 120.0).clamp(0.0, 1.0),
                              minHeight: isLandscape ? 6.h : 10.h,
                              backgroundColor: AppColors.panel,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isImpactPass ? AppColors.amber : AppColors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isLandscape ? 8.h : 14.h),

                    // Live Audio Spike Waveform Graph Card
                    _buildLiveAudioSpikeGraphCard(
                      context,
                      decibelSamples: decibelHistory?.toList() ?? [],
                      thresholdDb: thresholdDb,
                      isLandscape: isLandscape,
                    ),
                    SizedBox(height: isLandscape ? 8.h : 14.h),

                    // Audio Threshold Metrics Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildAudioMetricCard(
                            context,
                            title: 'PUNCH THRESHOLD',
                            value: '${thresholdDb.round()} dB',
                            subtitle: db >= thresholdDb
                                ? 'GATE PASSED'
                                : 'BELOW GATE',
                            icon: Icons.tune,
                            isPassed: db >= thresholdDb,
                            color: AppColors.amber,
                          ),
                        ),
                        10.width,
                        Expanded(
                          child: _buildAudioMetricCard(
                            context,
                            title: 'ONSET SPIKE MIN',
                            value: '+${spikeDb.toStringAsFixed(1)} dB',
                            subtitle: 'Impact Spike',
                            icon: Icons.bolt,
                            isPassed: true,
                            color: AppColors.lime,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isLandscape ? 8.h : 14.h),

                    // Physical Device Impact Vibration Gate Card
                    if (isVibrationGateEnabled != null &&
                        onToggleVibrationGate != null)
                      Obx(
                        () => _buildDeviceVibrationTelemetryCard(
                          context,
                          isEnabled: isVibrationGateEnabled.value,
                          onToggle: onToggleVibrationGate,
                          minThreshold: minVibrationThreshold,
                          onChangedThreshold: onChangedVibrationThreshold,
                          liveMagnitude: liveVibrationMagnitude,
                          isVibrationDisabled: isVibrationDisabled,
                        ),
                      ),
                    SizedBox(height: isLandscape ? 8.h : 14.h),



                    // Live Detection Engine Status Card
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: AppColors.panel2,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.graphic_eq,
                            color: AppColors.amber,
                            size: 18.w,
                          ),
                          10.width,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AUDIO ENGINE STATUS',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 8.5.ts(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                2.height,
                                Text(
                                  status,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 11.ts(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (deviceStabilityMetrics != null)
                      Obx(() {
                        final metrics = deviceStabilityMetrics.value;
                        final isEnabled =
                            isDeviceStabilityEnabled?.value ??
                            AppConstants.enableDeviceStabilityCheck;
                        return _buildDeviceStabilityTelemetryCard(
                          context,
                          metrics: metrics,
                          isEnabled: isEnabled,
                          onToggle: onToggleDeviceStability,
                        );
                      }),
                  ],
                );
              }),
            ),

            SizedBox(height: isLandscape ? 6.h : 10.h),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, isLandscape ? 34.h : 42.h),
                side: const BorderSide(color: AppColors.amber, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              onPressed: () {
                Get.back();
                onOpenSettings();
              },
              icon: Icon(
                Icons.tune,
                color: AppColors.amber,
                size: isLandscape ? 15.w : 18.w,
              ),
              label: Text(
                'Tune Audio Thresholds ⚙️',
                style: TextStyle(
                  color: AppColors.amber,
                  fontSize: isLandscape ? 10.ts(context) : 11.5.ts(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: isLandscape ? 6.h : 16.h),
          ],
        ),
      );
    },
  );
}

Widget _buildAudioMetricCard(
  BuildContext context, {
  required String title,
  required String value,
  required String subtitle,
  required IconData icon,
  required bool isPassed,
  required Color color,
}) {
  return Container(
    padding: EdgeInsets.all(12.r),
    decoration: BoxDecoration(
      color: AppColors.panel2,
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 8.5.ts(context),
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
            ),
            Icon(icon, color: color, size: 14.w),
          ],
        ),
        6.height,
        Text(
          value,
          style: TextStyle(
            color: isPassed ? color : AppColors.textMuted,
            fontSize: 18.ts(context),
            fontWeight: FontWeight.w900,
          ),
        ),
        2.height,
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 8.5.ts(context),
          ),
        ),
      ],
    ),
  );
}

/// Helper tile widget to display real-time Device Stability & Motion sensor metrics
Widget _buildDeviceStabilityTelemetryCard(
  BuildContext context, {
  required DeviceStabilityMetrics metrics,
  required bool isEnabled,
  required Function(bool)? onToggle,
}) {
  final state = metrics.state;
  Color stateColor = AppColors.lime;
  Color borderColor = AppColors.lime.withValues(alpha: 0.5);
  Color bgColor = AppColors.lime.withValues(alpha: 0.12);

  if (!isEnabled) {
    stateColor = AppColors.textMuted;
    borderColor = AppColors.border;
    bgColor = AppColors.panel2;
  } else if (state == DeviceStabilityState.unstableHandheld) {
    stateColor = AppColors.red;
    borderColor = AppColors.red.withValues(alpha: 0.6);
    bgColor = AppColors.red.withValues(alpha: 0.15);
  } else if (state == DeviceStabilityState.minorVibration) {
    stateColor = AppColors.amber;
    borderColor = AppColors.amber.withValues(alpha: 0.5);
    bgColor = AppColors.amber.withValues(alpha: 0.12);
  }

  return Container(
    margin: EdgeInsets.only(top: 10.h),
    padding: EdgeInsets.all(12.r),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: borderColor, width: 1.2.w),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.sensors, color: stateColor, size: 18.w),
                  8.width,
                  Text(
                    'DEVICE STABILITY & MOTION',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 10.ts(context),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            if (onToggle != null)
              Switch(
                value: isEnabled,
                activeThumbColor: AppColors.lime,
                onChanged: onToggle,
              ),
          ],
        ),
        2.height,
        Text(
          metrics.statusMessage,
          style: TextStyle(
            color: stateColor,
            fontSize: 10.5.ts(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        if (isEnabled) ...[
          6.height,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Linear Accel: ${metrics.smoothedLinearAccel.toStringAsFixed(2)} m/s²',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9.ts(context),
                ),
              ),
              Text(
                'Gyro: ${metrics.smoothedAngularVel.toStringAsFixed(2)} rad/s',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9.ts(context),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

/// Helper card to configure & monitor Physical Device Impact Vibration Gate
Widget _buildDeviceVibrationTelemetryCard(
  BuildContext context, {
  required bool isEnabled,
  required Function(bool) onToggle,
  RxDouble? minThreshold,
  Function(double)? onChangedThreshold,
  RxDouble? liveMagnitude,
  RxBool? isVibrationDisabled,
}) {
  final bool disabled = isVibrationDisabled?.value ?? false;

  return Container(
    padding: EdgeInsets.all(12.r),
    decoration: BoxDecoration(
      color: const Color(0xFF030712),
      borderRadius: BorderRadius.circular(14.r),
      border: Border.all(
        color: disabled
            ? AppColors.border
            : (isEnabled
                ? const Color(0xFF8B5CF6).withValues(alpha: 0.6)
                : AppColors.border),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.vibration,
                  color: disabled
                      ? AppColors.textMuted
                      : (isEnabled
                          ? const Color(0xFFA78BFA)
                          : AppColors.textMuted),
                  size: 16.w,
                ),
                6.width,
                Text(
                  'PHYSICAL VIBRATION GATE 📳',
                  style: TextStyle(
                    color: disabled ? AppColors.textMuted : AppColors.textPrimary,
                    fontSize: 10.ts(context),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
                if (disabled) ...[
                  6.width,
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: AppColors.amber.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      'DISABLED',
                      style: TextStyle(
                        color: AppColors.amber,
                        fontSize: 8.ts(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Opacity(
              opacity: disabled ? 0.4 : 1.0,
              child: IgnorePointer(
                ignoring: disabled,
                child: Switch(
                  value: disabled ? false : isEnabled,
                  onChanged: onToggle,
                  activeThumbColor: const Color(0xFFA78BFA),
                  activeTrackColor: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
        if (disabled) ...[
          6.height,
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.portable_wifi_off,
                  color: AppColors.amber,
                  size: 14.w,
                ),
                6.width,
                Expanded(
                  child: Text(
                    'Phone is in Pole Mount or Vibration-Off mode. Impact detection relies on Audio + Camera.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 8.5.ts(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (isEnabled) ...[
          6.height,
          Text(
            'Rejects vocal shouts unless physical impact vibration is sensed on phone/mount.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 9.ts(context),
            ),
          ),
          8.height,
          if (liveMagnitude != null)
            Obx(() {
              final mag = liveMagnitude.value;
              final thresh = minThreshold?.value ?? 0.35;
              final isVibrating = mag >= thresh;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sensors Acceleration: ${mag.toStringAsFixed(2)} m/s²',
                    style: TextStyle(
                      color: isVibrating
                          ? const Color(0xFFA78BFA)
                          : AppColors.textMuted,
                      fontSize: 9.5.ts(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: isVibrating
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                          : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(4.r),
                      border: Border.all(
                        color: isVibrating
                            ? const Color(0xFFA78BFA)
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      isVibrating ? '📳 VIBRATION SENSED' : 'IDLE',
                      style: TextStyle(
                        color: isVibrating
                            ? const Color(0xFFDDD6FE)
                            : AppColors.textMuted,
                        fontSize: 8.ts(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              );
            }),
          if (minThreshold != null && onChangedThreshold != null) ...[
            8.height,
            Obx(
              () => Row(
                children: [
                  Text(
                    'Impact Threshold: ${minThreshold.value.toStringAsFixed(2)} m/s²',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9.ts(context),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: minThreshold.value.clamp(0.15, 1.0),
                      min: 0.15,
                      max: 1.0,
                      divisions: 17,
                      activeColor: const Color(0xFFA78BFA),
                      onChanged: onChangedThreshold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    ),
  );
}



/// Widget to display real-time rolling audio decibel spike graph matching user reference image
Widget _buildLiveAudioSpikeGraphCard(
  BuildContext context, {
  required List<double> decibelSamples,
  required double thresholdDb,
  required bool isLandscape,
}) {
  final double currentMax = decibelSamples.isEmpty
      ? 0.0
      : decibelSamples.reduce(max);
  final double latestDb = decibelSamples.isEmpty ? 0.0 : decibelSamples.last;
  final bool hasActiveSpike = decibelSamples.any((db) => db >= thresholdDb);

  return Container(
    padding: EdgeInsets.all(12.r),
    decoration: BoxDecoration(
      color: const Color(0xFF030712), // Deep pitch black from image
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(
        color: hasActiveSpike
            ? const Color(0xFF3B82F6).withValues(alpha: 0.8)
            : AppColors.border,
        width: hasActiveSpike ? 1.5 : 1.0,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.show_chart,
                    color: const Color(0xFF3B82F6),
                    size: 16.w,
                  ),
                  6.width,
                  Flexible(
                    child: Text(
                      'LIVE AUDIO WAVE 📈',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 10.ts(context),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            4.width,
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasActiveSpike) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 5.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4.r),
                        border: Border.all(color: const Color(0xFF3B82F6)),
                      ),
                      child: Text(
                        '⚡ SPIKE',
                        style: TextStyle(
                          color: const Color(0xFF60A5FA),
                          fontSize: 8.ts(context),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    4.width,
                  ],
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '${latestDb.round()} dB | Peak: ${currentMax.round()}dB',
                        style: TextStyle(
                          color: const Color(0xFF60A5FA),
                          fontSize: 8.5.ts(context),
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        8.height,
        SizedBox(
          height: isLandscape ? 70.h : 95.h,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: CustomPaint(
              painter: AudioSpikeWaveformPainter(
                decibelSamples: decibelSamples,
                thresholdDb: thresholdDb,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

