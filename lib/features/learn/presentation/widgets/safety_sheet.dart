import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../../../../core/widgets/ui/app_buttons.dart';

/// One-time "Train safely" screen before the first lesson. Returns true when
/// the user accepts.
Future<bool?> showSafetySheet() {
  return Get.bottomSheet<bool>(
    const _SafetySheet(),
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
  );
}

class _SafetySheet extends StatelessWidget {
  const _SafetySheet();

  static const _points = [
    (
      Icons.directions_run_rounded,
      'Warm up first',
      '3–5 minutes of light movement: arm circles, marching, shadow boxing.',
    ),
    (
      Icons.back_hand_rounded,
      'Protect your hands',
      'Wrap your hands and wear gloves when you hit a bag or pads.',
    ),
    (
      Icons.open_with_rounded,
      'Clear your space',
      'Room to move all around you, and the phone set up where it can\'t fall.',
    ),
    (
      Icons.healing_rounded,
      'Listen to your body',
      'Start slowly. Stop if you feel pain, dizziness or shortness of breath.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.health_and_safety_rounded,
                color: AppColors.success,
                size: 40.r,
              ),
              10.height,
              Text(
                'Train safely',
                textAlign: TextAlign.center,
                style: AppTextStyles.heading2(),
              ),
              6.height,
              Text(
                'A few things before your first lesson.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium(),
              ),
              18.height,
              for (final (icon, title, body) in _points)
                Padding(
                  padding: EdgeInsets.only(bottom: 14.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36.r,
                        height: 36.r,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(icon, color: AppColors.success, size: 19.r),
                      ),
                      12.width,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTextStyles.bodyLarge().copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            2.height,
                            Text(body, style: AppTextStyles.bodyMedium()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                'KnockUp gives general fitness guidance, not medical advice. '
                'If you have a health condition, an injury or are pregnant, '
                'check with a doctor before you start.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium().copyWith(fontSize: 11.fs),
              ),
              16.height,
              PrimaryButton(
                label: 'I understand, let\'s train',
                icon: Icons.check_rounded,
                onPressed: () => Get.back(result: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
