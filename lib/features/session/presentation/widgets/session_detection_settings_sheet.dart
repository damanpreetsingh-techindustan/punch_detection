import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/enums/detection_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/common_function.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/utils/size_box.dart';
import '../../domain/services/auto_config_evaluator.dart';
import 'auto_config_dialog.dart';

/// Opens an adaptive, live bottom sheet to adjust Audio, Vibration & Camera detection parameters.
/// Automatically adapts with tailored layouts for Portrait and Landscape orientations.
/// In Landscape, utilizes the full screen width with an executive two-column dashboard layout.
void showSessionDetectionSettingsSheet(
  BuildContext context, {
  required RxDouble staticCalibratedAudioDb,
  required RxDouble customTargetAudioDb,
  required RxDouble minAudioPunchSpikeDb,
  required RxInt audioSampleIntervalMs,
  required List<int> audioIntervalOptions,
  required Function(int) onSetAudioInterval,
  required RxDouble minPunchAudioDb,
  required RxDouble liveBaselineDb,
  required RxDouble liveDecibelLevel,
  required RxDouble minVibrationThreshold,
  required RxDouble liveVibrationMagnitude,
  required RxDouble peakAudioDbRecorded,
  required Function(double) onUpdateVibrationThreshold,
  required RxBool isVisionConfirmationRequired,
  required RxBool isDeviceStabilityEnabled,
  required Function(bool) onToggleDeviceStability,
  required Function({required double spikeDb, required double vibrationMag})
  onApplyEnvironmentPreset,
  required Function(double) onSpikeDbChanged,
  RxDouble? maxCameraDistanceM,
  double? defaultMaxCameraDistanceM,
  Function(double)? onMaxCameraDistanceChanged,
  RxBool? cameraDistanceUnknownIsValid,
  Function(bool)? onToggleCameraDistanceUnknownIsValid,
  Rx<VibrationGateType>? vibrationGateType,
  Function(VibrationGateType)? onSetVibrationGateType,
  RxBool? isBodyMotionGateEnabled,
  Function(bool)? onToggleBodyMotionGate,
  Rx<BodyMotionLevel>? bodyMotionLevel,
  Function(BodyMotionLevel)? onSetBodyMotionLevel,
  RxDouble? bodyMotionMinScore,
  Function(double)? onSetBodyMotionMinScore,
  RxBool? isPersonFocusEnabled,
  Function(bool)? onTogglePersonFocus,
  RxBool? isVibrationDisabled,
  RxBool? isVibrationGateEnabled,
  Function(bool)? onToggleVibrationGate,
  AutoConfigResult Function()? onEvaluateAutoConfig,
  Function(AutoConfigResult)? onApplyAutoConfig,
  VoidCallback? onResetToDefaults,
  VoidCallback? onOpened,
  VoidCallback? onClosed,
}) async {
  onOpened?.call();
  try {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (ctx) => _SessionDetectionSettingsSheetContent(
        staticCalibratedAudioDb: staticCalibratedAudioDb,
        customTargetAudioDb: customTargetAudioDb,
        minAudioPunchSpikeDb: minAudioPunchSpikeDb,
        audioSampleIntervalMs: audioSampleIntervalMs,
        audioIntervalOptions: audioIntervalOptions,
        onSetAudioInterval: onSetAudioInterval,
        minPunchAudioDb: minPunchAudioDb,
        liveBaselineDb: liveBaselineDb,
        liveDecibelLevel: liveDecibelLevel,
        minVibrationThreshold: minVibrationThreshold,
        liveVibrationMagnitude: liveVibrationMagnitude,
        peakAudioDbRecorded: peakAudioDbRecorded,
        onUpdateVibrationThreshold: onUpdateVibrationThreshold,
        isVisionConfirmationRequired: isVisionConfirmationRequired,
        isDeviceStabilityEnabled: isDeviceStabilityEnabled,
        onToggleDeviceStability: onToggleDeviceStability,
        onApplyEnvironmentPreset: onApplyEnvironmentPreset,
        onSpikeDbChanged: onSpikeDbChanged,
        maxCameraDistanceM: maxCameraDistanceM,
        defaultMaxCameraDistanceM: defaultMaxCameraDistanceM,
        onMaxCameraDistanceChanged: onMaxCameraDistanceChanged,
        cameraDistanceUnknownIsValid: cameraDistanceUnknownIsValid,
        onToggleCameraDistanceUnknownIsValid:
            onToggleCameraDistanceUnknownIsValid,
        vibrationGateType: vibrationGateType,
        onSetVibrationGateType: onSetVibrationGateType,
        isBodyMotionGateEnabled: isBodyMotionGateEnabled,
        onToggleBodyMotionGate: onToggleBodyMotionGate,
        bodyMotionLevel: bodyMotionLevel,
        onSetBodyMotionLevel: onSetBodyMotionLevel,
        bodyMotionMinScore: bodyMotionMinScore,
        onSetBodyMotionMinScore: onSetBodyMotionMinScore,
        isPersonFocusEnabled: isPersonFocusEnabled,
        onTogglePersonFocus: onTogglePersonFocus,
        isVibrationDisabled: isVibrationDisabled,
        isVibrationGateEnabled: isVibrationGateEnabled,
        onToggleVibrationGate: onToggleVibrationGate,
        onEvaluateAutoConfig: onEvaluateAutoConfig,
        onApplyAutoConfig: onApplyAutoConfig,
        onResetToDefaults: onResetToDefaults,
        onOpened: onOpened,
        onClosed: onClosed,
      ),
    );
  } finally {
    onClosed?.call();
  }
}

class _SessionDetectionSettingsSheetContent extends StatelessWidget {
  final RxDouble staticCalibratedAudioDb;
  final RxDouble customTargetAudioDb;
  final RxDouble minAudioPunchSpikeDb;
  final RxInt audioSampleIntervalMs;
  final List<int> audioIntervalOptions;
  final Function(int) onSetAudioInterval;
  final RxDouble minPunchAudioDb;
  final RxDouble liveBaselineDb;
  final RxDouble liveDecibelLevel;
  final RxDouble minVibrationThreshold;
  final RxDouble liveVibrationMagnitude;
  final RxDouble peakAudioDbRecorded;
  final Function(double) onUpdateVibrationThreshold;
  final RxBool isVisionConfirmationRequired;
  final RxBool isDeviceStabilityEnabled;
  final Function(bool) onToggleDeviceStability;
  final Function({required double spikeDb, required double vibrationMag})
  onApplyEnvironmentPreset;
  final Function(double) onSpikeDbChanged;
  final RxDouble? maxCameraDistanceM;
  final double? defaultMaxCameraDistanceM;
  final Function(double)? onMaxCameraDistanceChanged;
  final RxBool? cameraDistanceUnknownIsValid;
  final Function(bool)? onToggleCameraDistanceUnknownIsValid;
  final Rx<VibrationGateType>? vibrationGateType;
  final Function(VibrationGateType)? onSetVibrationGateType;
  final RxBool? isBodyMotionGateEnabled;
  final Function(bool)? onToggleBodyMotionGate;
  final Rx<BodyMotionLevel>? bodyMotionLevel;
  final Function(BodyMotionLevel)? onSetBodyMotionLevel;
  final RxDouble? bodyMotionMinScore;
  final Function(double)? onSetBodyMotionMinScore;
  final RxBool? isPersonFocusEnabled;
  final Function(bool)? onTogglePersonFocus;
  final RxBool? isVibrationDisabled;
  final RxBool? isVibrationGateEnabled;
  final Function(bool)? onToggleVibrationGate;
  final AutoConfigResult Function()? onEvaluateAutoConfig;
  final Function(AutoConfigResult)? onApplyAutoConfig;
  final VoidCallback? onResetToDefaults;
  final VoidCallback? onOpened;
  final VoidCallback? onClosed;

  const _SessionDetectionSettingsSheetContent({
    required this.staticCalibratedAudioDb,
    required this.customTargetAudioDb,
    required this.minAudioPunchSpikeDb,
    required this.audioSampleIntervalMs,
    required this.audioIntervalOptions,
    required this.onSetAudioInterval,
    required this.minPunchAudioDb,
    required this.liveBaselineDb,
    required this.liveDecibelLevel,
    required this.minVibrationThreshold,
    required this.liveVibrationMagnitude,
    required this.peakAudioDbRecorded,
    required this.onUpdateVibrationThreshold,
    required this.isVisionConfirmationRequired,
    required this.isDeviceStabilityEnabled,
    required this.onToggleDeviceStability,
    required this.onApplyEnvironmentPreset,
    required this.onSpikeDbChanged,
    this.maxCameraDistanceM,
    this.defaultMaxCameraDistanceM,
    this.onMaxCameraDistanceChanged,
    this.cameraDistanceUnknownIsValid,
    this.onToggleCameraDistanceUnknownIsValid,
    this.vibrationGateType,
    this.onSetVibrationGateType,
    this.isBodyMotionGateEnabled,
    this.onToggleBodyMotionGate,
    this.bodyMotionLevel,
    this.onSetBodyMotionLevel,
    this.bodyMotionMinScore,
    this.onSetBodyMotionMinScore,
    this.isPersonFocusEnabled,
    this.onTogglePersonFocus,
    this.isVibrationDisabled,
    this.isVibrationGateEnabled,
    this.onToggleVibrationGate,
    this.onEvaluateAutoConfig,
    this.onApplyAutoConfig,
    this.onResetToDefaults,
    this.onOpened,
    this.onClosed,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLandscape = CommonFunction.checkOrientationLandscape(context);
    final double sheetHeight =
        MediaQuery.of(context).size.height * (isLandscape ? 0.96 : 0.90);

    return Container(
      width: double.infinity,
      height: sheetHeight,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        border: Border.all(color: AppColors.border, width: 1.5.w),
      ),
      child: Column(
        children: [
          // ─── DRAG HANDLE ───
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(
                top: isLandscape ? 6.h : 10.h,
                bottom: isLandscape ? 4.h : 6.h,
              ),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          // ─── TOP BAR: TITLE + CLOSE BUTTON ───
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 20.w : 16.w,
              vertical: isLandscape ? 4.h : 8.h,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune,
                        color: AppColors.lime,
                        size: isLandscape ? 18.w : 22.w,
                      ),
                      8.width,
                      Expanded(
                        child: Text(
                          'Session Detection Settings',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: isLandscape
                                ? 13.5.ts(context)
                                : 16.ts(context),
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                10.width,
                if (onResetToDefaults != null) ...[
                  GestureDetector(
                    onTap: onResetToDefaults,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isLandscape ? 8.w : 10.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.panel,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            color: AppColors.amber,
                            size: isLandscape ? 12.w : 14.w,
                          ),
                          4.width,
                          Text(
                            'Defaults',
                            style: TextStyle(
                              color: AppColors.amber,
                              fontSize: isLandscape
                                  ? 9.ts(context)
                                  : 10.5.ts(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  8.width,
                ],
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.close,
                    color: AppColors.textMuted,
                    size: isLandscape ? 18.w : 20.w,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(color: AppColors.border, height: 1.h),

          // ─── BODY: ADAPTIVE LAYOUT (PORTRAIT VS LANDSCAPE) ───
          Expanded(
            child: isLandscape
                ? _buildLandscapeLayout(context)
                : _buildPortraitLayout(context),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LANDSCAPE LAYOUT: FULL-WIDTH 2-COLUMN COCKPIT PANELS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildLandscapeLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── LEFT PANEL: AUDIO ENGINE & TARGETS ───
          Expanded(
            flex: 1,
            child: Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: AppColors.lime.withValues(alpha: 0.25),
                  width: 1.w,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAudioHeader(context, isLandscape: true),
                  8.height,
                  _buildAudioGraphLegendCard(context, isLandscape: true),
                  8.height,
                  _buildAudioTargetBanner(context, isLandscape: true),
                  8.height,
                  _buildSpikeThresholdSlider(context, isLandscape: true),
                  8.height,
                  _buildAudioIntervalSelector(context, isLandscape: true),
                ],
              ),
            ),
          ),

          SizedBox(width: 12.w),

          // ─── RIGHT PANEL: PRESETS, VIBRATION & CAMERA ───
          Expanded(
            flex: 1,
            child: Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.7),
                  width: 1.w,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (onEvaluateAutoConfig != null) ...[
                    _buildAutoConfigBanner(context, isLandscape: true),
                    8.height,
                  ],
                  _buildPresetsSection(context, isLandscape: true),
                  10.height,
                  _buildVibrationHeader(context, isLandscape: true),
                  8.height,
                  _buildVibrationTargetBanner(context, isLandscape: true),
                  8.height,
                  _buildVibrationThresholdSlider(context, isLandscape: true),
                  if (vibrationGateType != null) ...[
                    8.height,
                    _buildVibrationGateStrategySelector(
                      context,
                      isLandscape: true,
                    ),
                  ],
                  10.height,
                  _buildCameraHeader(context, isLandscape: true),
                  8.height,
                  _buildVisionConfirmationModeSelector(
                    context,
                    isLandscape: true,
                  ),
                  8.height,
                  if (maxCameraDistanceM != null) ...[
                    _buildCameraDistanceSlider(context, isLandscape: true),
                    8.height,
                  ],
                  if (cameraDistanceUnknownIsValid != null) ...[
                    _buildCameraDistanceUnknownSettingTile(
                      context,
                      isLandscape: true,
                    ),
                    8.height,
                  ],
                  if (isPersonFocusEnabled != null) ...[
                    _buildPersonFocusTile(context, isLandscape: true),
                    8.height,
                  ],
                  if (isBodyMotionGateEnabled != null) ...[
                    _buildBodyMotionGateTile(context, isLandscape: true),
                    8.height,
                  ],
                  _buildDeviceStabilityTile(context, isLandscape: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PORTRAIT LAYOUT: SPACIOUS SINGLE-COLUMN FULL SCROLL
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPortraitLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Auto Configure Intelligence Banner
          if (onEvaluateAutoConfig != null) ...[
            _buildAutoConfigBanner(context, isLandscape: false),
            12.height,
          ],

          // Quick Environment Presets at Top
          _buildPresetsSection(context, isLandscape: false),
          12.height,

          // SECTION 1: AUDIO SENSITIVITY
          _buildAudioHeader(context, isLandscape: false),
          8.height,
          _buildAudioGraphLegendCard(context, isLandscape: false),
          10.height,
          _buildAudioTargetBanner(context, isLandscape: false),
          10.height,
          _buildSpikeThresholdSlider(context, isLandscape: false),
          10.height,
          _buildAudioIntervalSelector(context, isLandscape: false),

          14.height,
          Divider(color: AppColors.border, height: 1.h),
          12.height,

          // SECTION 2: PHYSICAL VIBRATION SENSITIVITY
          _buildVibrationHeader(context, isLandscape: false),
          10.height,
          _buildVibrationTargetBanner(context, isLandscape: false),
          10.height,
          _buildVibrationThresholdSlider(context, isLandscape: false),
          if (vibrationGateType != null) ...[
            10.height,
            _buildVibrationGateStrategySelector(context, isLandscape: false),
          ],

          14.height,
          Divider(color: AppColors.border, height: 1.h),
          12.height,

          // SECTION 3: VIDEO / CAMERA SENSITIVITY
          _buildCameraHeader(context, isLandscape: false),
          10.height,
          _buildVisionConfirmationModeSelector(context, isLandscape: false),
          10.height,
          if (maxCameraDistanceM != null) ...[
            _buildCameraDistanceSlider(context, isLandscape: false),
            10.height,
          ],
          if (cameraDistanceUnknownIsValid != null) ...[
            _buildCameraDistanceUnknownSettingTile(context, isLandscape: false),
            10.height,
          ],
          if (isPersonFocusEnabled != null) ...[
            _buildPersonFocusTile(context, isLandscape: false),
            10.height,
          ],
          if (isBodyMotionGateEnabled != null) ...[
            _buildBodyMotionGateTile(context, isLandscape: false),
            10.height,
          ],
          _buildDeviceStabilityTile(context, isLandscape: false),

          // ─── OPTIONAL: OPEN FULL APP SETTINGS BUTTON (COMMENTED OUT) ───
          // 14.height,
          // ElevatedButton.icon(
          //   style: ElevatedButton.styleFrom(
          //     backgroundColor: AppColors.primary,
          //     minimumSize: Size(double.infinity, 44.h),
          //     shape: RoundedRectangleBorder(
          //       borderRadius: BorderRadius.circular(12.r),
          //     ),
          //   ),
          //   onPressed: () {
          //     Get.back();
          //     AppNavigator.toSettings();
          //   },
          //   icon: Icon(Icons.settings, color: AppColors.ink, size: 18.w),
          //   label: Text(
          //     'Open Full App Settings ⚙️',
          //     style: TextStyle(
          //       color: AppColors.ink,
          //       fontWeight: FontWeight.w900,
          //       fontSize: 12.ts(context),
          //     ),
          //   ),
          // ),
          20.height,
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUTO CONFIGURE BANNER WIDGET
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildAutoConfigBanner(
    BuildContext context, {
    required bool isLandscape,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.cyan.withValues(alpha: 0.16),
            AppColors.panel2.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.cyan.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 10.w : 12.w,
        vertical: isLandscape ? 8.h : 10.h,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isLandscape ? 6.r : 8.r),
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome,
              color: AppColors.cyan,
              size: isLandscape ? 16.w : 18.w,
            ),
          ),
          10.width,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Auto Configure Settings',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: isLandscape ? 10.ts(context) : 11.5.ts(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                2.height,
                Text(
                  'Auto-tune audio, vibration & camera from recent strikes',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: isLandscape ? 8.ts(context) : 9.ts(context),
                  ),
                ),
              ],
            ),
          ),
          8.width,
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyan,
              foregroundColor: Colors.black,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 8.w : 12.w,
                vertical: isLandscape ? 4.h : 6.h,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            onPressed: () {
              if (onEvaluateAutoConfig != null) {
                final result = onEvaluateAutoConfig!();
                showAutoConfigDialog(
                  context,
                  result: result,
                  onApply: onApplyAutoConfig != null
                      ? () => onApplyAutoConfig!(result)
                      : null,
                  onOpened: onOpened,
                  onClosed: onClosed,
                );
              }
            },
            child: Text(
              'Tune',
              style: TextStyle(
                fontSize: isLandscape ? 9.ts(context) : 10.5.ts(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SECTION COMPONENTS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAudioHeader(BuildContext context, {required bool isLandscape}) {
    return Row(
      children: [
        Icon(
          Icons.volume_up,
          color: AppColors.lime,
          size: isLandscape ? 14.w : 16.w,
        ),
        6.width,
        Expanded(
          child: Text(
            'AUDIO SENSITIVITY',
            style: TextStyle(
              color: AppColors.lime,
              fontSize: isLandscape ? 11.ts(context) : 12.ts(context),
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildVibrationHeader(
    BuildContext context, {
    required bool isLandscape,
  }) {
    return Obx(() {
      final bool disabled = isVibrationDisabled?.value ?? false;
      final bool isGateActive = isVibrationGateEnabled?.value ?? !disabled;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.vibration,
                  color: isGateActive
                      ? const Color(0xFFA78BFA)
                      : AppColors.textMuted,
                  size: isLandscape ? 14.w : 16.w,
                ),
                6.width,
                Flexible(
                  child: Text(
                    'PHYSICAL VIBRATION 📳',
                    style: TextStyle(
                      color: isGateActive
                          ? const Color(0xFFA78BFA)
                          : AppColors.textMuted,
                      fontSize: isLandscape ? 11.ts(context) : 12.ts(context),
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                6.width,
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: isGateActive
                        ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                        : AppColors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(
                      color: isGateActive
                          ? const Color(0xFFA78BFA).withValues(alpha: 0.6)
                          : AppColors.amber.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    isGateActive ? 'ACTIVE' : 'DISABLED',
                    style: TextStyle(
                      color: isGateActive
                          ? const Color(0xFFA78BFA)
                          : AppColors.amber,
                      fontSize: isLandscape ? 8.ts(context) : 9.ts(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onToggleVibrationGate != null) ...[
            8.width,
            Transform.scale(
              scale: isLandscape ? 0.72 : 0.80,
              child: Switch(
                value: isGateActive,
                activeThumbColor: const Color(0xFFA78BFA),
                activeTrackColor:
                    const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                inactiveThumbColor: AppColors.textMuted,
                inactiveTrackColor: AppColors.surface,
                onChanged: (bool newVal) {
                  onToggleVibrationGate!(newVal);
                },
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _buildCameraHeader(BuildContext context, {required bool isLandscape}) {
    return Row(
      children: [
        Icon(
          Icons.videocam,
          color: AppColors.blue,
          size: isLandscape ? 14.w : 16.w,
        ),
        6.width,
        Expanded(
          child: Text(
            'VIDEO / CAMERA SENSITIVITY',
            style: TextStyle(
              color: AppColors.blue,
              fontSize: isLandscape ? 11.ts(context) : 12.ts(context),
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ─── QUICK ENVIRONMENT PRESETS ───
  Widget _buildPresetsSection(
    BuildContext context, {
    required bool isLandscape,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Quick Environment Presets',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: isLandscape ? 11.ts(context) : 12.ts(context),
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: isLandscape ? 6.h : 8.h),
        Obx(() {
          final int spike = minAudioPunchSpikeDb.value.round();
          final bool isHighSens =
              spike == EnvironmentPreset.highSensitivity.spikeDb.round();
          final bool isBalanced =
              spike == EnvironmentPreset.balanced.spikeDb.round();
          final bool isStrict =
              spike == EnvironmentPreset.strictGym.spikeDb.round();

          return Row(
            children: [
              // ⚡ High Sens: 6.0 dB spike, 0.30 vibration
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    onApplyEnvironmentPreset(
                      spikeDb: EnvironmentPreset.highSensitivity.spikeDb,
                      vibrationMag:
                          EnvironmentPreset.highSensitivity.vibrationMag,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isHighSens
                        ? AppColors.lime.withValues(alpha: 0.12)
                        : Colors.transparent,
                    side: BorderSide(
                      color: isHighSens ? AppColors.lime : AppColors.border,
                      width: isHighSens ? 1.5 : 1.0,
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: isLandscape ? 6.h : 8.h,
                      horizontal: 2.w,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(
                    '⚡ High Sens\n(+${EnvironmentPreset.highSensitivity.spikeDb.round()} dB spike)',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isHighSens
                          ? AppColors.lime
                          : AppColors.textPrimary,
                      fontSize: isLandscape ? 8.5.ts(context) : 9.5.ts(context),
                      fontWeight: isHighSens
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              6.width,
              // ⚖️ Balanced: 8.0 dB spike, 0.50 vibration (Selected by Default)
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    onApplyEnvironmentPreset(
                      spikeDb: EnvironmentPreset.balanced.spikeDb,
                      vibrationMag: EnvironmentPreset.balanced.vibrationMag,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isBalanced
                        ? AppColors.lime.withValues(alpha: 0.12)
                        : Colors.transparent,
                    side: BorderSide(
                      color: isBalanced ? AppColors.lime : AppColors.border,
                      width: isBalanced ? 1.5 : 1.0,
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: isLandscape ? 6.h : 8.h,
                      horizontal: 2.w,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(
                    '⚖️ Balanced\n(+${EnvironmentPreset.balanced.spikeDb.round()} dB spike)',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isBalanced
                          ? AppColors.lime
                          : AppColors.textPrimary,
                      fontSize: isLandscape ? 8.5.ts(context) : 9.5.ts(context),
                      fontWeight: isBalanced
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              6.width,
              // 🥊 Strict: 15.0 dB spike, 0.80 vibration
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    onApplyEnvironmentPreset(
                      spikeDb: EnvironmentPreset.strictGym.spikeDb,
                      vibrationMag: EnvironmentPreset.strictGym.vibrationMag,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isStrict
                        ? AppColors.lime.withValues(alpha: 0.12)
                        : Colors.transparent,
                    side: BorderSide(
                      color: isStrict ? AppColors.lime : AppColors.border,
                      width: isStrict ? 1.5 : 1.0,
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: isLandscape ? 6.h : 8.h,
                      horizontal: 2.w,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(
                    '🥊 Strict\n(+${EnvironmentPreset.strictGym.spikeDb.round()} dB spike)',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isStrict ? AppColors.lime : AppColors.textPrimary,
                      fontSize: isLandscape ? 8.5.ts(context) : 9.5.ts(context),
                      fontWeight: isStrict
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ─── DUAL-LINE WAVEFORM GRAPH LEGEND CARD ───
  Widget _buildAudioGraphLegendCard(
    BuildContext context, {
    required bool isLandscape,
  }) {
    return Obx(
      () => Container(
        width: double.infinity,
        padding: EdgeInsets.all(isLandscape ? 8.r : 12.r),
        decoration: BoxDecoration(
          color: const Color(0xFF070D18),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AUDIO GRAPH REFERENCE LINES',
              style: AppTextStyles.tag(context).copyWith(
                fontSize: isLandscape ? 8.ts(context) : 9.ts(context),
                color: AppColors.cyan,
              ),
            ),
            SizedBox(height: isLandscape ? 4.h : 8.h),
            Row(
              children: [
                Container(
                  width: 16.w,
                  height: 2.5.h,
                  color: const Color(0xFF00E5FF), // Cyan
                ),
                8.width,
                Expanded(
                  child: Text(
                    'Static Calibration Line: ${staticCalibratedAudioDb.value.round()} dB',
                    style: TextStyle(
                      color: const Color(0xFF00E5FF),
                      fontSize: isLandscape ? 9.5.ts(context) : 11.ts(context),
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            2.height,
            Text(
              'Fixed baseline recorded during 5-second precheck calibration.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: isLandscape ? 8.ts(context) : 9.ts(context),
              ),
            ),
            SizedBox(height: isLandscape ? 4.h : 8.h),
            Row(
              children: [
                Container(
                  width: 16.w,
                  height: 2.5.h,
                  color: const Color(0xFF1AFF00), // Lime Green
                ),
                8.width,
                Expanded(
                  child: Text(
                    'Audio Target Line: ${(customTargetAudioDb.value > 0 ? customTargetAudioDb.value : staticCalibratedAudioDb.value + minAudioPunchSpikeDb.value).round()} dB',
                    style: TextStyle(
                      color: const Color(0xFF1AFF00),
                      fontSize: isLandscape ? 9.5.ts(context) : 11.ts(context),
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            2.height,
            Text(
              'Current punch threshold: ${staticCalibratedAudioDb.value.round()} dB Base ${minAudioPunchSpikeDb.value.round() >= 0 ? '+ ' : ''}${minAudioPunchSpikeDb.value.round()} dB Spike.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: isLandscape ? 8.ts(context) : 9.ts(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── LIVE AUDIO TARGET BANNER (ABOVE SPIKE THRESHOLD SLIDER) ───
  Widget _buildAudioTargetBanner(
    BuildContext context, {
    required bool isLandscape,
  }) {
    return Obx(() {
      final double targetAudioDb = customTargetAudioDb.value > 0
          ? customTargetAudioDb.value
          : (staticCalibratedAudioDb.value + minAudioPunchSpikeDb.value);
      final double liveDb = liveDecibelLevel.value;
      final double peakDb = peakAudioDbRecorded.value;
      final bool isTriggered = liveDb >= targetAudioDb;

      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 10.w : 12.w,
          vertical: isLandscape ? 6.h : 8.h,
        ),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isTriggered
                ? AppColors.lime
                : AppColors.lime.withValues(alpha: 0.35),
            width: 1.w,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.ads_click,
                        color: AppColors.lime,
                        size: isLandscape ? 12.w : 14.w,
                      ),
                      5.width,
                      Expanded(
                        child: Text(
                          'PUNCH AUDIO TARGET',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: isLandscape
                                ? 8.ts(context)
                                : 9.ts(context),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  2.height,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '≥ ${targetAudioDb.round()}',
                        style: TextStyle(
                          color: AppColors.lime,
                          fontSize: isLandscape
                              ? 15.ts(context)
                              : 18.ts(context),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      3.width,
                      Text(
                        'dB',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: isLandscape
                              ? 9.ts(context)
                              : 11.ts(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            8.width,
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 6.w : 8.w,
                    vertical: 2.5.h,
                  ),
                  decoration: BoxDecoration(
                    color: isTriggered
                        ? AppColors.lime.withValues(alpha: 0.2)
                        : AppColors.panel,
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(
                      color: isTriggered ? AppColors.lime : AppColors.border,
                    ),
                  ),
                  child: Text(
                    'Live: ${liveDb.round()} dB',
                    style: TextStyle(
                      color: isTriggered
                          ? AppColors.lime
                          : AppColors.textPrimary,
                      fontSize: isLandscape ? 8.5.ts(context) : 10.ts(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                3.height,
                Text(
                  'Peak: ${peakDb.round()} dB',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: isLandscape ? 8.ts(context) : 9.ts(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  // ─── SPIKE THRESHOLD SLIDER ───
  Widget _buildSpikeThresholdSlider(
    BuildContext context, {
    required bool isLandscape,
  }) {
    return Obx(() {
      final int spikeVal = minAudioPunchSpikeDb.value.round();
      final String spikeLabel =
          spikeVal > 0 ? '+$spikeVal dB' : '$spikeVal dB';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Spike Threshold (Above Environment)',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: isLandscape ? 10.5.ts(context) : 12.ts(context),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              8.width,
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 8.w : 10.w,
                  vertical: 2.5.h,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lime.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppColors.lime),
                ),
                child: Text(
                  spikeLabel,
                  style: TextStyle(
                    color: AppColors.lime,
                    fontSize: isLandscape ? 11.ts(context) : 13.ts(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          3.height,
          Text(
            spikeVal >= 0
                ? 'Extra dB added to calibrated base audio (${staticCalibratedAudioDb.value.round()} dB) to set the audio target.'
                : 'Offset subtracted from calibrated base audio (${staticCalibratedAudioDb.value.round()} dB) to set the audio target.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: isLandscape ? 8.5.ts(context) : 9.5.ts(context),
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: isLandscape ? 2.5.h : 3.5.h,
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: isLandscape ? 6.r : 8.r,
              ),
            ),
            child: Slider(
              value: minAudioPunchSpikeDb.value.clamp(
                AppConstants.minAudioSpikeSliderDb,
                AppConstants.maxAudioSpikeSliderDb,
              ),
              min: AppConstants.minAudioSpikeSliderDb,
              max: AppConstants.maxAudioSpikeSliderDb,
              divisions:
                  (AppConstants.maxAudioSpikeSliderDb -
                          AppConstants.minAudioSpikeSliderDb)
                      .round(),
              activeColor: AppColors.lime,
              inactiveColor: AppColors.border,
              label: spikeLabel,
              onChanged: (double value) => onSpikeDbChanged(value),
            ),
          ),
        ],
      );
    });
  }

  // ─── AUDIO CAPTURE INTERVAL SELECTOR ───
  Widget _buildAudioIntervalSelector(
    BuildContext context, {
    required bool isLandscape,
  }) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Audio Capture Interval',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: isLandscape ? 10.5.ts(context) : 12.ts(context),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              8.width,
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 8.w : 10.w,
                  vertical: 2.5.h,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lime.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppColors.lime),
                ),
                child: Text(
                  '${audioSampleIntervalMs.value} ms (${(1000 / audioSampleIntervalMs.value).round()} Hz)',
                  style: TextStyle(
                    color: AppColors.lime,
                    fontSize: isLandscape ? 10.ts(context) : 12.ts(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          3.height,
          Text(
            'Microphone hardware sampling rate. 3ms (333 Hz) or 5ms (200 Hz) provides ultra-fast sampling.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: isLandscape ? 8.5.ts(context) : 9.5.ts(context),
            ),
          ),
          SizedBox(height: isLandscape ? 4.h : 8.h),
          Wrap(
            spacing: 5.w,
            runSpacing: 4.h,
            children: audioIntervalOptions.map((int ms) {
              final bool isSelected = audioSampleIntervalMs.value == ms;
              return GestureDetector(
                onTap: () => onSetAudioInterval(ms),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 7.w : 9.w,
                    vertical: isLandscape ? 3.h : 5.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.lime.withValues(alpha: 0.25)
                        : AppColors.panel,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: isSelected ? AppColors.lime : AppColors.border,
                      width: isSelected ? 1.5.w : 1.w,
                    ),
                  ),
                  child: Text(
                    '${ms}ms',
                    style: TextStyle(
                      color: isSelected ? AppColors.lime : AppColors.textMuted,
                      fontSize: isLandscape ? 9.5.ts(context) : 11.ts(context),
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── LIVE VIBRATION TARGET BANNER (ABOVE IMPACT SENSITIVITY SLIDER) ───
  Widget _buildVibrationTargetBanner(
    BuildContext context, {
    required bool isLandscape,
  }) {
    return Obx(() {
      final bool disabled = isVibrationDisabled?.value ?? false;
      if (disabled) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 10.w : 12.w,
            vertical: isLandscape ? 6.h : 8.h,
          ),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(
                Icons.portable_wifi_off,
                color: AppColors.amber,
                size: isLandscape ? 16.w : 18.w,
              ),
              8.width,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VIBRATION DETECTION DISABLED',
                      style: TextStyle(
                        color: AppColors.amber,
                        fontSize: isLandscape ? 9.ts(context) : 10.ts(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    2.height,
                    Text(
                      'Vibration check bypassed. Punches detected via Audio + Camera (Audio fallback if Camera off).',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: isLandscape ? 8.ts(context) : 9.ts(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      final double targetVibe = minVibrationThreshold.value;
      final double liveVibe = liveVibrationMagnitude.value;
      final bool isTriggered = liveVibe >= targetVibe;

      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 10.w : 12.w,
          vertical: isLandscape ? 6.h : 8.h,
        ),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isTriggered
                ? const Color(0xFFA78BFA)
                : const Color(0xFFA78BFA).withValues(alpha: 0.35),
            width: 1.w,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.vibration,
                        color: const Color(0xFFA78BFA),
                        size: isLandscape ? 12.w : 14.w,
                      ),
                      5.width,
                      Expanded(
                        child: Text(
                          'PUNCH VIBRATION TARGET',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: isLandscape
                                ? 8.ts(context)
                                : 9.ts(context),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  2.height,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '≥ ${targetVibe.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: const Color(0xFFA78BFA),
                          fontSize: isLandscape
                              ? 15.ts(context)
                              : 18.ts(context),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      3.width,
                      Text(
                        'm/s²',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: isLandscape
                              ? 9.ts(context)
                              : 11.ts(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            8.width,
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 6.w : 8.w,
                vertical: 4.h,
              ),
              decoration: BoxDecoration(
                color: isTriggered
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.25)
                    : AppColors.panel,
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(
                  color: isTriggered
                      ? const Color(0xFFA78BFA)
                      : AppColors.border,
                ),
              ),
              child: Text(
                'Live: ${liveVibe.toStringAsFixed(2)} m/s²',
                style: TextStyle(
                  color: isTriggered
                      ? const Color(0xFFA78BFA)
                      : AppColors.textPrimary,
                  fontSize: isLandscape ? 8.5.ts(context) : 10.ts(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ─── IMPACT SENSITIVITY THRESHOLD SLIDER ───
  Widget _buildVibrationThresholdSlider(
    BuildContext context, {
    required bool isLandscape,
  }) {
    return Obx(() {
      final bool disabled = isVibrationDisabled?.value ?? false;
      return Opacity(
        opacity: disabled ? 0.45 : 1.0,
        child: IgnorePointer(
          ignoring: disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Impact Sensitivity Threshold',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize:
                            isLandscape ? 10.5.ts(context) : 12.ts(context),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  8.width,
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 8.w : 10.w,
                      vertical: 2.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: disabled
                          ? AppColors.panel
                          : const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: disabled
                            ? AppColors.border
                            : const Color(0xFFA78BFA),
                      ),
                    ),
                    child: Text(
                      disabled
                          ? 'OFF'
                          : '${minVibrationThreshold.value.toStringAsFixed(2)} m/s²',
                      style: TextStyle(
                        color: disabled
                            ? AppColors.textMuted
                            : const Color(0xFFA78BFA),
                        fontSize: isLandscape ? 11.ts(context) : 13.ts(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              3.height,
              Text(
                disabled
                    ? 'Vibration detection is disabled. Turn ON toggle switch above to re-enable physical shockwave tracking.'
                    : 'Minimum physical shockwave acceleration required on phone mount (Live: ${liveVibrationMagnitude.value.toStringAsFixed(2)} m/s²).',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: isLandscape ? 8.5.ts(context) : 9.5.ts(context),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: isLandscape ? 2.5.h : 3.5.h,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: isLandscape ? 6.r : 8.r,
                  ),
                ),
                child: Slider(
                  value: minVibrationThreshold.value.clamp(
                    AppConstants.minImpactVibrationSlider,
                    AppConstants.maxImpactVibrationSlider,
                  ),
                  min: AppConstants.minImpactVibrationSlider,
                  max: AppConstants.maxImpactVibrationSlider,
                  divisions:
                      ((AppConstants.maxImpactVibrationSlider -
                                  AppConstants.minImpactVibrationSlider) *
                              100)
                          .round(),
                  activeColor: disabled
                      ? AppColors.textMuted
                      : const Color(0xFFA78BFA),
                  inactiveColor: AppColors.border,
                  label:
                      '${minVibrationThreshold.value.toStringAsFixed(2)} m/s²',
                  onChanged: (double value) =>
                      onUpdateVibrationThreshold(value),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ─── VIBRATION GATE STRATEGY SELECTOR ───
  Widget _buildVibrationGateStrategySelector(
    BuildContext context, {
    required bool isLandscape,
  }) {
    if (vibrationGateType == null) return const SizedBox.shrink();

    return Obx(() {
      final bool disabled = isVibrationDisabled?.value ?? false;
      final VibrationGateType currentType = vibrationGateType!.value;
      final bool isKnock = currentType == VibrationGateType.knock;

      return Opacity(
        opacity: disabled ? 0.45 : 1.0,
        child: IgnorePointer(
          ignoring: disabled,
          child: Container(
            padding: EdgeInsets.all(isLandscape ? 8.w : 10.w),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title takes the space left by the badge and shrinks with
                    // "…" on narrow sheets instead of overflowing the row.
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            color: const Color(0xFFA78BFA),
                            size: isLandscape ? 15.w : 18.w,
                          ),
                          6.width,
                          Flexible(
                            child: Text(
                              'Vibration Gate Strategy',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: isLandscape
                                    ? 10.5.ts(context)
                                    : 12.ts(context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    6.width,
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isLandscape ? 6.w : 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: isKnock
                            ? AppColors.lime.withValues(alpha: 0.15)
                            : AppColors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6.r),
                        border: Border.all(
                          color: isKnock ? AppColors.lime : AppColors.amber,
                          width: 1.w,
                        ),
                      ),
                      child: Text(
                        isKnock ? 'RECOMMENDED' : 'LEGACY',
                        style: TextStyle(
                          color: isKnock ? AppColors.lime : AppColors.amber,
                          fontSize:
                              isLandscape ? 7.5.ts(context) : 8.5.ts(context),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                8.height,
                Row(
                  children: [
                    // Option 1: Fresh Knock (Jerk Delta)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onSetVibrationGateType?.call(
                          VibrationGateType.knock,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: EdgeInsets.symmetric(
                            horizontal: isLandscape ? 8.w : 10.w,
                            vertical: isLandscape ? 6.h : 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: isKnock
                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.2)
                                : AppColors.panel,
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: isKnock
                                  ? const Color(0xFFA78BFA)
                                  : AppColors.border,
                              width: isKnock ? 1.5.w : 1.w,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: isLandscape ? 14.w : 16.w,
                                    height: isLandscape ? 14.w : 16.w,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isKnock
                                            ? const Color(0xFFA78BFA)
                                            : AppColors.border,
                                        width: 2.w,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: isKnock
                                        ? Container(
                                            width: isLandscape ? 7.w : 8.w,
                                            height: isLandscape ? 7.w : 8.w,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(0xFFA78BFA),
                                            ),
                                          )
                                        : null,
                                  ),
                                  6.width,
                                  Expanded(
                                    child: Text(
                                      'Fresh Knock',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: isLandscape
                                            ? 10.ts(context)
                                            : 11.5.ts(context),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              3.height,
                              Text(
                                'Jerk Δ ≥ 0.15 m/s²',
                                style: TextStyle(
                                  color: isKnock
                                      ? const Color(0xFFA78BFA)
                                      : AppColors.textMuted,
                                  fontSize: isLandscape
                                      ? 8.ts(context)
                                      : 9.ts(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    8.width,
                    // Option 2: Legacy Peak Threshold
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onSetVibrationGateType?.call(
                          VibrationGateType.peakThreshold,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: EdgeInsets.symmetric(
                            horizontal: isLandscape ? 8.w : 10.w,
                            vertical: isLandscape ? 6.h : 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: !isKnock
                                ? AppColors.amber.withValues(alpha: 0.15)
                                : AppColors.panel,
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: !isKnock
                                  ? AppColors.amber
                                  : AppColors.border,
                              width: !isKnock ? 1.5.w : 1.w,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: isLandscape ? 14.w : 16.w,
                                    height: isLandscape ? 14.w : 16.w,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: !isKnock
                                            ? AppColors.amber
                                            : AppColors.border,
                                        width: 2.w,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: !isKnock
                                        ? Container(
                                            width: isLandscape ? 7.w : 8.w,
                                            height: isLandscape ? 7.w : 8.w,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.amber,
                                            ),
                                          )
                                        : null,
                                  ),
                                  6.width,
                                  Expanded(
                                    child: Text(
                                      'Legacy Peak',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: isLandscape
                                            ? 10.ts(context)
                                            : 11.5.ts(context),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              3.height,
                              Text(
                                'Envelope Threshold',
                                style: TextStyle(
                                  color: !isKnock
                                      ? AppColors.amber
                                      : AppColors.textMuted,
                                  fontSize: isLandscape
                                      ? 8.ts(context)
                                      : 9.ts(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                8.height,
                // Informational container on how it works
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 8.w : 10.w,
                    vertical: isLandscape ? 6.h : 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.panel.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: isKnock
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.25)
                          : AppColors.amber.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isKnock
                            ? Icons.info_outline_rounded
                            : Icons.warning_amber_rounded,
                        color: isKnock
                            ? const Color(0xFFA78BFA)
                            : AppColors.amber,
                        size: isLandscape ? 13.w : 15.w,
                      ),
                      6.width,
                      Expanded(
                        child: Text(
                          isKnock
                              ? 'How it works: Detects sudden sample-to-sample jerk (Δ ≥ 0.15 m/s²) on raw 50Hz sensor data. It ignores smooth bag swing pendulum motion (averaging 0.24 m/s²), eliminates false punch counts from loud gym talking while bag is swinging, and enables rapid combos (120–160ms apart).'
                              : 'How it works: Triggers whenever the smoothed vibration envelope exceeds the threshold. Note: After hard punches, heavy bag swings above threshold for 2–3s, which can cause loud voices to falsely register as punches during swings.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize:
                                isLandscape ? 7.8.ts(context) : 9.ts(context),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }


  // ─── VISION CONFIRMATION MODE SELECTOR ───
  Widget _buildVisionConfirmationModeSelector(
    BuildContext context, {
    required bool isLandscape,
  }) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Vision Confirmation Mode',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: isLandscape ? 10.5.ts(context) : 12.ts(context),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              8.width,
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 8.w : 10.w,
                  vertical: 2.5.h,
                ),
                decoration: BoxDecoration(
                  color: isVisionConfirmationRequired.value
                      ? AppColors.blue.withValues(alpha: 0.2)
                      : AppColors.lime.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: isVisionConfirmationRequired.value
                        ? AppColors.blue
                        : AppColors.lime,
                  ),
                ),
                child: Text(
                  isVisionConfirmationRequired.value
                      ? 'Strict (Required)'
                      : 'Flexible (Optional)',
                  style: TextStyle(
                    color: isVisionConfirmationRequired.value
                        ? AppColors.blue
                        : AppColors.lime,
                    fontSize: isLandscape ? 9.5.ts(context) : 11.ts(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          3.height,
          Text(
            'If Required: Punches count ONLY when camera confirms motion. If Optional: Audio+Vibration dual impacts count even if camera does not confirm.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: isLandscape ? 8.5.ts(context) : 9.5.ts(context),
            ),
          ),
          SizedBox(height: isLandscape ? 4.h : 8.h),
          Row(
            children: [
              // Option 1: Optional
              Expanded(
                child: GestureDetector(
                  onTap: () => isVisionConfirmationRequired.value = false,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 8.w : 10.w,
                      vertical: isLandscape ? 5.h : 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: !isVisionConfirmationRequired.value
                          ? AppColors.lime.withValues(alpha: 0.15)
                          : AppColors.panel,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: !isVisionConfirmationRequired.value
                            ? AppColors.lime
                            : AppColors.border,
                        width: !isVisionConfirmationRequired.value
                            ? 1.5.w
                            : 1.w,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: isLandscape ? 14.w : 18.w,
                          height: isLandscape ? 14.w : 18.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: !isVisionConfirmationRequired.value
                                  ? AppColors.lime
                                  : AppColors.border,
                              width: 2.w,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: !isVisionConfirmationRequired.value
                              ? Container(
                                  width: isLandscape ? 7.w : 9.w,
                                  height: isLandscape ? 7.w : 9.w,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.lime,
                                  ),
                                )
                              : null,
                        ),
                        6.width,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Disable',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: isLandscape
                                      ? 10.ts(context)
                                      : 11.5.ts(context),
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Dual impact fallback',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: isLandscape
                                      ? 7.5.ts(context)
                                      : 8.5.ts(context),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              6.width,
              // Option 2: Required
              Expanded(
                child: GestureDetector(
                  onTap: () => isVisionConfirmationRequired.value = true,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 8.w : 10.w,
                      vertical: isLandscape ? 5.h : 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: isVisionConfirmationRequired.value
                          ? AppColors.blue.withValues(alpha: 0.15)
                          : AppColors.panel,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: isVisionConfirmationRequired.value
                            ? AppColors.blue
                            : AppColors.border,
                        width: isVisionConfirmationRequired.value ? 1.5.w : 1.w,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: isLandscape ? 14.w : 18.w,
                          height: isLandscape ? 14.w : 18.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isVisionConfirmationRequired.value
                                  ? AppColors.blue
                                  : AppColors.border,
                              width: 2.w,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: isVisionConfirmationRequired.value
                              ? Container(
                                  width: isLandscape ? 7.w : 9.w,
                                  height: isLandscape ? 7.w : 9.w,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.blue,
                                  ),
                                )
                              : null,
                        ),
                        6.width,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Required',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: isLandscape
                                      ? 10.ts(context)
                                      : 11.5.ts(context),
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Strict camera lock',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: isLandscape
                                      ? 7.5.ts(context)
                                      : 8.5.ts(context),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── MAX CAMERA DISTANCE SLIDER ───
  Widget _buildCameraDistanceSlider(
    BuildContext context, {
    required bool isLandscape,
  }) {
    return Obx(() {
      final double metres = maxCameraDistanceM!.value;
      final double? defaultMetres = defaultMaxCameraDistanceM;
      final bool isDefault =
          defaultMetres == null || (metres - defaultMetres).abs() < 0.05;
      final bool disabled = !isVisionConfirmationRequired.value;
      final String metresLabel = '≈ ${metres.toStringAsFixed(1)} m';

      return Opacity(
        opacity: disabled ? 0.45 : 1.0,
        child: IgnorePointer(
          ignoring: disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Max Camera Distance',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize:
                            isLandscape ? 10.5.ts(context) : 12.ts(context),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isDefault) ...[
                    GestureDetector(
                      onTap: () =>
                          onMaxCameraDistanceChanged?.call(defaultMetres),
                      child: Text(
                        'Reset',
                        style: TextStyle(
                          color: AppColors.amber,
                          fontSize:
                              isLandscape ? 9.ts(context) : 10.5.ts(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    8.width,
                  ],
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 8.w : 10.w,
                      vertical: 2.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: disabled
                          ? AppColors.panel
                          : AppColors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: disabled ? AppColors.border : AppColors.blue,
                      ),
                    ),
                    child: Text(
                      disabled ? 'OFF' : metresLabel,
                      style: TextStyle(
                        color: disabled ? AppColors.textMuted : AppColors.blue,
                        fontSize: isLandscape ? 11.ts(context) : 13.ts(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              3.height,
              Text(
                disabled
                    ? 'Camera confirmation is disabled, so distance is not checked.'
                    : 'Camera counts a punch only when you stand within this distance. Lower = stand closer. '
                          'Default ≈ ${(defaultMetres ?? metres).toStringAsFixed(1)} m (approximate, depends on camera lens).',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: isLandscape ? 8.5.ts(context) : 9.5.ts(context),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: isLandscape ? 2.5.h : 3.5.h,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: isLandscape ? 6.r : 8.r,
                  ),
                ),
                child: Slider(
                  value: metres.clamp(
                    AppConstants.minCameraDistanceSliderM,
                    AppConstants.maxCameraDistanceSliderM,
                  ),
                  min: AppConstants.minCameraDistanceSliderM,
                  max: AppConstants.maxCameraDistanceSliderM,
                  divisions:
                      ((AppConstants.maxCameraDistanceSliderM -
                                  AppConstants.minCameraDistanceSliderM) *
                              10)
                          .round(),
                  activeColor: disabled ? AppColors.textMuted : AppColors.blue,
                  inactiveColor: AppColors.border,
                  label: metresLabel,
                  onChanged: (double value) =>
                      onMaxCameraDistanceChanged?.call(value),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ─── CAMERA DISTANCE SIDE-PROFILE / UNKNOWN STANCE TILE ───
  Widget _buildCameraDistanceUnknownSettingTile(
    BuildContext context, {
    required bool isLandscape,
  }) {
    if (cameraDistanceUnknownIsValid == null) return const SizedBox.shrink();

    return Obx(() {
      final bool disabled = !isVisionConfirmationRequired.value;
      final bool allowSideProfile = cameraDistanceUnknownIsValid!.value;

      return Opacity(
        opacity: disabled ? 0.45 : 1.0,
        child: IgnorePointer(
          ignoring: disabled,
          child: Container(
            margin: EdgeInsets.symmetric(vertical: isLandscape ? 2.h : 6.h),
            padding: EdgeInsets.all(isLandscape ? 8.w : 10.w),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: allowSideProfile && !disabled
                    ? AppColors.blue.withValues(alpha: 0.5)
                    : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.sports_mma_rounded,
                            color: AppColors.blue,
                            size: isLandscape ? 15.w : 18.w,
                          ),
                          6.width,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Allow Side-Profile / Hook Stance',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: isLandscape
                                        ? 10.5.ts(context)
                                        : 12.ts(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                1.5.height,
                                Text(
                                  allowSideProfile
                                      ? 'ENABLED — Side-angle & single-shoulder punches allowed'
                                      : 'STRICT — Requires both shoulders visible to measure span',
                                  style: TextStyle(
                                    color: allowSideProfile
                                        ? AppColors.lime
                                        : AppColors.textMuted,
                                    fontSize: isLandscape
                                        ? 7.8.ts(context)
                                        : 9.ts(context),
                                    fontWeight: allowSideProfile
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: isLandscape ? 0.75 : 0.85,
                      child: Switch(
                        value: allowSideProfile,
                        activeThumbColor: AppColors.blue,
                        onChanged: (bool value) =>
                            onToggleCameraDistanceUnknownIsValid?.call(value),
                      ),
                    ),
                  ],
                ),
                6.height,
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 8.w : 10.w,
                    vertical: isLandscape ? 5.h : 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.panel.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: AppColors.blue.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.blue,
                        size: isLandscape ? 13.w : 15.w,
                      ),
                      6.width,
                      Expanded(
                        child: Text(
                          disabled
                              ? 'Camera confirmation is disabled, so distance check is inactive.'
                              : 'How it works: When turning into side stance or throwing hooks, your rear shoulder is occluded from the camera. In STRICT mode, ML Kit cannot measure dual-shoulder span and rejects valid punches as "too far". Enabling this allows side punches while still protecting against background people via person size ratio, audio sync, and bag vibration knock.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize:
                                isLandscape ? 7.8.ts(context) : 9.ts(context),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ─── NEAREST-PERSON FOCUS TILE ───
  // Switch: ON = with several people in view the camera follows the closest
  // one. Always active (camera-only mode uses the pose too), unlike the tiles
  // that depend on camera confirmation.
  Widget _buildPersonFocusTile(
    BuildContext context, {
    required bool isLandscape,
  }) {
    if (isPersonFocusEnabled == null) return const SizedBox.shrink();

    return Obx(() {
      final bool enabled = isPersonFocusEnabled!.value;

      return Container(
        margin: EdgeInsets.symmetric(vertical: isLandscape ? 2.h : 6.h),
        padding: EdgeInsets.all(isLandscape ? 8.w : 10.w),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: enabled
                ? AppColors.blue.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_pin_circle_rounded,
                        color: AppColors.blue,
                        size: isLandscape ? 15.w : 18.w,
                      ),
                      6.width,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Focus on Nearest Person',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: isLandscape
                                    ? 10.5.ts(context)
                                    : 12.ts(context),
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            1.5.height,
                            Text(
                              enabled
                                  ? 'ENABLED — Skeleton follows the closest person when several are in view'
                                  : 'OFF — Camera follows whoever it detects first',
                              style: TextStyle(
                                color: enabled
                                    ? AppColors.lime
                                    : AppColors.textMuted,
                                fontSize: isLandscape
                                    ? 7.8.ts(context)
                                    : 9.ts(context),
                                fontWeight: enabled
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: isLandscape ? 0.75 : 0.85,
                  child: Switch(
                    value: enabled,
                    activeThumbColor: AppColors.blue,
                    onChanged: (bool value) => onTogglePersonFocus?.call(value),
                  ),
                ),
              ],
            ),
            6.height,
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 8.w : 10.w,
                vertical: isLandscape ? 5.h : 6.h,
              ),
              decoration: BoxDecoration(
                color: AppColors.panel.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: AppColors.blue.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.blue,
                    size: isLandscape ? 13.w : 15.w,
                  ),
                  6.width,
                  Expanded(
                    child: Text(
                      'Uses face detection to find the closest person and hides everyone else from the pose tracker. With one person in view nothing changes. Turn off if the camera loses you when your face is hidden.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: isLandscape ? 7.8.ts(context) : 9.ts(context),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  // ─── BODY-MOTION GATE TILE ───
  // Switch: ON = an impact only counts when the user's upper body moved.
  // Level chips (Easy / Normal / Strict) = how much movement is needed.
  // Inactive (dimmed) when camera confirmation is off, like the other camera
  // settings, because the check needs the camera.
  Widget _buildBodyMotionGateTile(
    BuildContext context, {
    required bool isLandscape,
  }) {
    if (isBodyMotionGateEnabled == null) return const SizedBox.shrink();

    return Obx(() {
      final bool disabled = !isVisionConfirmationRequired.value;
      final bool enabled = isBodyMotionGateEnabled!.value;
      final BodyMotionLevel level =
          bodyMotionLevel?.value ?? AppConstants.bodyMotionLevel;
      // Live value (preset or slider); falls back to the preset value.
      final double minScore =
          bodyMotionMinScore?.value ?? AppConstants.bodyMotionMinScore(level);

      return Opacity(
        opacity: disabled ? 0.45 : 1.0,
        child: IgnorePointer(
          ignoring: disabled,
          child: Container(
            margin: EdgeInsets.symmetric(vertical: isLandscape ? 2.h : 6.h),
            padding: EdgeInsets.all(isLandscape ? 8.w : 10.w),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: enabled && !disabled
                    ? AppColors.lime.withValues(alpha: 0.5)
                    : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.directions_run_rounded,
                      color: AppColors.lime,
                      size: isLandscape ? 15.w : 18.w,
                    ),
                    6.width,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Body Motion Check',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: isLandscape
                                  ? 10.5.ts(context)
                                  : 12.ts(context),
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          1.5.height,
                          Text(
                            enabled
                                ? 'ON — needs ≥ ${(minScore * 100).toStringAsFixed(1)}% body movement (${_bodyMotionLevelLabel(level).toUpperCase()})'
                                : 'OFF — movement is only measured and logged',
                            style: TextStyle(
                              color: enabled
                                  ? AppColors.lime
                                  : AppColors.textMuted,
                              fontSize: isLandscape
                                  ? 7.8.ts(context)
                                  : 9.ts(context),
                              fontWeight: enabled
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: isLandscape ? 0.75 : 0.85,
                      child: Switch(
                        value: enabled,
                        activeThumbColor: AppColors.lime,
                        onChanged: (bool value) =>
                            onToggleBodyMotionGate?.call(value),
                      ),
                    ),
                  ],
                ),
                if (bodyMotionLevel != null) ...[
                  6.height,
                  Opacity(
                    // Level can be chosen while OFF too; it then decides what
                    // the log reports as "would pass / would reject".
                    opacity: enabled ? 1.0 : 0.6,
                    child: Row(
                      children: [
                        // Presets from most sensitive to strictest; "custom"
                        // has no chip (it is what the slider produces).
                        for (final BodyMotionLevel option in _bodyMotionPresets) ...[
                          Expanded(
                            child: _buildBodyMotionLevelChip(
                              context,
                              option: option,
                              selected: option == level,
                              isLandscape: isLandscape,
                            ),
                          ),
                          if (option != _bodyMotionPresets.last)
                            (isLandscape ? 4 : 5).width,
                        ],
                      ],
                    ),
                  ),
                ],
                if (bodyMotionMinScore != null) ...[
                  4.height,
                  Opacity(
                    opacity: enabled ? 1.0 : 0.6,
                    child: _buildBodyMotionSensitivitySlider(
                      context,
                      minScore: minScore,
                      isLandscape: isLandscape,
                    ),
                  ),
                ],
                6.height,
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 8.w : 10.w,
                    vertical: isLandscape ? 5.h : 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.panel.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: AppColors.lime.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.lime,
                        size: isLandscape ? 13.w : 15.w,
                      ),
                      6.width,
                      Expanded(
                        child: Text(
                          disabled
                              ? 'Camera confirmation is disabled, so the body motion check is inactive.'
                              : 'How it works: the camera follows your face and shoulders (and elbows / wrists when visible) around each hit. If you stood still, a loud sound + a bump on the mount is NOT counted. Needs movement of at least ${(minScore * 100).round()}% of your body width. Easy = light jabs pass easily, Strict = only clear punching movement.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: isLandscape
                                ? 7.8.ts(context)
                                : 9.ts(context),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  /// Preset chips shown in the sheet (every level except custom).
  static final List<BodyMotionLevel> _bodyMotionPresets = BodyMotionLevel.values
      .where((BodyMotionLevel l) => l != BodyMotionLevel.custom)
      .toList();

  static String _bodyMotionLevelLabel(BodyMotionLevel level) => switch (level) {
    BodyMotionLevel.veryLight => 'Very Light',
    BodyMotionLevel.light => 'Light',
    BodyMotionLevel.easy => 'Easy',
    BodyMotionLevel.normal => 'Normal',
    BodyMotionLevel.strict => 'Strict',
    BodyMotionLevel.custom => 'Custom',
  };

  // ─── BODY-MOTION SENSITIVITY SLIDER ───
  // Fine control between / beyond the presets. LEFT = more sensitive (less
  // movement needed), RIGHT = stricter. Moving it to a preset value
  // highlights that chip; any other value shows "Custom".
  Widget _buildBodyMotionSensitivitySlider(
    BuildContext context, {
    required double minScore,
    required bool isLandscape,
  }) {
    final double fontSmall = isLandscape ? 7.5.ts(context) : 8.5.ts(context);
    final String percentLabel = '${(minScore * 100).toStringAsFixed(1)}%';
    final bool nearJitter =
        minScore < AppConstants.bodyMotionMinScoreVeryLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Sensitivity',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: isLandscape ? 9.ts(context) : 10.5.ts(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              'needs ≥ $percentLabel movement',
              style: TextStyle(
                color: AppColors.lime,
                fontSize: isLandscape ? 8.5.ts(context) : 9.5.ts(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: isLandscape ? 2.5.h : 3.5.h,
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: isLandscape ? 6.r : 8.r,
            ),
          ),
          child: Slider(
            value: minScore.clamp(
              AppConstants.bodyMotionSliderMin,
              AppConstants.bodyMotionSliderMax,
            ),
            min: AppConstants.bodyMotionSliderMin,
            max: AppConstants.bodyMotionSliderMax,
            divisions:
                ((AppConstants.bodyMotionSliderMax -
                            AppConstants.bodyMotionSliderMin) /
                        AppConstants.bodyMotionSliderStep)
                    .round(),
            activeColor: AppColors.lime,
            inactiveColor: AppColors.border,
            label: percentLabel,
            onChanged: (double value) =>
                onSetBodyMotionMinScore?.call(value),
          ),
        ),
        Row(
          children: [
            Text(
              '◀ More sensitive',
              style: TextStyle(color: AppColors.textMuted, fontSize: fontSmall),
            ),
            const Spacer(),
            Text(
              'Stricter ▶',
              style: TextStyle(color: AppColors.textMuted, fontSize: fontSmall),
            ),
          ],
        ),
        if (nearJitter) ...[
          2.height,
          Text(
            '⚠ Below 3%: standing still (breathing / camera jitter) may pass.',
            style: TextStyle(
              color: AppColors.amber,
              fontSize: fontSmall,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBodyMotionLevelChip(
    BuildContext context, {
    required BodyMotionLevel option,
    required bool selected,
    required bool isLandscape,
  }) {
    final String label = _bodyMotionLevelLabel(option);
    // One decimal only when needed (e.g. "3%", "4.5%").
    final double pct = AppConstants.bodyMotionMinScore(option) * 100;
    final String percent = (pct - pct.roundToDouble()).abs() < 0.01
        ? pct.round().toString()
        : pct.toStringAsFixed(1);
    return GestureDetector(
      onTap: () => onSetBodyMotionLevel?.call(option),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isLandscape ? 4.h : 6.h),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.lime.withValues(alpha: 0.18)
              : AppColors.panel.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: selected ? AppColors.lime : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            // Five chips share one row: shrink the label instead of wrapping.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: selected ? AppColors.lime : AppColors.textPrimary,
                  fontSize: isLandscape ? 9.ts(context) : 10.5.ts(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '≥ $percent%',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: isLandscape ? 7.5.ts(context) : 8.5.ts(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── DEVICE STABILITY TILE ───
  Widget _buildDeviceStabilityTile(
    BuildContext context, {
    required bool isLandscape,
  }) {
    return Obx(
      () => Container(
        margin: EdgeInsets.symmetric(vertical: isLandscape ? 2.h : 8.h),
        padding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 10.w : 12.w,
          vertical: isLandscape ? 4.h : 8.h,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.sensors,
                        color: AppColors.lime,
                        size: isLandscape ? 14.w : 16.w,
                      ),
                      6.width,
                      Expanded(
                        child: Text(
                          'Device Stability Check (sensors_plus)',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: isLandscape
                                ? 10.5.ts(context)
                                : 12.ts(context),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  2.height,
                  Text(
                    isDeviceStabilityEnabled.value
                        ? 'ACTIVE — Blocks false pose triggers when holding device'
                        : 'DISABLED — Device movement check bypassed',
                    style: TextStyle(
                      color: isDeviceStabilityEnabled.value
                          ? AppColors.lime
                          : AppColors.textMuted,
                      fontSize: isLandscape ? 8.ts(context) : 9.5.ts(context),
                      fontWeight: isDeviceStabilityEnabled.value
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: isLandscape ? 0.75 : 0.85,
              child: Switch(
                value: isDeviceStabilityEnabled.value,
                activeThumbColor: AppColors.lime,
                onChanged: (bool value) => onToggleDeviceStability(value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
