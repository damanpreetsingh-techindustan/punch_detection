import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../controllers/permissions_controller.dart';

class PermissionsPage extends GetView<PermissionsController> {
  const PermissionsPage({super.key});

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
                    'App Setup',
                    style: AppTextStyles.bodyMedium(context).copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),

              24.height,
              Text(
                'Allow on-device detection',
                style: AppTextStyles.heading2(context),
              ),
              8.height,
              Text(
                'Microphone audio is mandatory for punch detection. Camera motion provides optional confirmation.',
                style: AppTextStyles.bodyMedium(context),
              ),
              24.height,

              Obx(() => _buildPermissionRow(
                    context: context,
                    icon: '🎙',
                    title: 'Microphone access (Required)',
                    subtitle: 'Detects impact energy spikes and audio frequency width.',
                    isGranted: controller.micGranted.value,
                    onTap: controller.requestMicrophonePermission,
                  )),
              12.height,
              Obx(() => _buildPermissionRow(
                    context: context,
                    icon: '◉',
                    title: 'Camera access (Optional)',
                    subtitle: 'Confirms body motion using on-device pose detection.',
                    isGranted: controller.cameraGranted.value,
                    onTap: controller.requestCameraPermission,
                  )),
              12.height,
              Obx(() => _buildPermissionRow(
                    context: context,
                    icon: '▣',
                    title: 'Local session storage',
                    subtitle: 'Saves prompts, punches, timestamps on this phone.',
                    isGranted: controller.storageGranted.value,
                    onTap: () {},
                  )),

              const Spacer(),
              Obx(() => ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: controller.micGranted.value ? AppColors.primary : AppColors.panel,
                      side: BorderSide(
                        color: controller.micGranted.value ? AppColors.primary : AppColors.border,
                      ),
                      minimumSize: Size(double.infinity, 54.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    onPressed: controller.continueNext,
                    child: Text(
                      controller.micGranted.value ? 'Complete Setup & Go to Home' : 'Grant Required Permissions to Proceed',
                      style: AppTextStyles.buttonLabel(context).copyWith(
                        color: controller.micGranted.value ? AppColors.ink : AppColors.textMuted,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )),
              20.height,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionRow({
    required BuildContext context,
    required String icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: isGranted ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42.r,
              height: 42.r,
              decoration: BoxDecoration(
                color: AppColors.panel2,
                borderRadius: BorderRadius.circular(13.r),
              ),
              child: Center(
                child: Text(
                  icon,
                  style: TextStyle(fontSize: 18.ts(context)),
                ),
              ),
            ),
            12.width,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.heading3(context).copyWith(fontSize: 14.ts(context)),
                  ),
                  2.height,
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium(context).copyWith(fontSize: 12.ts(context)),
                  ),
                ],
              ),
            ),
            8.width,
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46.w,
              height: 26.h,
              padding: EdgeInsets.all(3.r),
              decoration: BoxDecoration(
                color: isGranted ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(999.r),
              ),
              child: Align(
                alignment: isGranted ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20.r,
                  height: 20.r,
                  decoration: BoxDecoration(
                    color: isGranted ? AppColors.ink : Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
