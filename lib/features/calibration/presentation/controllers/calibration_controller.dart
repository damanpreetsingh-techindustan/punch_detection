import 'dart:async';
import 'package:get/get.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/services/config_service.dart';
import '../../domain/entities/calibration_result.dart';
import '../../domain/usecases/run_ambient_calibration.dart';

class CalibrationController extends GetxController {
  final RunAmbientCalibration runAmbientCalibrationUseCase;
  final ConfigService configService;

  final RxInt secondsRemaining = 10.obs;
  final RxDouble progressRatio = 0.0.obs;
  final RxDouble currentRms = 0.04.obs;
  final RxBool isCalibrating = false.obs;
  final Rxn<CalibrationResult> calibrationResult = Rxn<CalibrationResult>();

  Timer? _timer;

  CalibrationController({
    required this.runAmbientCalibrationUseCase,
    required this.configService,
  });

  @override
  void onInit() {
    super.onInit();
    startCalibrationSequence();
  }

  void startCalibrationSequence() {
    isCalibrating.value = true;
    secondsRemaining.value = 10;
    progressRatio.value = 0.0;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (secondsRemaining.value > 1) {
        secondsRemaining.value--;
        progressRatio.value = (10 - secondsRemaining.value) / 10.0;
        currentRms.value = 0.03 + (secondsRemaining.value % 4) * 0.01;
      } else {
        timer.cancel();
        secondsRemaining.value = 0;
        progressRatio.value = 1.0;
        await _finishCalibration();
      }
    });
  }

  Future<void> _finishCalibration() async {
    final result = await runAmbientCalibrationUseCase(
      RunAmbientCalibrationParams(
        isCameraEnabled: configService.cameraEnabled.value,
      ),
    );

    calibrationResult.value = result;
    isCalibrating.value = false;

    // Transition to Home Screen after successful 5s calibration
    await Future.delayed(const Duration(milliseconds: 800));
    AppNavigator.toHome();
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
