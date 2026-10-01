import 'dart:async';
import 'package:get/get.dart';
import '../../../../core/services/config_service.dart';
import '../../domain/entities/filter_stage_status.dart';
import '../../domain/entities/signal_telemetry.dart';
import '../../domain/usecases/get_live_telemetry.dart';
import '../../domain/usecases/update_detection_thresholds.dart';

class DiagnosticsController extends GetxController {
  final GetLiveTelemetry getLiveTelemetryUseCase;
  final UpdateDetectionThresholds updateDetectionThresholdsUseCase;
  final ConfigService configService;

  final Rx<SignalTelemetry> latestTelemetry = SignalTelemetry.initial().obs;
  final RxList<FilterStageStatus> filterStages = <FilterStageStatus>[].obs;

  final RxDouble audioWeight = 0.70.obs;
  final RxDouble visionWeight = 0.30.obs;
  final RxDouble minConfidenceThreshold = 0.75.obs;

  StreamSubscription<SignalTelemetry>? _subscription;

  DiagnosticsController({
    required this.getLiveTelemetryUseCase,
    required this.updateDetectionThresholdsUseCase,
    required this.configService,
  });

  @override
  void onInit() {
    super.onInit();
    _loadCurrentConfig();
    _subscribeToTelemetry();
  }

  void _loadCurrentConfig() {
    audioWeight.value = configService.audioWeight.value;
    visionWeight.value = configService.visionWeight.value;
    minConfidenceThreshold.value = configService.minFusionConfidenceThreshold.value;
  }

  void _subscribeToTelemetry() {
    _subscription = getLiveTelemetryUseCase().listen((telemetry) {
      latestTelemetry.value = telemetry;
      _updateFilterStages(telemetry);
    });
  }

  void _updateFilterStages(SignalTelemetry telemetry) {
    filterStages.value = [
      FilterStageStatus(
        stageName: 'Adaptive Noise Floor',
        passed: telemetry.audioRms > configService.noiseFloorRms.value,
        currentValue: telemetry.audioRms,
        thresholdValue: configService.noiseFloorRms.value,
      ),
      FilterStageStatus(
        stageName: 'Energy Threshold',
        passed: telemetry.audioRms > 0.08,
        currentValue: telemetry.audioRms,
        thresholdValue: 0.08,
      ),
      FilterStageStatus(
        stageName: 'Transient Envelope',
        passed: telemetry.peakAmplitude > 0.12,
        currentValue: telemetry.peakAmplitude,
        thresholdValue: 0.12,
      ),
      FilterStageStatus(
        stageName: 'Spectral Flatness',
        passed: telemetry.spectralFlatness > 0.50,
        currentValue: telemetry.spectralFlatness,
        thresholdValue: 0.50,
      ),
      FilterStageStatus(
        stageName: '3D Elbow Extension',
        passed: telemetry.elbowAngle > 140.0,
        currentValue: telemetry.elbowAngle,
        thresholdValue: 140.0,
      ),
      FilterStageStatus(
        stageName: 'Wrist Velocity',
        passed: telemetry.wristVelocity > 1.0,
        currentValue: telemetry.wristVelocity,
        thresholdValue: 1.0,
      ),
    ];
  }

  void setAudioWeight(double value) {
    audioWeight.value = value;
    visionWeight.value = 1.0 - value;
    updateDetectionThresholdsUseCase(
      UpdateThresholdsParams(
        audioWeight: audioWeight.value,
        visionWeight: visionWeight.value,
      ),
    );
  }

  void setMinConfidenceThreshold(double value) {
    minConfidenceThreshold.value = value;
    updateDetectionThresholdsUseCase(
      UpdateThresholdsParams(minConfidence: value),
    );
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
