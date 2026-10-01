import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../controllers/benchmarking_controller.dart';

class BenchmarkingPage extends GetView<BenchmarkingController> {
  const BenchmarkingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Accuracy Benchmarking', style: AppTextStyles.heading2(context)),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall F1 Score Card
              Obx(() {
                final report = controller.report.value;
                final f1Pct = (report.f1Score * 100).toStringAsFixed(1);
                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: report.isPassed ? AppColors.green : AppColors.red,
                      width: 2.w,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text('OVERALL F1 ACCURACY SCORE', style: AppTextStyles.tag(context)),
                      8.height,
                      Text(
                        '$f1Pct%',
                        style: AppTextStyles.heading1(context).copyWith(
                          fontSize: 56.sp,
                          color: report.isPassed ? AppColors.green : AppColors.red,
                        ),
                      ),
                      8.height,
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: (report.isPassed ? AppColors.green : AppColors.red).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          report.isPassed ? 'BENCHMARK PASSED (>90%)' : 'BENCHMARK FAILED (<90%)',
                          style: AppTextStyles.tag(context).copyWith(
                            color: report.isPassed ? AppColors.green : AppColors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              20.height,

              // Metric Cards Row (Precision, Recall, Latency)
              Obx(() {
                final report = controller.report.value;
                return Row(
                  children: [
                    _buildMetricCard(context, 'PRECISION', '${(report.precision * 100).toStringAsFixed(1)}%', AppColors.primary),
                    12.width,
                    _buildMetricCard(context, 'RECALL', '${(report.recall * 100).toStringAsFixed(1)}%', AppColors.secondary),
                    12.width,
                    _buildMetricCard(context, 'LATENCY', '${report.meanLatencyMs} ms', AppColors.blue),
                  ],
                );
              }),
              20.height,

              // Confusion Matrix Grid
              Text('CONFUSION MATRIX (100 SAMPLES)', style: AppTextStyles.tag(context)),
              10.height,
              Expanded(
                child: Obx(() {
                  final report = controller.report.value;
                  return GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 12.h,
                    childAspectRatio: 1.8,
                    children: [
                      _buildMatrixCell(context, 'TRUE POSITIVES (TP)', '${report.truePositives}', 'Correct Punches', AppColors.green),
                      _buildMatrixCell(context, 'FALSE POSITIVES (FP)', '${report.falsePositives}', 'False Alarms', AppColors.red),
                      _buildMatrixCell(context, 'TRUE NEGATIVES (TN)', '${report.trueNegatives}', 'Correct Rejections', AppColors.blue),
                      _buildMatrixCell(context, 'FALSE NEGATIVES (FN)', '${report.falseNegatives}', 'Missed Punches', AppColors.amber),
                    ],
                  );
                }),
              ),

              // Run Benchmark Suite Button
              16.height,
              Obx(() {
                final isRunning = controller.isRunning.value;
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    onPressed: isRunning ? null : () => controller.executeBenchmark(),
                    child: isRunning
                        ? const CircularProgressIndicator(color: AppColors.background)
                        : Text('RUN BENCHMARK SUITE', style: AppTextStyles.buttonLabel(context).copyWith(color: AppColors.background)),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(label, style: AppTextStyles.tag(context)),
            6.height,
            Text(value, style: AppTextStyles.heading2(context).copyWith(color: color, fontSize: 18.sp)),
          ],
        ),
      ),
    );
  }

  Widget _buildMatrixCell(BuildContext context, String title, String count, String subtitle, Color color) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: AppTextStyles.tag(context).copyWith(fontSize: 10.sp, color: AppColors.textMuted)),
          4.height,
          Text(count, style: AppTextStyles.heading1(context).copyWith(color: color, fontSize: 28.sp)),
          2.height,
          Text(subtitle, style: AppTextStyles.bodyMedium(context).copyWith(fontSize: 10.sp)),
        ],
      ),
    );
  }
}
