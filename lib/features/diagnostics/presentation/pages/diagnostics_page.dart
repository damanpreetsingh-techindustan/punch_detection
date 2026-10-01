import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../../domain/entities/filter_stage_status.dart';
import '../controllers/diagnostics_controller.dart';

class DiagnosticsPage extends GetView<DiagnosticsController> {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Diagnostics & Tuning', style: AppTextStyles.heading2(context)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          child: isLandscape
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Side: Telemetry + Filter Stage Breakdown
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('LIVE SIGNAL TELEMETRY', style: AppTextStyles.tag(context)),
                          6.height,
                          Obx(() {
                            final telemetry = controller.latestTelemetry.value;
                            return Container(
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildTelemetryItem(context, 'Audio RMS', '${(telemetry.audioRms * 100).toStringAsFixed(1)}%', AppColors.primary),
                                      _buildTelemetryItem(context, 'Peak Amp', '${(telemetry.peakAmplitude * 100).toStringAsFixed(1)}%', AppColors.secondary),
                                      _buildTelemetryItem(context, 'Flatness', '${telemetry.spectralFlatness}', AppColors.blue),
                                    ],
                                  ),
                                  8.height,
                                  const Divider(color: AppColors.border),
                                  8.height,
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildTelemetryItem(context, 'Elbow Angle', '${telemetry.elbowAngle.toStringAsFixed(0)}°', AppColors.lime),
                                      _buildTelemetryItem(context, 'Wrist Speed', '${telemetry.wristVelocity} m/s', AppColors.amber),
                                      _buildTelemetryItem(
                                        context,
                                        'Fused Punch',
                                        telemetry.isFusedPunch ? 'DETECTED' : 'IDLE',
                                        telemetry.isFusedPunch ? AppColors.green : AppColors.textMuted,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                          12.height,

                          Text('FILTER STAGE BREAKDOWN', style: AppTextStyles.tag(context)),
                          6.height,
                          Obx(() {
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 2.2,
                                crossAxisSpacing: 8.w,
                                mainAxisSpacing: 8.h,
                              ),
                              itemCount: controller.filterStages.length,
                              itemBuilder: (context, index) {
                                final stage = controller.filterStages[index];
                                return _buildFilterStageCard(context, stage);
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                    16.width,

                    // Right Side: Algorithm Parameter Tuning Sliders
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ALGORITHM PARAMETER TUNING', style: AppTextStyles.tag(context)),
                          6.height,
                          Container(
                            padding: EdgeInsets.all(14.w),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                // Audio Weight Slider
                                Obx(() {
                                  final weight = controller.audioWeight.value;
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Audio Primary Weight', style: AppTextStyles.bodyMedium(context)),
                                          Text('${(weight * 100).toStringAsFixed(0)}%', style: AppTextStyles.heading3(context).copyWith(color: AppColors.primary)),
                                        ],
                                      ),
                                      Slider(
                                        value: weight,
                                        min: 0.50,
                                        max: 0.90,
                                        activeColor: AppColors.primary,
                                        onChanged: (val) => controller.setAudioWeight(val),
                                      ),
                                    ],
                                  );
                                }),
                                10.height,

                                // Minimum Fused Confidence Slider
                                Obx(() {
                                  final conf = controller.minConfidenceThreshold.value;
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Min Fused Confidence Threshold', style: AppTextStyles.bodyMedium(context)),
                                          Text('${(conf * 100).toStringAsFixed(0)}%', style: AppTextStyles.heading3(context).copyWith(color: AppColors.secondary)),
                                        ],
                                      ),
                                      Slider(
                                        value: conf,
                                        min: 0.50,
                                        max: 0.95,
                                        activeColor: AppColors.secondary,
                                        onChanged: (val) => controller.setMinConfidenceThreshold(val),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Real-Time Signal Telemetry Cards
                    Text('LIVE SIGNAL TELEMETRY', style: AppTextStyles.tag(context)),
                    10.height,
                    Obx(() {
                      final telemetry = controller.latestTelemetry.value;
                      return Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildTelemetryItem(context, 'Audio RMS', '${(telemetry.audioRms * 100).toStringAsFixed(1)}%', AppColors.primary),
                                _buildTelemetryItem(context, 'Peak Amp', '${(telemetry.peakAmplitude * 100).toStringAsFixed(1)}%', AppColors.secondary),
                                _buildTelemetryItem(context, 'Flatness', '${telemetry.spectralFlatness}', AppColors.blue),
                              ],
                            ),
                            12.height,
                            const Divider(color: AppColors.border),
                            12.height,
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildTelemetryItem(context, 'Elbow Angle', '${telemetry.elbowAngle.toStringAsFixed(0)}°', AppColors.lime),
                                _buildTelemetryItem(context, 'Wrist Speed', '${telemetry.wristVelocity} m/s', AppColors.amber),
                                _buildTelemetryItem(
                                  context,
                                  'Fused Punch',
                                  telemetry.isFusedPunch ? 'DETECTED' : 'IDLE',
                                  telemetry.isFusedPunch ? AppColors.green : AppColors.textMuted,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    20.height,

                    // 6-Filter Stage Status Grid
                    Text('FILTER STAGE BREAKDOWN', style: AppTextStyles.tag(context)),
                    10.height,
                    Obx(() {
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.2,
                          crossAxisSpacing: 12.w,
                          mainAxisSpacing: 12.h,
                        ),
                        itemCount: controller.filterStages.length,
                        itemBuilder: (context, index) {
                          final stage = controller.filterStages[index];
                          return _buildFilterStageCard(context, stage);
                        },
                      );
                    }),
                    24.height,

                    // Live Parameter Tuning Sliders
                    Text('ALGORITHM PARAMETER TUNING', style: AppTextStyles.tag(context)),
                    10.height,
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          // Audio Weight Slider
                          Obx(() {
                            final weight = controller.audioWeight.value;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Audio Primary Weight', style: AppTextStyles.bodyMedium(context)),
                                    Text('${(weight * 100).toStringAsFixed(0)}%', style: AppTextStyles.heading3(context).copyWith(color: AppColors.primary)),
                                  ],
                                ),
                                Slider(
                                  value: weight,
                                  min: 0.50,
                                  max: 0.90,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) => controller.setAudioWeight(val),
                                ),
                              ],
                            );
                          }),
                          12.height,

                          // Minimum Fused Confidence Slider
                          Obx(() {
                            final conf = controller.minConfidenceThreshold.value;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Min Fused Confidence Threshold', style: AppTextStyles.bodyMedium(context)),
                                    Text('${(conf * 100).toStringAsFixed(0)}%', style: AppTextStyles.heading3(context).copyWith(color: AppColors.secondary)),
                                  ],
                                ),
                                Slider(
                                  value: conf,
                                  min: 0.50,
                                  max: 0.95,
                                  activeColor: AppColors.secondary,
                                  onChanged: (val) => controller.setMinConfidenceThreshold(val),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTelemetryItem(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.tag(context).copyWith(color: AppColors.textMuted)),
        4.height,
        Text(value, style: AppTextStyles.heading3(context).copyWith(color: color, fontSize: 16.ts(context))),
      ],
    );
  }

  Widget _buildFilterStageCard(BuildContext context, FilterStageStatus stage) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: stage.passed ? AppColors.green : AppColors.red.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                stage.passed ? Icons.check_circle : Icons.cancel,
                color: stage.passed ? AppColors.green : AppColors.red,
                size: 16.w,
              ),
              6.width,
              Expanded(
                child: Text(
                  stage.stageName,
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    fontSize: 11.ts(context),
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          4.height,
          Text(
            'Val: ${stage.currentValue} / Thresh: ${stage.thresholdValue}',
            style: AppTextStyles.tag(context).copyWith(fontSize: 9.ts(context)),
          ),
        ],
      ),
    );
  }
}
