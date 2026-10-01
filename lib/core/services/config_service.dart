import 'package:get/get.dart';

class ConfigService extends GetxService {
  // Detection thresholds & weights
  final RxDouble audioWeight = 0.7.obs;
  final RxDouble visionWeight = 0.3.obs;
  final RxDouble minFusionConfidenceThreshold = 0.65.obs;
  final RxDouble audioRmsSpikeThreshold = 0.15.obs;
  final RxDouble noiseFloorRms = 0.05.obs;
  final RxBool cameraEnabled = true.obs;

  Future<ConfigService> init() async {
    return this;
  }

  void setAudioWeight(double val) => audioWeight.value = val;
  void setVisionWeight(double val) => visionWeight.value = val;
  void setMinFusionConfidenceThreshold(double val) => minFusionConfidenceThreshold.value = val;
}
