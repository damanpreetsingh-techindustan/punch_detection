import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../../domain/entities/workout_record.dart';
import '../controllers/history_controller.dart';

class HistoryPage extends GetView<HistoryController> {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Workout History',
          style: AppTextStyles.heading2(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.red),
            onPressed: () => _confirmClearDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
          child: isLandscape
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Lifetime Summary Stats Card
                    Expanded(
                      flex: 4,
                      child: Obx(() {
                        final stats = controller.summaryStats.value;
                        return Container(
                          padding: EdgeInsets.all(14.w),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildSummaryMetric(
                                context,
                                label: 'WORKOUTS',
                                value: '${stats.totalWorkouts}',
                                color: AppColors.textPrimary,
                              ),
                              Divider(color: AppColors.border, height: 16.h),
                              _buildSummaryMetric(
                                context,
                                label: 'PUNCHES',
                                value: '${stats.totalPunches}',
                                color: AppColors.primary,
                              ),
                              Divider(color: AppColors.border, height: 16.h),
                              _buildSummaryMetric(
                                context,
                                label: 'AVG REACTION',
                                value:
                                    '${stats.lifetimeAvgReactionMs.toStringAsFixed(0)} ms',
                                color: AppColors.secondary,
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                    16.width,

                    // Right Column: History Record List
                    Expanded(
                      flex: 6,
                      child: Obx(() {
                        if (controller.isLoading.value) {
                          return const Center(
                            child: CircularProgressIndicator(color: AppColors.primary),
                          );
                        }

                        if (controller.records.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history, size: 48.w, color: AppColors.textMuted),
                                12.height,
                                Text(
                                  'No Saved Workouts',
                                  style: AppTextStyles.heading3(context),
                                ),
                                6.height,
                                Text(
                                  'Complete a session to record your punch performance.',
                                  style: AppTextStyles.bodyMedium(context),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: controller.records.length,
                          separatorBuilder: (_, index) => 10.height,
                          itemBuilder: (context, index) {
                            final record = controller.records[index];
                            return _buildRecordTile(context, record);
                          },
                        );
                      }),
                    ),
                  ],
                )
              : Column(
                  children: [
                    // Lifetime Summary Header Cards
                    Obx(() {
                      final stats = controller.summaryStats.value;
                      return Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSummaryMetric(
                              context,
                              label: 'WORKOUTS',
                              value: '${stats.totalWorkouts}',
                              color: AppColors.textPrimary,
                            ),
                            Container(height: 36.h, width: 1.w, color: AppColors.border),
                            _buildSummaryMetric(
                              context,
                              label: 'PUNCHES',
                              value: '${stats.totalPunches}',
                              color: AppColors.primary,
                            ),
                            Container(height: 36.h, width: 1.w, color: AppColors.border),
                            _buildSummaryMetric(
                              context,
                              label: 'AVG REACTION',
                              value: '${stats.lifetimeAvgReactionMs.toStringAsFixed(0)} ms',
                              color: AppColors.secondary,
                            ),
                          ],
                        ),
                      );
                    }),
                    20.height,

                    // History Record List
                    Expanded(
                      child: Obx(() {
                        if (controller.isLoading.value) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                        }

                        if (controller.records.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history, size: 64.w, color: AppColors.textMuted),
                                16.height,
                                Text(
                                  'No Saved Workouts',
                                  style: AppTextStyles.heading3(context),
                                ),
                                8.height,
                                Text(
                                  'Complete a session to record your punch performance.',
                                  style: AppTextStyles.bodyMedium(context),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: controller.records.length,
                          separatorBuilder: (_, index) => 12.height,
                          itemBuilder: (context, index) {
                            final record = controller.records[index];
                            return _buildRecordTile(context, record);
                          },
                        );
                      }),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.tag(context).copyWith(color: AppColors.textMuted)),
        6.height,
        Text(
          value,
          style: AppTextStyles.heading2(context).copyWith(color: color, fontSize: 20.ts(context)),
        ),
      ],
    );
  }

  Widget _buildRecordTile(BuildContext context, WorkoutRecord record) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.sports_mma, color: AppColors.primary, size: 24.w),
              ),
              12.width,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${record.totalPunches} Punches',
                    style: AppTextStyles.bodyLarge(context).copyWith(fontWeight: FontWeight.bold),
                  ),
                  4.height,
                  Text(
                    'Avg: ${record.averageReactionMs.toStringAsFixed(0)} ms  •  Best: ${record.bestReactionMs} ms',
                    style: AppTextStyles.bodyMedium(context),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              record.detectionMode.toUpperCase(),
              style: AppTextStyles.tag(context),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Clear Workout History', style: AppTextStyles.heading3(context)),
        content: Text(
          'Are you sure you want to delete all saved workout records? This action cannot be undone.',
          style: AppTextStyles.bodyMedium(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: AppTextStyles.bodyMedium(context)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () {
              Get.back();
              controller.clearAllHistory();
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
