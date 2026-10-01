import 'package:get/get.dart';
import '../../../../core/navigation/app_navigator.dart';

class HomeController extends GetxController {
  void startPromptMode() {
    AppNavigator.toWorkoutSetup();
  }

  void startFreeMode() {
    AppNavigator.toSessionPreCheck(sessionType: 'free');
  }

  void openCalibration() {
    AppNavigator.toSessionPreCheck();
  }

  void openDiagnostics() {
    AppNavigator.toDiagnostics();
  }

  void openHistory() {
    AppNavigator.toHistory();
  }

  void openSettings() {
    AppNavigator.toSettings();
  }
}
