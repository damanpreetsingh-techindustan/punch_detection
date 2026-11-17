import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/enums/sensitivity_level.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/app_version_info.dart';
import '../../../../core/utils/constants.dart';

class SettingsController extends GetxController {
  final StorageService _storage = StorageService.to;

  final Rx<SensitivityLevel> sensitivity = SensitivityLevel.normal.obs;
  RxBool get developerMode => _storage.developerMode;

  int _versionTaps = 0;

  String get versionLabel => AppVersionInfo.fullVersion;

  @override
  void onInit() {
    super.onInit();
    sensitivity.value = _storage.sensitivity;
  }

  void setSensitivity(SensitivityLevel level) {
    sensitivity.value = level;
    _storage.setSensitivity(level);
  }

  Future<void> replayIntro() async {
    await _storage.setOnboardingDone(false);
    AppNavigator.startOnboarding();
  }

  /// Tapping the version [AppConstants.developerModeTapCount] times turns
  /// Developer mode on.
  void onVersionTap() {
    if (developerMode.value) return;
    _versionTaps++;
    final left = AppConstants.developerModeTapCount - _versionTaps;
    if (left <= 0) {
      _versionTaps = 0;
      HapticFeedback.heavyImpact();
      _storage.setDeveloperMode(true);
      Get.snackbar(
        'Developer mode on',
        'Advanced detection controls are now visible.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } else if (left <= 3) {
      HapticFeedback.selectionClick();
      Get.closeAllSnackbars();
      Get.snackbar(
        'Developer mode',
        '$left more tap${left == 1 ? '' : 's'}',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(milliseconds: 900),
      );
    }
  }

  void setDeveloperMode(bool value) => _storage.setDeveloperMode(value);

  void openAdvancedSetup() =>
      AppNavigator.toSessionPreCheck(sessionType: 'free');

  void openDiagnostics() => AppNavigator.toDiagnostics();

  void openPaywall() => AppNavigator.toPaywall();
}
