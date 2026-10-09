import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/size_box.dart';
import '../../domain/services/auto_config_evaluator.dart';

/// Shows an adaptive, review dialog for the Auto-Configuration feature.
Future<void> showAutoConfigDialog(
  BuildContext context, {
  required AutoConfigResult result,
  VoidCallback? onApply,
  VoidCallback? onOpened,
  VoidCallback? onClosed,
}) async {
  onOpened?.call();
  try {
    await showDialog(
      context: context,
      builder: (ctx) => _AutoConfigReviewDialogContent(
        result: result,
        onApply: () {
          Navigator.of(ctx).pop();
          if (onApply != null) {
            onApply();
          }
        },
      ),
    );
  } finally {
    onClosed?.call();
  }
}

/// Shows an adaptive, premium review dialog for the Auto-Configuration feature.
Future<void> showAutoConfigReviewDialog(
  BuildContext context, {
  required AutoConfigResult result,
  required Function(AutoConfigResult) onApply,
  VoidCallback? onOpened,
  VoidCallback? onClosed,
}) async {
  onOpened?.call();
  try {
    await showDialog(
      context: context,
      builder: (ctx) => _AutoConfigReviewDialogContent(
        result: result,
        onApply: () {
          Navigator.of(ctx).pop();
          onApply(result);
        },
      ),
    );
  } finally {
    onClosed?.call();
  }
}

class _AutoConfigReviewDialogContent extends StatelessWidget {
  final AutoConfigResult result;
  final VoidCallback onApply;

  const _AutoConfigReviewDialogContent({
    required this.result,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    if (!result.hasSufficientData) {
      return AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.amber),
            8.width,
            Text(
              'More Punches Needed',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.ts(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.statusMessage,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13.ts(context),
                height: 1.4,
              ),
            ),
            12.height,
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: AppColors.panel2,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '💡 Tip: ${result.explanationSummary}',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.ts(context),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Got It',
              style: TextStyle(color: AppColors.lime, fontSize: 13.ts(context)),
            ),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: const BorderSide(color: AppColors.lime, width: 1.5),
      ),
      titlePadding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 10.h),
      contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      actionsPadding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 16.h),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.r),
            decoration: BoxDecoration(
              color: AppColors.lime.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.lime, size: 22),
          ),
          10.width,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto-Configured Settings',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15.ts(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                2.height,
                Text(
                  'Based on ${result.totalEventsAnalyzed} impact events',
                  style: TextStyle(
                    color: AppColors.lime,
                    fontSize: 11.ts(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.panel2,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Avg Hit: ${result.averagePunchDb} dB',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11.ts(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Avg Vibe: ${result.averagePunchVibration} m/s²',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11.ts(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            12.height,
            _buildComparisonRow(
              context,
              label: 'Audio Target',
              current: '${result.currentTargetAudioDb.round()} dB',
              recommended: '${result.recommendedTargetAudioDb.round()} dB',
              isChanged: (result.currentTargetAudioDb - result.recommendedTargetAudioDb).abs() >= 1.0,
            ),
            6.height,
            _buildComparisonRow(
              context,
              label: 'Spike Rise',
              current: '+${result.currentSpikeDb.round()} dB',
              recommended: '+${result.recommendedSpikeDb.round()} dB',
              isChanged: (result.currentSpikeDb - result.recommendedSpikeDb).abs() >= 1.0,
            ),
            6.height,
            _buildComparisonRow(
              context,
              label: 'Vibration Threshold',
              current: '${result.currentVibrationThreshold.toStringAsFixed(2)} m/s²',
              recommended: '${result.recommendedVibrationThreshold.toStringAsFixed(2)} m/s²',
              isChanged: (result.currentVibrationThreshold - result.recommendedVibrationThreshold).abs() >= 0.01,
            ),
            6.height,
            _buildComparisonRow(
              context,
              label: 'Vibration Sensor',
              current: result.currentVibrationGateEnabled ? 'Enabled' : 'Disabled',
              recommended: result.recommendedVibrationGateEnabled ? 'Enabled' : 'Disabled',
              isChanged: result.currentVibrationGateEnabled != result.recommendedVibrationGateEnabled,
            ),
            6.height,
            _buildComparisonRow(
              context,
              label: 'Camera Confirm',
              current: result.currentVisionRequired ? 'Required' : 'Optional',
              recommended: result.recommendedVisionRequired ? 'Required' : 'Optional',
              isChanged: result.currentVisionRequired != result.recommendedVisionRequired,
            ),
            12.height,
            Text(
              result.explanationSummary,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.ts(context),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Keep Current',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13.ts(context)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: onApply,
          icon: const Icon(Icons.check, size: 16),
          label: Text(
            'Apply Settings',
            style: TextStyle(fontSize: 13.ts(context), fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.lime,
            foregroundColor: AppColors.ink,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonRow(
    BuildContext context, {
    required String label,
    required String current,
    required String recommended,
    required bool isChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: isChanged
            ? AppColors.lime.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(
          color: isChanged
              ? AppColors.lime.withValues(alpha: 0.3)
              : AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.ts(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            current,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.ts(context),
              decoration: isChanged ? TextDecoration.lineThrough : null,
            ),
          ),
          if (isChanged) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: const Icon(Icons.arrow_forward, size: 12, color: AppColors.lime),
            ),
            Text(
              recommended,
              style: TextStyle(
                color: AppColors.lime,
                fontSize: 11.ts(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
