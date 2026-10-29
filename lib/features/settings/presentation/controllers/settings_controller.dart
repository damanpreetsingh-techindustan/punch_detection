import 'package:get/get.dart';
import '../../../../core/services/config_service.dart';
import '../../../../core/utils/constants.dart';

class SettingsController extends GetxController {
  final ConfigService configService = Get.find<ConfigService>();

  /// Debug: record raw sensor data for the next Free sessions.
  final RxBool recordRawData = AppConstants.recordRawSessionData.obs;

  void setRecordRawData(bool enabled) {
    AppConstants.recordRawSessionData = enabled;
    recordRawData.value = enabled;
  }

  final RxDouble audioEnergyThreshold = 0.45.obs;
  final RxDouble visionMotionThreshold = 0.35.obs;
  final RxDouble audioWeight = 0.70.obs;
  final RxDouble minFusionConfidenceThreshold = 0.65.obs;

  @override
  void onInit() {
    super.onInit();
    audioWeight.value = configService.audioWeight.value;
    minFusionConfidenceThreshold.value =
        configService.minFusionConfidenceThreshold.value;
  }

  void setAudioWeight(double val) {
    audioWeight.value = val;
    configService.setAudioWeight(val);
    configService.setVisionWeight(1.0 - val);
  }

  void setMinFusionConfidenceThreshold(double val) {
    minFusionConfidenceThreshold.value = val;
    configService.setMinFusionConfidenceThreshold(val);
  }

  void saveSettings() {
    Get.back();
    Get.snackbar(
      'Settings Saved',
      'Punch detection parameters updated.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
