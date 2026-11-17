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
import '../../../../core/utils/size_box.dart';

/// Developer mode only: the session's detection settings, the punch spikes
/// log and the .txt / .csv export (moved here from the old Results screen).
class ResultsDevPanel extends StatelessWidget {
  final SessionResultModel result;

  const ResultsDevPanel({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.recordedSpikesHistory.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => _exportAndShareSessionLogs(context, result),
          icon: Icon(Icons.share, color: AppColors.warning, size: 14.w),
          label: Text(
            'EXPORT .TXT',
            style: AppTextStyles.tag().copyWith(color: AppColors.warning),
          ),
        ),
      );
    }
    return _buildRecordedSpikesCard(context, result);
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
      buffer.writeln('             KNOCKUP - PUNCH LOG EXPORT              ');
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
        buffer.writeln(
          'One row per punch decision (kind=IMPACT) and per camera',
        );
        buffer.writeln(
          'change (kind=CAMERA). Paste into Excel / Google Sheets.',
        );
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
          '${tempDir.path}/knockup_punch_log_$timestamp.txt';
      final File file = File(filePath);
      await file.writeAsString(content);

      // 3. Attempt native share sheet
      bool shareSuccess = false;
      try {
        final XFile xFile = XFile(filePath, mimeType: 'text/plain');
        final List<XFile> shareFiles = <XFile>[xFile];
        if (result.summaryCsv.isNotEmpty) {
          final String csvPath =
              '${tempDir.path}/knockup_summary_$timestamp.csv';
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
                'KnockUp Workout Punch Log Export (.txt) — Total Punches: ${result.totalPunches}',
            subject: 'KnockUp Punch Log Export',
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
