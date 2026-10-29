import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/size_box.dart';
import '../controllers/settings_controller.dart';

class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.w),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                16.height,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: AppNavigator.back,
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Settings & Configuration',
                      style: AppTextStyles.bodyMedium(
                        context,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                20.height,
                Text(
                  'DETECTION ENGINE PARAMS',
                  style: AppTextStyles.tag(context),
                ),
                4.height,
                Text(
                  'Tunable Thresholds',
                  style: AppTextStyles.heading2(context),
                ),
                16.height,

                Obx(
                  () => _buildSlider(
                    context: context,
                    title: 'Audio Impact Energy Threshold',
                    subtitle:
                        'Minimum RMS energy to register audio punch candidate.',
                    value: controller.audioEnergyThreshold.value,
                    min: 0.1,
                    max: 1.0,
                    onChanged: (v) => controller.audioEnergyThreshold.value = v,
                  ),
                ),
                12.height,
                Obx(
                  () => _buildSlider(
                    context: context,
                    title: 'Vision Motion Confirmation Threshold',
                    subtitle:
                        'Minimum pose displacement required for vision vote.',
                    value: controller.visionMotionThreshold.value,
                    min: 0.1,
                    max: 1.0,
                    onChanged: (v) =>
                        controller.visionMotionThreshold.value = v,
                  ),
                ),
                12.height,
                Obx(
                  () => _buildSlider(
                    context: context,
                    title: 'Audio vs. Vision Signal Weighting',
                    subtitle:
                        'Audio weight: ${(controller.audioWeight.value * 100).round()}% | Vision weight: ${((1.0 - controller.audioWeight.value) * 100).round()}%.',
                    value: controller.audioWeight.value,
                    min: 0.10,
                    max: 0.90,
                    onChanged: (v) => controller.setAudioWeight(v),
                  ),
                ),
                12.height,
                Obx(
                  () => _buildSlider(
                    context: context,
                    title: 'Minimum Fused Confidence Threshold',
                    subtitle:
                        'Minimum score required to confirm a fused audio+vision punch.',
                    value: controller.minFusionConfidenceThreshold.value,
                    min: 0.40,
                    max: 0.95,
                    onChanged: (v) =>
                        controller.setMinFusionConfidenceThreshold(v),
                  ),
                ),

                24.height,
                Text('DEBUG', style: AppTextStyles.tag(context)),
                8.height,
                Obx(
                  () => _buildSwitch(
                    context: context,
                    title: 'Record raw data',
                    subtitle:
                        '16 kHz audio, full-rate accelerometer, camera landmarks '
                        'and every decision for each Free session (for offline '
                        'replay and tuning). Uses ~2 MB per minute.',
                    value: controller.recordRawData.value,
                    onChanged: controller.setRecordRawData,
                  ),
                ),

                32.height,
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: Size(double.infinity, 54.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  onPressed: controller.saveSettings,
                  child: Text(
                    'Save detection parameters',
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
      ),
    );
  }

  Widget _buildSwitch({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.heading3(
                    context,
                  ).copyWith(fontSize: 14.ts(context)),
                ),
                4.height,
                Text(
                  subtitle,
                  style: AppTextStyles.bodyMedium(
                    context,
                  ).copyWith(fontSize: 11.ts(context)),
                ),
              ],
            ),
          ),
          12.width,
          Switch(
            value: value,
            activeThumbColor: AppColors.lime,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required BuildContext context,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.heading3(
                    context,
                  ).copyWith(fontSize: 14.ts(context)),
                ),
              ),
              12.width,
              Text(
                value.toStringAsFixed(2),
                style: TextStyle(
                  color: AppColors.lime,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.ts(context),
                ),
              ),
            ],
          ),
          4.height,
          Text(
            subtitle,
            style: AppTextStyles.bodyMedium(
              context,
            ).copyWith(fontSize: 11.ts(context)),
          ),
          8.height,
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4.h,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8.r),
              activeTrackColor: AppColors.lime,
              inactiveTrackColor: AppColors.border,
              thumbColor: AppColors.lime,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
