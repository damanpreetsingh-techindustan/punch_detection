import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';

class MountGuidePage extends StatelessWidget {
  const MountGuidePage({super.key});

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
                    'Mounting Guide',
                    style: AppTextStyles.bodyMedium(context).copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),

              24.height,
              Text(
                'Mount the phone',
                style: AppTextStyles.heading2(context),
              ),
              8.height,
              Text(
                'Secure your phone on the Hyper Hitter bracket. Keep the microphone facing the bag and the camera view clear.',
                style: AppTextStyles.bodyMedium(context),
              ),
              20.height,

              Container(
                height: 220.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E141B),
                  borderRadius: BorderRadius.circular(23.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 76.w,
                      height: 135.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13.r),
                        border: Border.all(color: AppColors.lime, width: 3),
                      ),
                    ),
                    Positioned(
                      left: 18.w,
                      bottom: 16.h,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF17230F),
                          borderRadius: BorderRadius.circular(999.r),
                          border: Border.all(color: const Color(0xFF3B5618)),
                        ),
                        child: Text(
                          'Fixed phone-to-bag distance',
                          style: TextStyle(
                            color: AppColors.lime,
                            fontSize: 11.ts(context),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              20.height,
              _buildGuideRow(
                context: context,
                num: '1',
                title: 'Use the Hyper Hitter bracket',
                subtitle: 'Supports wall, rack and post installations.',
              ),
              12.height,
              _buildGuideRow(
                context: context,
                num: '2',
                title: 'Keep the mount stable',
                subtitle: 'A stable position improves audio and vision consistency.',
              ),

              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: Size(double.infinity, 54.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                onPressed: AppNavigator.toPermissions,
                child: Text(
                  'Continue to Permissions',
                  style: AppTextStyles.buttonLabel(context).copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              20.height,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideRow({
    required BuildContext context,
    required String num,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 38.r,
          height: 38.r,
          decoration: BoxDecoration(
            color: AppColors.panel2,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Center(
            child: Text(
              num,
              style: AppTextStyles.heading3(context).copyWith(fontSize: 16.ts(context)),
            ),
          ),
        ),
        12.width,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.heading3(context).copyWith(fontSize: 14.ts(context))),
              2.height,
              Text(subtitle, style: AppTextStyles.bodyMedium(context).copyWith(fontSize: 12.ts(context))),
            ],
          ),
        ),
      ],
    );
  }
}
