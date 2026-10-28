import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/common_function.dart';
import '../../../../core/utils/size_box.dart';

class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionResultModel result = SessionResultModel.fromArguments(
      Get.arguments,
    );

    final int totalPunches = result.totalPunches;
    final int accuracy = result.accuracyPercentage.round();
    final String grade = result.grade;
    final String modeLabel = result.formattedSessionModeLabel;
    final String typeLabel = result.formattedSessionTypeLabel;
    final String durationStr = result.formattedDuration;
    final bool isLandscape = CommonFunction.checkOrientationLandscape(context);

    // final String signalSummary =
    //     'Session completed in $modeLabel mode ($durationStr). Successfully confirmed $totalPunches punch(es) (${result.leftPunches} Left / ${result.rightPunches} Right) with $accuracy% signal accuracy and ${result.peakAudioDb.round()} dB peak impact.';


    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          child: isLandscape
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Side Column (Completion Badge, Score Card & Button)
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            Container(
                              width: 50.r,
                              height: 50.r,
                              decoration: const BoxDecoration(
                                color: AppColors.cyan,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '✓',
                                  style: TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 22.ts(context),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            8.height,
                            Text(
                              'Workout Complete!',
                              style: AppTextStyles.heading2(
                                context,
                              ).copyWith(fontSize: 18.ts(context)),
                            ),
                            2.height,
                            Text(
                              '$typeLabel · $modeLabel',
                              style: AppTextStyles.bodyMedium(context),
                            ),
                            12.height,

                            // Score Card
                            Container(
                              padding: EdgeInsets.all(14.r),
                              decoration: BoxDecoration(
                                color: AppColors.panel,
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'PUNCH ACCURACY',
                                        style: AppTextStyles.tag(context),
                                      ),
                                      4.height,
                                      Text(
                                        '$accuracy%',
                                        style: AppTextStyles.heading1(context)
                                            .copyWith(
                                              fontSize: 32.ts(context),
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 54.r,
                                    height: 54.r,
                                    decoration: const BoxDecoration(
                                      color: AppColors.panel2,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        grade,
                                        style: TextStyle(
                                          color: AppColors.cyan,
                                          fontSize: 20.ts(context),
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            16.height,

                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: AppColors.panel,
                                side: const BorderSide(color: AppColors.border),
                                minimumSize: Size(double.infinity, 44.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                              ),
                              onPressed: AppNavigator.toHome,
                              child: Text(
                                'Back to Hyper Hitter',
                                style: AppTextStyles.buttonLabel(context)
                                    .copyWith(
                                      color: AppColors.textPrimary,
                                      fontSize: 13.ts(context),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    16.width,

                    // Right Side Column (Metrics, Summary & Benchmark Cards)
                    Expanded(
                      flex: 7,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // Metrics Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetric(
                                    context,
                                    '$totalPunches',
                                    'PUNCHES (L:${result.leftPunches}/R:${result.rightPunches})',
                                  ),
                                ),
                                6.width,
                                Expanded(
                                  child: _buildMetric(
                                    context,
                                    result.sessionType == 'prompt'
                                        ? '${result.averageReactionTimeMs.round()} ms'
                                        : durationStr,
                                    result.sessionType == 'prompt'
                                        ? 'REACTION'
                                        : 'WORKOUT TIME',
                                  ),
                                ),
                                6.width,
                                Expanded(
                                  child: _buildMetric(
                                    context,
                                    '${result.averageLatencyMs.round()} ms',
                                    'AVG LATENCY',
                                  ),
                                ),
                              ],
                            ),
                            10.height,
                            /*
                            // Signal Fusion Summary Card
                            Container(
                              padding: EdgeInsets.all(12.r),
                              decoration: BoxDecoration(
                                color: const Color(0xFF121D0F),
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(
                                  color: const Color(0xFF354D19),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SIGNAL FUSION SUMMARY',
                                    style: AppTextStyles.tag(context),
                                  ),
                                  6.height,
                                  Text(
                                    signalSummary,
                                    style: AppTextStyles.bodyMedium(context)
                                        .copyWith(
                                          color: AppColors.textPrimary,
                                          fontSize: 11.ts(context),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            10.height,
                            */
                            // Environment Benchmark
                            Container(
                              padding: EdgeInsets.all(12.r),
                              decoration: BoxDecoration(
                                color: AppColors.panel,
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ENVIRONMENT BENCHMARK',
                                    style: AppTextStyles.tag(context),
                                  ),
                                  8.height,
                                  _buildRow(
                                    context,
                                    'Target Benchmark',
                                    '80–88%',
                                  ),
                                  Divider(
                                    color: AppColors.border,
                                    height: 12.h,
                                  ),
                                  _buildRow(
                                    context,
                                    'This Session Accuracy',
                                    '$accuracy%',
                                    color: AppColors.lime,
                                  ),
                                  Divider(
                                    color: AppColors.border,
                                    height: 12.h,
                                  ),
                                  _buildRow(
                                    context,
                                    'Peak Impact Volume',
                                    '${result.peakAudioDb.round()} dB',
                                    color: AppColors.cyan,
                                  ),
                                  Divider(
                                    color: AppColors.border,
                                    height: 12.h,
                                  ),
                                  _buildRow(context, 'Mode Active', modeLabel),
                                ],
                              ),
                            ),
                            10.height,

                            // Recorded Punch Spikes History Card
                            _buildRecordedSpikesCard(context, result),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      24.height,
                      Container(
                        width: 66.r,
                        height: 66.r,
                        decoration: const BoxDecoration(
                          color: AppColors.cyan,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '✓',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 26.ts(context),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      14.height,
                      Text(
                        'Workout Complete!',
                        style: AppTextStyles.heading2(context),
                      ),
                      4.height,
                      Text(
                        '$typeLabel · $modeLabel',
                        style: AppTextStyles.bodyMedium(context),
                      ),

                      20.height,

                      // Score Card
                      Container(
                        padding: EdgeInsets.all(18.r),
                        decoration: BoxDecoration(
                          color: AppColors.panel,
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PUNCH DETECTION ACCURACY',
                                  style: AppTextStyles.tag(context),
                                ),
                                4.height,
                                Text(
                                  '$accuracy%',
                                  style: AppTextStyles.heading1(context)
                                      .copyWith(
                                        fontSize: 40.ts(context),
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ],
                            ),
                            Container(
                              width: 70.r,
                              height: 70.r,
                              decoration: const BoxDecoration(
                                color: AppColors.panel2,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  grade,
                                  style: TextStyle(
                                    color: AppColors.cyan,
                                    fontSize: 24.ts(context),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      12.height,

                      // Metrics Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetric(
                              context,
                              '$totalPunches',
                              'PUNCHES (L:${result.leftPunches}/R:${result.rightPunches})',
                            ),
                          ),
                          8.width,
                          Expanded(
                            child: _buildMetric(
                              context,
                              result.sessionType == 'prompt'
                                  ? '${result.averageReactionTimeMs.round()} ms'
                                  : durationStr,
                              result.sessionType == 'prompt'
                                  ? 'REACTION'
                                  : 'WORKOUT TIME',
                            ),
                          ),
                          8.width,
                          Expanded(
                            child: _buildMetric(
                              context,
                              '${result.averageLatencyMs.round()} ms',
                              'AVG LATENCY',
                            ),
                          ),
                        ],
                      ),

                      12.height,
                      /*
                      // Signal Fusion Summary Card
                      Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121D0F),
                          borderRadius: BorderRadius.circular(18.r),
                          border: Border.all(color: const Color(0xFF354D19)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SIGNAL FUSION SUMMARY',
                              style: AppTextStyles.tag(context),
                            ),
                            8.height,
                            Text(
                              signalSummary,
                              style: AppTextStyles.bodyMedium(context).copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 13.ts(context),
                              ),
                            ),
                          ],
                        ),
                      ),

                      12.height,
    */
                      // Environment Benchmark
                      Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: AppColors.panel,
                          borderRadius: BorderRadius.circular(18.r),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ENVIRONMENT BENCHMARK',
                              style: AppTextStyles.tag(context),
                            ),
                            12.height,
                            _buildRow(context, 'Target Benchmark', '80–88%'),
                            Divider(color: AppColors.border, height: 16.h),
                            _buildRow(
                              context,
                              'This Session Accuracy',
                              '$accuracy%',
                              color: AppColors.lime,
                            ),
                            Divider(color: AppColors.border, height: 16.h),
                            _buildRow(
                              context,
                              'Peak Impact Volume',
                              '${result.peakAudioDb.round()} dB',
                              color: AppColors.cyan,
                            ),
                            Divider(color: AppColors.border, height: 16.h),
                            _buildRow(context, 'Mode Active', modeLabel),
                          ],
                        ),
                      ),

                      12.height,

                      // Recorded Punch Spikes History Card
                      _buildRecordedSpikesCard(context, result),

                      24.height,

                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.panel,
                          side: const BorderSide(color: AppColors.border),
                          minimumSize: Size(double.infinity, 54.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        onPressed: AppNavigator.toHome,
                        child: Text(
                          'Back to Hyper Hitter',
                          style: AppTextStyles.buttonLabel(
                            context,
                          ).copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                      24.height,
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildMetric(BuildContext context, String value, String label) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 6.w),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.heading3(
              context,
            ).copyWith(fontSize: 16.ts(context)),
          ),
          2.height,
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8.5.ts(context),
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    String label,
    String value, {
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5.ts(context),
            color: AppColors.textMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5.ts(context),
            fontWeight: FontWeight.w900,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Future<void> _exportAndShareSessionLogs(
    BuildContext context,
    SessionResultModel result,
  ) async {
    try {
      final double ppm = result.durationSeconds > 0
          ? (result.totalPunches / (result.durationSeconds / 60.0))
          : 0.0;

      final StringBuffer buffer = StringBuffer();
      buffer.writeln('====================================================');
      buffer.writeln('          HYPER HITTER - PUNCH LOG EXPORT           ');
      buffer.writeln('====================================================');
      buffer.writeln(
        'Session Type         : ${result.formattedSessionTypeLabel}',
      );
      buffer.writeln(
        'Session Mode         : ${result.formattedSessionModeLabel}',
      );
      buffer.writeln(
        'Export Date          : ${DateTime.now().toLocal().toString()}',
      );
      buffer.writeln('Total Punches        : ${result.totalPunches}');
      buffer.writeln(
        'Left / Right Splits  : ${result.leftPunches} Left | ${result.rightPunches} Right',
      );
      buffer.writeln('Duration             : ${result.formattedDuration}');
      buffer.writeln('Cadence              : ${ppm.toStringAsFixed(1)} PPM');
      buffer.writeln('Peak Audio Recorded  : ${result.peakAudioDb.round()} dB');
      buffer.writeln('====================================================');
      buffer.writeln('  SESSION DETECTION CALIBRATION & SENSOR SETTINGS   ');
      buffer.writeln('====================================================');
      buffer.writeln(
        'Audio Capture Rate   : ${result.audioSampleIntervalMs} ms (~${(1000 / result.audioSampleIntervalMs).round()} Hz)',
      );
      buffer.writeln(
        'Direct Audio Target  : ${result.directAudioTargetDb.round()} dB (Min dB threshold to count)',
      );
      buffer.writeln(
        'Audio Spike Jump     : +${result.audioSpikeThresholdDb.round()} dB above ambient baseline',
      );
      buffer.writeln(
        'Ambient Baseline dB  : ${result.ambientBaselineDb.round()} dB',
      );
      buffer.writeln(
        'Vibration Threshold  : ${result.vibrationThreshold.toStringAsFixed(2)} m/s²',
      );
      buffer.writeln(
        'Vibration Gate       : ${result.isVibrationGateEnabled ? "ENABLED" : "DISABLED"}',
      );
      buffer.writeln(
        'Vision Confirmation  : ${result.isVisionConfirmationRequired ? "REQUIRED (Strict — must see punching motion)" : "OPTIONAL (Dual audio+vibe fallback enabled)"}',
      );
      if (result.sessionTotalsText.isNotEmpty) {
        buffer.writeln('====================================================');
        buffer.writeln('                SESSION TOTALS                      ');
        buffer.writeln('====================================================');
        buffer.write(result.sessionTotalsText);
      }
      // All confirmed punches (never trimmed); falls back to filtering the
      // spike history for sessions that did not record a dedicated list.
      final List<String> confirmedPunches = result.confirmedPunchLog.isNotEmpty
          ? result.confirmedPunchLog
          : result.recordedSpikesHistory
                .where(
                  (entry) => entry.contains('PUNCH') || entry.startsWith('🥊'),
                )
                .toList();

      buffer.writeln('====================================================');
      buffer.writeln(
        '       CONFIRMED PUNCHES LOG (${confirmedPunches.length} PUNCHES RECORDED, OLDEST FIRST)       ',
      );
      buffer.writeln('====================================================');
      if (confirmedPunches.isEmpty) {
        buffer.writeln('  No confirmed punches recorded in this session.');
      } else {
        for (int i = 0; i < confirmedPunches.length; i++) {
          final int index = i + 1;
          final String numStr = index.toString().padLeft(3, '0');
          buffer.writeln('#$numStr | ${confirmedPunches[i]}');
        }
      }
      buffer.writeln('====================================================');
      buffer.writeln(
        'RECORDED SPIKES LOG HISTORY (${result.recordedSpikesHistory.length} ENTRIES, NEWEST FIRST):',
      );
      buffer.writeln('====================================================');
      for (int i = 0; i < result.recordedSpikesHistory.length; i++) {
        final int index = i + 1;
        final String numStr = index.toString().padLeft(3, '0');
        buffer.writeln('#$numStr | ${result.recordedSpikesHistory[i]}');
      }
      if (result.summaryCsv.isNotEmpty) {
        buffer.writeln('====================================================');
        buffer.writeln('DECISION & CAMERA TABLE (CSV, OLDEST FIRST)');
        buffer.writeln('One row per punch decision (kind=IMPACT) and per camera');
        buffer.writeln('change (kind=CAMERA). Paste into Excel / Google Sheets.');
        buffer.writeln('====================================================');
        buffer.write(result.summaryCsv);
      }
      buffer.writeln('====================================================');
      buffer.writeln('End of Log File.');

      final String content = buffer.toString();

      // 1. Copy to Clipboard immediately as 100% reliable fallback
      await Clipboard.setData(ClipboardData(text: content));

      // 2. Write file to app temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String filePath =
          '${tempDir.path}/hyper_hitter_punch_log_$timestamp.txt';
      final File file = File(filePath);
      await file.writeAsString(content);

      // 3. Attempt native share sheet
      bool shareSuccess = false;
      try {
        final XFile xFile = XFile(filePath, mimeType: 'text/plain');
        final List<XFile> shareFiles = <XFile>[xFile];
        if (result.summaryCsv.isNotEmpty) {
          final String csvPath =
              '${tempDir.path}/hyper_hitter_summary_$timestamp.csv';
          await File(csvPath).writeAsString(result.summaryCsv);
          shareFiles.add(XFile(csvPath, mimeType: 'text/csv'));
        }
        final String? rawPath = result.rawEventFilePath;
        if (rawPath != null && await File(rawPath).exists()) {
          shareFiles.add(XFile(rawPath, mimeType: 'application/x-ndjson'));
        }
        await SharePlus.instance.share(
          ShareParams(
            files: shareFiles,
            text:
                'Hyper Hitter Workout Punch Log Export (.txt) — Total Punches: ${result.totalPunches}',
            subject: 'Hyper Hitter Punch Log Export',
          ),
        );
        shareSuccess = true;
      } catch (shareErr) {
        // Native plugin not linked in currently running binary until app rebuild
      }

      Get.snackbar(
        shareSuccess ? 'Log Exported & Shared' : 'Log Copied to Clipboard',
        shareSuccess
            ? 'Saved to file & copied to clipboard!'
            : 'Punch log copied to clipboard! (Rebuild app to enable native share sheet).',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.cyan,
        colorText: AppColors.background,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      Get.snackbar(
        'Export Error',
        'Could not export log file: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.red,
        colorText: Colors.white,
      );
    }
  }

  Widget _buildRecordedSpikesCard(
    BuildContext context,
    SessionResultModel result,
  ) {
    final List<String> spikesHistory = result.recordedSpikesHistory;
    if (spikesHistory.isEmpty) return const SizedBox();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
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
                    Icon(
                      Icons.history_toggle_off,
                      color: AppColors.cyan,
                      size: 16.w,
                    ),
                    6.width,
                    Expanded(
                      child: Text(
                        'PUNCH SPIKES LOG ⚡',
                        style: AppTextStyles.tag(context),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              8.width,
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  side: const BorderSide(color: AppColors.cyan),
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                onPressed: () => _exportAndShareSessionLogs(context, result),
                icon: Icon(Icons.share, color: AppColors.cyan, size: 14.w),
                label: Text(
                  'EXPORT .TXT',
                  style: TextStyle(
                    color: AppColors.cyan,
                    fontSize: 10.ts(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          8.height,

          // Configuration summary strip
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.panel2,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Wrap(
              spacing: 8.w,
              runSpacing: 6.h,
              children: [
                _buildConfigBadge(
                  context,
                  'Audio Rate',
                  '${result.audioSampleIntervalMs}ms',
                ),
                _buildConfigBadge(
                  context,
                  'Audio Target',
                  '${result.directAudioTargetDb.round()} dB',
                ),
                _buildConfigBadge(
                  context,
                  'Spike Jump',
                  '+${result.audioSpikeThresholdDb.round()} dB',
                ),
                _buildConfigBadge(
                  context,
                  'Vibration',
                  '${result.vibrationThreshold.toStringAsFixed(2)} m/s²',
                ),
                _buildConfigBadge(
                  context,
                  'Vision Lock',
                  result.isVisionConfirmationRequired ? 'Required' : 'Optional',
                  color: result.isVisionConfirmationRequired
                      ? AppColors.blue
                      : AppColors.lime,
                ),
              ],
            ),
          ),
          10.height,
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 280.h),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: spikesHistory.length,
              separatorBuilder: (_, _) => 6.height,
              itemBuilder: (context, index) {
                final String spikeStr = spikesHistory[index];
                final bool isConfirmedPunch =
                    spikeStr.contains('PUNCH') || spikeStr.startsWith('🥊');
                final bool isValidDual = spikeStr.contains('[VALID]');
                final bool isCandidate = spikeStr.contains('[CANDIDATE]');
                final bool isRejected = spikeStr.contains('[REJECTED]');

                final Color borderColor = isConfirmedPunch || isValidDual
                    ? AppColors.lime.withValues(alpha: 0.6)
                    : (isCandidate
                          ? AppColors.amber.withValues(alpha: 0.6)
                          : (isRejected
                                ? AppColors.red.withValues(alpha: 0.4)
                                : AppColors.cyan.withValues(alpha: 0.4)));

                final Color bgColor = isConfirmedPunch
                    ? AppColors.lime.withValues(alpha: 0.12)
                    : (isValidDual
                          ? AppColors.lime.withValues(alpha: 0.08)
                          : (isCandidate
                                ? AppColors.amber.withValues(alpha: 0.08)
                                : (isRejected
                                      ? AppColors.red.withValues(alpha: 0.06)
                                      : AppColors.panel2)));

                final Color textColor = isConfirmedPunch || isValidDual
                    ? AppColors.lime
                    : (isCandidate
                          ? AppColors.amber
                          : (isRejected ? AppColors.red : AppColors.cyan));

                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: borderColor, width: 1.0),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${(index + 1).toString().padLeft(3, '0')}',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10.ts(context),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      8.width,
                      Expanded(
                        child: Text(
                          spikeStr,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 10.ts(context),
                            fontWeight: isConfirmedPunch
                                ? FontWeight.w800
                                : FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigBadge(
    BuildContext context,
    String label,
    String value, {
    Color? color,
  }) {
    final Color textColor = color ?? AppColors.cyan;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: textColor,
          fontSize: 9.5.ts(context),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
