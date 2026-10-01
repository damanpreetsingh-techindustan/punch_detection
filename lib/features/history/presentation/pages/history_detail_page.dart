import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';

class HistoryDetailPage extends StatelessWidget {
  const HistoryDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              16.height,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: AppNavigator.back,
                    icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Session Log Detail',
                    style: AppTextStyles.bodyMedium(context).copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              20.height,
              Text('SESSION DETAILS', style: AppTextStyles.tag(context)),
              4.height,
              Text('Log Detail', style: AppTextStyles.heading2(context)),
              16.height,

              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildRow(context, 'Mode', 'Prompt Mode'),
                    Divider(color: AppColors.border, height: 20.h),
                    _buildRow(context, 'Total Punches', '48'),
                    Divider(color: AppColors.border, height: 20.h),
                    _buildRow(context, 'Average Reaction', '412 ms'),
                  ],
                ),
              ),

              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: Size(double.infinity, 54.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                ),
                onPressed: AppNavigator.back,
                child: Text('Close detail', style: AppTextStyles.buttonLabel(context).copyWith(color: AppColors.ink, fontWeight: FontWeight.w900)),
              ),
              20.height,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium(context)),
        Text(value, style: AppTextStyles.heading3(context).copyWith(fontSize: 14.ts(context))),
      ],
    );
  }
}
