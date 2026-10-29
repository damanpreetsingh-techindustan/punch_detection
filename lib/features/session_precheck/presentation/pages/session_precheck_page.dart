import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import '../../../../core/enums/detection_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/common_function.dart';
import '../../../../core/utils/size_box.dart';
import '../../../../core/services/device_stability/device_stability_models.dart';
import 'package:punch_detection_demo/features/session/presentation/widgets/audio_spike_waveform_painter.dart';
import '../controllers/session_precheck_controller.dart';

class SessionPreCheckPage extends GetView<SessionPreCheckController> {
  const SessionPreCheckPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isLandscape = CommonFunction.checkOrientationLandscape(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 0.05.sw : 22.w,
          ),
          child: Column(
            children: [
              12.height,

              // Dynamic Header: "Pre-Session Step X of Y"
              !AppConstants.showAllFeatures
                  ? SizedBox()
                  : Obx(
                      () => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: controller.previousStep,
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Pre-Session Step ${controller.currentStep.value + 1} of ${controller.totalSteps}',
                            style: AppTextStyles.bodyMedium(
                              context,
                            ).copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),

              8.height,

              // Dynamic Progress Indicator (4 or 5 segments)
              !AppConstants.showAllFeatures
                  ? SizedBox()
                  : Obx(
                      () => Row(
                        children: List.generate(
                          controller.totalSteps,
                          (index) => Expanded(
                            child: Container(
                              height: 4.h,
                              margin: EdgeInsets.symmetric(horizontal: 2.w),
                              decoration: BoxDecoration(
                                color: index <= controller.currentStep.value
                                    ? AppColors.cyan
                                    : AppColors.border,
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

              16.height,

              // Dynamic PageView Pages
              Expanded(
                child: Obx(() {
                  final mode = controller.selectedMode.value;
                  final isFusion = mode == DetectionMode.fusion;
                  final isAudioMode =
                      mode == DetectionMode.audio ||
                      mode == DetectionMode.audioVibration;
                  final isCameraOnly = mode == DetectionMode.camera;
                  final showPermissionsStep = controller.needsPermissionsStep;
                  final List<Widget> steps = AppConstants.showAllFeatures
                      ? <Widget>[
                          if (showPermissionsStep)
                            _buildStep1CheckPermissions(context),
                          _buildStep2SelectMode(context),
                          if (isFusion || isCameraOnly)
                            _buildStep4ConfirmCamera(context),
                          if (isFusion || isAudioMode)
                            _buildStep5CalibrateGymNoise(
                              context,
                              stepNumber: controller.totalSteps,
                              total: controller.totalSteps,
                            ),
                        ]
                      : <Widget>[
                          if (showPermissionsStep)
                            _buildStep1CheckPermissions(context),
                          _buildStep2SelectMode(context),
                          if (isFusion || isAudioMode)
                            _buildStep5CalibrateGymNoise(
                              context,
                              stepNumber: controller.totalSteps,
                              total: controller.totalSteps,
                            ),
                        ];

                  return PageView(
                    controller: controller.pageController,
                    onPageChanged: controller.onPageChanged,
                    physics: const BouncingScrollPhysics(),
                    children: steps,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // STEP 1: PERMISSION CHECK
  Widget _buildStep1CheckPermissions(BuildContext context) {
    final bool isLandscape = CommonFunction.checkOrientationLandscape(context);

    if (isLandscape) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Header, Description & Continue Button
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check Permissions',
                      style: AppTextStyles.heading2(
                        context,
                      ).copyWith(fontSize: 18.ts(context)),
                    ),
                    6.height,
                    Text(
                      'Select required hardware permissions for your chosen punch detection mode.',
                      style: AppTextStyles.bodyMedium(
                        context,
                      ).copyWith(fontSize: 11.ts(context)),
                    ),
                    16.height,
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: Size(double.infinity, 44.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      onPressed: controller.nextStep,
                      child: Text(
                        'Continue to Mode Selection',
                        style: AppTextStyles.buttonLabel(context).copyWith(
                          color: AppColors.ink,
                          fontSize: 12.ts(context),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            16.width,

            // Right Column: Permission Option Cards
            Expanded(
              flex: 6,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Obx(() {
                      final isCameraOnly =
                          controller.selectedMode.value == DetectionMode.camera;
                      return _permissionCard(
                        context: context,
                        icon: '🎙',
                        title:
                            'Microphone access (${isCameraOnly ? 'Optional' : 'Required'})',
                        subtitle:
                            'Detects acoustic punch impact energy and decibel spikes.',
                        isGranted: controller.micGranted.value,
                        onTap: controller.requestMicrophone,
                      );
                    }),
                    10.height,
                    Obx(() {
                      final isAudioOnly =
                          !controller.selectedMode.value.requiresCamera;
                      return _permissionCard(
                        context: context,
                        icon: '◉',
                        title:
                            'Camera access (${isAudioOnly ? 'Optional' : 'Required'})',
                        subtitle:
                            'Tracks shoulder, elbow, and wrist movement using Google ML Kit.',
                        isGranted: controller.cameraGranted.value,
                        onTap: controller.requestCamera,
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Check Permissions',
                    style: AppTextStyles.heading2(context),
                  ),
                  8.height,
                  Text(
                    'Select required hardware permissions for your chosen punch detection mode.',
                    style: AppTextStyles.bodyMedium(context),
                  ),
                  20.height,

                  Obx(() {
                    final isCameraOnly =
                        controller.selectedMode.value == DetectionMode.camera;
                    return _permissionCard(
                      context: context,
                      icon: '🎙',
                      title:
                          'Microphone access (${isCameraOnly ? 'Optional' : 'Required'})',
                      subtitle:
                          'Detects acoustic punch impact energy and decibel spikes.',
                      isGranted: controller.micGranted.value,
                      onTap: controller.requestMicrophone,
                    );
                  }),
                  12.height,
                  Obx(() {
                    final isAudioOnly =
                        !controller.selectedMode.value.requiresCamera;
                    return _permissionCard(
                      context: context,
                      icon: '◉',
                      title:
                          'Camera access (${isAudioOnly ? 'Optional' : 'Required'})',
                      subtitle:
                          'Tracks shoulder, elbow, and wrist movement using Google ML Kit.',
                      isGranted: controller.cameraGranted.value,
                      onTap: controller.requestCamera,
                    );
                  }),
                  12.height,
                  const Spacer(),
                  16.height,
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: Size(double.infinity, 54.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    onPressed: controller.nextStep,
                    child: Text(
                      'Continue to Mode Selection',
                      style: AppTextStyles.buttonLabel(context).copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  16.height,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // STEP 2: SELECT DETECTION MODE (3 OPTIONS: Audio+Camera, Audio Only, Camera Only)
  Widget _buildStep2SelectMode(BuildContext context) {
    final bool isLandscape = CommonFunction.checkOrientationLandscape(context);

    if (isLandscape) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Header, Description & Button
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Detection Mode',
                      style: AppTextStyles.heading2(
                        context,
                      ).copyWith(fontSize: 18.ts(context)),
                    ),
                    6.height,
                    Text(
                      'Choose how HyperHitter AI detects your punches during workout sessions.',
                      style: AppTextStyles.bodyMedium(
                        context,
                      ).copyWith(fontSize: 11.ts(context)),
                    ),
                    16.height,
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: Size(double.infinity, 44.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      onPressed: controller.nextStep,
                      child: Obx(() {
                      final mode = controller.selectedMode.value;
                      final String label;
                      if (AppConstants.showAllFeatures) {
                        if (mode == DetectionMode.fusion ||
                            mode == DetectionMode.camera) {
                          label = 'Continue to Confirm Camera';
                        } else if (mode == DetectionMode.audio ||
                            mode == DetectionMode.audioVibration) {
                          label = 'Continue to 5s Calibration';
                        } else {
                          label = 'Finish & Launch Session';
                        }
                      } else {
                        if (mode == DetectionMode.fusion ||
                            mode == DetectionMode.audio ||
                            mode == DetectionMode.audioVibration) {
                          label = 'Continue to 5s Calibration';
                        } else {
                          label = 'Finish & Launch Session';
                        }
                      }
                      return Text(
                        label,
                        style: AppTextStyles.buttonLabel(context).copyWith(
                          color: AppColors.ink,
                          fontSize: 12.ts(context),
                          fontWeight: FontWeight.w900,
                        ),
                      );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            16.width,

            // Right Column: 3 Mode Cards
            Expanded(
              flex: 6,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Obx(
                      () => _modeCardRow(
                        context: context,
                        id: DetectionMode.fusion.id,
                        icon: DetectionMode.fusion.icon,
                        title: DetectionMode.fusion.title,
                        subtitle: DetectionMode.fusion.subtitle,
                        isSelected:
                            controller.selectedMode.value ==
                            DetectionMode.fusion,
                        onTap: () =>
                            controller.selectMode(DetectionMode.fusion),
                      ),
                    ),
                    8.height,
                    if (!AppConstants.showAllFeatures && false) ...[
                      Obx(
                        () => _modeCardRow(
                          context: context,
                          id: DetectionMode.audioVibration.id,
                          icon: DetectionMode.audioVibration.icon,
                          title: DetectionMode.audioVibration.title,
                          subtitle: DetectionMode.audioVibration.subtitle,
                          isSelected:
                              controller.selectedMode.value ==
                              DetectionMode.audioVibration,
                          onTap: () => controller.selectMode(
                            DetectionMode.audioVibration,
                          ),
                          forTesting: true,
                        ),
                      ),
                      8.height,
                      Obx(
                        () => _modeCardRow(
                          context: context,
                          id: DetectionMode.audio.id,
                          icon: DetectionMode.audio.icon,
                          title: DetectionMode.audio.title,
                          subtitle: DetectionMode.audio.subtitle,
                          isSelected:
                              controller.selectedMode.value ==
                              DetectionMode.audio,
                          onTap: () =>
                              controller.selectMode(DetectionMode.audio),
                          forTesting: true,
                        ),
                      ),

                      8.height,
                      Obx(
                        () => _modeCardRow(
                          context: context,
                          id: DetectionMode.vibration.id,
                          icon: DetectionMode.vibration.icon,
                          title: DetectionMode.vibration.title,
                          subtitle: DetectionMode.vibration.subtitle,
                          isSelected:
                              controller.selectedMode.value ==
                              DetectionMode.vibration,
                          onTap: () =>
                              controller.selectMode(DetectionMode.vibration),
                          forTesting: true,
                        ),
                      ),
                      8.height,
                      Obx(
                        () => _modeCardRow(
                          context: context,
                          id: DetectionMode.camera.id,
                          icon: DetectionMode.camera.icon,
                          title: DetectionMode.camera.title,
                          subtitle: DetectionMode.camera.subtitle,
                          isSelected:
                              controller.selectedMode.value ==
                              DetectionMode.camera,
                          onTap: () =>
                              controller.selectMode(DetectionMode.camera),
                          forTesting: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Detection Mode',
                    style: AppTextStyles.heading2(context),
                  ),
                  8.height,
                  Text(
                    'Choose how HyperHitter AI detects your punches during workout sessions.',
                    style: AppTextStyles.bodyMedium(context),
                  ),
                  16.height,

                  // 5 MODE SELECTION CARDS
                  Obx(
                    () => _modeCardRow(
                      context: context,
                      id: DetectionMode.fusion.id,
                      icon: DetectionMode.fusion.icon,
                      title: DetectionMode.fusion.title,
                      subtitle: DetectionMode.fusion.subtitle,
                      isSelected:
                          controller.selectedMode.value == DetectionMode.fusion,
                      onTap: () => controller.selectMode(DetectionMode.fusion),
                    ),
                  ),

                  12.height,
                  Obx(
                    () => _modeCardRow(
                      context: context,
                      id: DetectionMode.audioVibration.id,
                      icon: DetectionMode.audioVibration.icon,
                      title: DetectionMode.audioVibration.title,
                      subtitle: DetectionMode.audioVibration.subtitle,
                      isSelected:
                          controller.selectedMode.value ==
                          DetectionMode.audioVibration,
                      onTap: () =>
                          controller.selectMode(DetectionMode.audioVibration),
                      forTesting: true,
                    ),
                  ),
                  12.height,
                  Obx(
                    () => _modeCardRow(
                      context: context,
                      id: DetectionMode.audio.id,
                      icon: DetectionMode.audio.icon,
                      title: DetectionMode.audio.title,
                      subtitle: DetectionMode.audio.subtitle,
                      isSelected:
                          controller.selectedMode.value == DetectionMode.audio,
                      onTap: () => controller.selectMode(DetectionMode.audio),
                      forTesting: true,
                    ),
                  ),
                  12.height,
                  Obx(
                    () => _modeCardRow(
                      context: context,
                      id: DetectionMode.vibration.id,
                      icon: DetectionMode.vibration.icon,
                      title: DetectionMode.vibration.title,
                      subtitle: DetectionMode.vibration.subtitle,
                      isSelected:
                          controller.selectedMode.value ==
                          DetectionMode.vibration,
                      onTap: () =>
                          controller.selectMode(DetectionMode.vibration),
                      forTesting: true,
                    ),
                  ),
                  12.height,
                  Obx(
                    () => _modeCardRow(
                      context: context,
                      id: DetectionMode.camera.id,
                      icon: DetectionMode.camera.icon,
                      title: DetectionMode.camera.title,
                      subtitle: DetectionMode.camera.subtitle,
                      isSelected:
                          controller.selectedMode.value == DetectionMode.camera,
                      onTap: () => controller.selectMode(DetectionMode.camera),
                      forTesting: true,
                    ),
                  ),

                  const Spacer(),
                  16.height,
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: Size(double.infinity, 54.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    onPressed: controller.nextStep,
                    child: Obx(() {
                      final mode = controller.selectedMode.value;
                      final String label;
                      if (AppConstants.showAllFeatures) {
                        if (mode == DetectionMode.fusion ||
                            mode == DetectionMode.camera) {
                          label = 'Continue to Confirm Camera';
                        } else if (mode == DetectionMode.audio ||
                            mode == DetectionMode.audioVibration) {
                          label = 'Continue to 5s Calibration';
                        } else {
                          label = 'Finish & Launch Session';
                        }
                      } else {
                        if (mode == DetectionMode.fusion ||
                            mode == DetectionMode.audio ||
                            mode == DetectionMode.audioVibration) {
                          label = 'Continue to 5s Calibration';
                        } else {
                          label = 'Finish & Launch Session';
                        }
                      }
                      return Text(
                        label,
                        style: AppTextStyles.buttonLabel(context).copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      );
                    }),
                  ),
                  16.height,
                ],
              ),
            ),
          ),
        );
      },
    );
  }



  // STEP 4: CONFIRM CAMERA / VISION
  Widget _buildStep4ConfirmCamera(BuildContext context) {
    final bool isLandscape = CommonFunction.checkOrientationLandscape(context);

    if (isLandscape) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Header, Description & Button
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirm Camera Framing',
                      style: AppTextStyles.heading2(
                        context,
                      ).copyWith(fontSize: 18.ts(context)),
                    ),
                    6.height,
                    Text(
                      'Position yourself so shoulders and arms are highlighted with tracking lines.',
                      style: AppTextStyles.bodyMedium(
                        context,
                      ).copyWith(fontSize: 11.ts(context)),
                    ),
                    16.height,
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: Size(double.infinity, 44.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      onPressed: controller.nextStep,
                      child: Text(
                        controller.selectedMode.value == DetectionMode.camera
                            ? 'Confirm Camera & Finish Setup'
                            : 'Proceed to 5s Calibration',
                        style: AppTextStyles.buttonLabel(context).copyWith(
                          color: AppColors.ink,
                          fontSize: 12.ts(context),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            16.width,

            // Right Column: Camera Readiness Card
            Expanded(
              flex: 6,
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.videocam,
                        size: 38.w,
                        color: AppColors.primary,
                      ),
                      10.height,
                      Text(
                        'Pose Detection Ready',
                        style: AppTextStyles.heading3(
                          context,
                        ).copyWith(fontSize: 14.ts(context)),
                      ),
                      6.height,
                      Text(
                        'Live ML Kit pose skeleton will automatically overlay your body in real time during session.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium(
                          context,
                        ).copyWith(fontSize: 11.ts(context)),
                      ),
                      10.height,
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10243B),
                          borderRadius: BorderRadius.circular(999.r),
                          border: Border.all(color: AppColors.blue),
                        ),
                        child: Text(
                          'ML Kit Pose Tracking Active',
                          style: TextStyle(
                            color: AppColors.blue,
                            fontSize: 10.ts(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confirm Camera Framing',
                    style: AppTextStyles.heading2(context),
                  ),
                  8.height,
                  Text(
                    'Position yourself so shoulders and arms are highlighted with tracking lines.',
                    style: AppTextStyles.bodyMedium(context),
                  ),
                  20.height,

                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(22.r),
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.videocam,
                          size: 48.w,
                          color: AppColors.primary,
                        ),
                        16.height,
                        Text(
                          'Pose Detection Ready',
                          style: AppTextStyles.heading3(context),
                        ),
                        8.height,
                        Text(
                          'Live ML Kit pose skeleton will automatically overlay your body in real time during session.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium(context),
                        ),
                        14.height,
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10243B),
                            borderRadius: BorderRadius.circular(999.r),
                            border: Border.all(color: AppColors.blue),
                          ),
                          child: Text(
                            'ML Kit Pose Tracking Active',
                            style: TextStyle(
                              color: AppColors.blue,
                              fontSize: 11.ts(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),
                  16.height,
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: Size(double.infinity, 54.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    onPressed: controller.nextStep,
                    child: Text(
                      controller.selectedMode.value == DetectionMode.camera
                          ? 'Confirm Camera & Finish Setup'
                          : 'Proceed to 5s Calibration',
                      style: AppTextStyles.buttonLabel(context).copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  16.height,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // STEP 5: 5-SECOND GYM NOISE CALIBRATION
  /// Shown while the mic reads the bottom of the scale (35 dB) for over 1 s:
  /// the microphone is not delivering audio and calibration would be wrong.
  Widget _buildMicFloorWarning(BuildContext context) {
    return Obx(() {
      if (!controller.isMicAtScaleFloor.value) return const SizedBox.shrink();
      return Container(
        margin: EdgeInsets.only(top: 10.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.amber),
        ),
        child: Row(
          children: [
            Icon(Icons.mic_off, color: AppColors.amber, size: 16.w),
            8.width,
            Expanded(
              child: Text(
                'Microphone is not delivering audio (stuck at '
                '${AppConstants.micScaleFloorDb.round()} dB). Check the mic '
                'permission and that no other app is using the microphone.',
                style: TextStyle(
                  color: AppColors.amber,
                  fontSize: 10.ts(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStep5CalibrateGymNoise(
    BuildContext context, {
    required int stepNumber,
    required int total,
  }) {
    final bool isLandscape = CommonFunction.checkOrientationLandscape(context);

    if (isLandscape) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Header, Description & Calibration Button
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calibrate Gym Noise (5s)',
                      style: AppTextStyles.heading2(
                        context,
                      ).copyWith(fontSize: 18.ts(context)),
                    ),
                    6.height,
                    Text(
                      'Stay quiet for 5 seconds. The engine captures ambient noise floor baseline.',
                      style: AppTextStyles.bodyMedium(
                        context,
                      ).copyWith(fontSize: 11.ts(context)),
                    ),
                    16.height,
                    Obx(
                      () => ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: Size(double.infinity, 44.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        onPressed: controller.isCalibrating.value
                            ? null
                            : controller.start5sCalibration,
                        child: Text(
                          controller.calibrationButtonText.value,
                          style: AppTextStyles.buttonLabel(context).copyWith(
                            color: AppColors.ink,
                            fontSize: 12.ts(context),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            16.width,

            // Right Column: Noise Meter & Calibration Gauge Card
            Expanded(
              flex: 6,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: AppColors.panel,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '5-SECOND NOISE FLOOR SAMPLE',
                            style: AppTextStyles.tag(context),
                          ),
                          6.height,
                          Obx(
                            () => Text(
                              '${controller.decibels.value} dB',
                              style: AppTextStyles.heading1(context).copyWith(
                                fontSize: 28.ts(context),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          10.height,
                          Container(
                            height: 75.h,
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Obx(
                              () => CustomPaint(
                                painter: AudioSpikeWaveformPainter(
                                  decibelSamples: controller.decibelHistory,
                                  thresholdDb: controller.maxCalibratedDb.value,
                                  showThresholdLine: false,
                                ),
                              ),
                            ),
                          ),
                          10.height,
                          Container(
                            height: 10.h,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF202A36),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Obx(
                              () => FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: controller
                                    .calibrationProgress
                                    .value
                                    .clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10.r),
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.blue,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          12.height,
                          Obx(
                            () => Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D2838),
                                borderRadius: BorderRadius.circular(999.r),
                                border: Border.all(
                                  color: const Color(0xFF1C5364),
                                ),
                              ),
                              child: Text(
                                controller.noiseStatusText.value,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10.ts(context),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          _buildMicFloorWarning(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calibrate Gym Noise (5s)',
                    style: AppTextStyles.heading2(context),
                  ),
                  8.height,
                  Text(
                    'Stay quiet for 5 seconds. The engine captures the ambient noise floor baseline.',
                    style: AppTextStyles.bodyMedium(context),
                  ),
                  20.height,

                  Container(
                    padding: EdgeInsets.all(22.r),
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '5-SECOND NOISE FLOOR SAMPLE',
                          style: AppTextStyles.tag(context),
                        ),
                        10.height,
                        Obx(
                          () => Text(
                            '${controller.decibels.value} dB',
                            style: AppTextStyles.heading1(context).copyWith(
                              fontSize: 36.ts(context),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        12.height,
                        Container(
                          height: 100.h,
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Obx(
                            () => CustomPaint(
                              painter: AudioSpikeWaveformPainter(
                                decibelSamples: controller.decibelHistory,
                                thresholdDb: controller.maxCalibratedDb.value,
                                showThresholdLine: false,
                              ),
                            ),
                          ),
                        ),
                        14.height,

                        Container(
                          height: 12.h,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF202A36),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Obx(
                            () => FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: controller.calibrationProgress.value
                                  .clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10.r),
                                  gradient: const LinearGradient(
                                    colors: [AppColors.primary, AppColors.blue],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        16.height,
                        Obx(
                          () => Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 11.w,
                              vertical: 8.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D2838),
                              borderRadius: BorderRadius.circular(999.r),
                              border: Border.all(
                                color: const Color(0xFF1C5364),
                              ),
                            ),
                            child: Text(
                              controller.noiseStatusText.value,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11.ts(context),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        _buildMicFloorWarning(context),
                      ],
                    ),
                  ),
                  const Spacer(),
                  16.height,
                  Obx(
                    () => ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: Size(double.infinity, 54.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      onPressed: controller.isCalibrating.value
                          ? null
                          : controller.start5sCalibration,
                      child: Text(
                        controller.calibrationButtonText.value,
                        style: AppTextStyles.buttonLabel(context).copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  16.height,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Permission Card
  Widget _permissionCard({
    required BuildContext context,
    required String icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44.r,
            height: 44.r,
            decoration: BoxDecoration(
              color: isGranted
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.border.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(icon, style: TextStyle(fontSize: 20.ts(context))),
            ),
          ),
          12.width,
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
          8.width,
          GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46.w,
              height: 26.h,
              padding: EdgeInsets.all(3.r),
              decoration: BoxDecoration(
                color: isGranted ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(999.r),
              ),
              child: Align(
                alignment: isGranted
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
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
          ),
        ],
      ),
    );
  }



  // Full-width Mode Card Row for Detection Modes
  Widget _modeCardRow({
    required BuildContext context,
    required String id,
    required String icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    bool forTesting = false,
    Widget? customBottomWidget,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.selectedBg : AppColors.panel,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2.w : 1.w,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: TextStyle(fontSize: 24.ts(context))),
            14.width,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.heading3(context).copyWith(
                      fontSize: 14.ts(context),
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  4.height,
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium(
                      context,
                    ).copyWith(fontSize: 11.ts(context)),
                  ),
                  ?customBottomWidget,
                  if (forTesting) ...[
                    6.height,
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(
                          color: AppColors.amber.withValues(alpha: 0.5),
                          width: 1.w,
                        ),
                      ),
                      child: Text(
                        'This is only for testing',
                        style: TextStyle(
                          color: AppColors.amber,
                          fontSize: 10.ts(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            8.width,
            Container(
              width: 20.r,
              height: 20.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 2.r,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 14.r, color: AppColors.ink)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Live Device Stability & Motion Badge with dynamic status & toggle switch
  // ignore: unused_element
  Widget _buildDeviceStabilityCard(BuildContext context) {
    return Obx(() {
      final bool isEnabled = controller.isDeviceStabilityEnabled.value;
      final metrics = controller.deviceStabilityMetrics.value;
      final state = metrics.state;

      Color stateColor = AppColors.lime;
      Color borderColor = AppColors.lime.withValues(alpha: 0.5);
      Color bgColor = AppColors.lime.withValues(alpha: 0.12);

      if (!isEnabled) {
        stateColor = AppColors.textMuted;
        borderColor = AppColors.border;
        bgColor = AppColors.panel;
      } else if (state == DeviceStabilityState.unstableHandheld) {
        stateColor = AppColors.red;
        borderColor = AppColors.red.withValues(alpha: 0.6);
        bgColor = AppColors.red.withValues(alpha: 0.15);
      } else if (state == DeviceStabilityState.minorVibration) {
        stateColor = AppColors.amber;
        borderColor = AppColors.amber.withValues(alpha: 0.5);
        bgColor = AppColors.amber.withValues(alpha: 0.12);
      }

      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: borderColor, width: 1.5.w),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.sensors, color: stateColor, size: 20.w),
                      8.width,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Device Stability Check (sensors_plus)',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12.ts(context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            2.height,
                            Text(
                              metrics.statusMessage,
                              style: TextStyle(
                                color: stateColor,
                                fontSize: 10.5.ts(context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  activeThumbColor: AppColors.lime,
                  onChanged: (val) => controller.toggleDeviceStability(val),
                ),
              ],
            ),
            if (isEnabled) ...[
              8.height,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Linear Accel: ${metrics.smoothedLinearAccel.toStringAsFixed(2)} m/s²',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9.5.ts(context),
                    ),
                  ),
                  Text(
                    'Gyro Angular Vel: ${metrics.smoothedAngularVel.toStringAsFixed(2)} rad/s',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9.5.ts(context),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }
}
