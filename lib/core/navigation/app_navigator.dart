import 'package:get/get.dart';
import '../utils/constants.dart';
import 'app_routes.dart';
import 'models/history_detail_arguments.dart';
import 'models/session_arguments.dart';
import 'models/session_precheck_arguments.dart';
import 'models/session_result_model.dart';

export 'models/history_detail_arguments.dart';
export 'models/session_arguments.dart';
export 'models/session_precheck_arguments.dart';
export 'models/session_result_model.dart';

enum SessionMode { prompt, free }

class AppNavigator {
  static void toSplash() {
    Get.offAllNamed(AppRoutes.splash);
  }

  static void toOnboarding() {
    Get.toNamed(AppRoutes.onboarding);
  }

  static void toPermissions() {
    Get.toNamed(AppRoutes.onboarding);
  }

  static void toMountGuide() {
    Get.toNamed(AppRoutes.onboarding);
  }

  static void toHome() {
    if (AppConstants.showAllFeatures) {
      Get.offAllNamed(AppRoutes.home);
    } else {
      final SessionPreCheckArguments preCheckArgs =
          SessionPreCheckArguments.fromArguments('free');
      Get.offAllNamed(AppRoutes.sessionPreCheck, arguments: preCheckArgs);
    }
  }

  static void toModeSelection() {
    Get.toNamed(AppRoutes.modeSelection);
  }

  static void toWorkoutSetup() {
    Get.toNamed(AppRoutes.workoutSetup);
  }

  static void toSessionPreCheck({
    dynamic arguments,
    String sessionType = 'prompt',
  }) {
    final SessionPreCheckArguments preCheckArgs =
        arguments is SessionPreCheckArguments
        ? arguments
        : SessionPreCheckArguments.fromArguments(arguments ?? sessionType);
    Get.toNamed(AppRoutes.sessionPreCheck, arguments: preCheckArgs);
  }

  static void toCalibration() {
    Get.toNamed(AppRoutes.sessionPreCheck);
  }

  static void toPromptSession({dynamic arguments}) {
    final SessionArguments sessionArgs = arguments is SessionArguments
        ? arguments
        : SessionArguments.fromArguments(arguments);
    Get.offNamed(AppRoutes.promptSession, arguments: sessionArgs);
  }

  static void toFreeSession({dynamic arguments}) {
    final SessionArguments sessionArgs = arguments is SessionArguments
        ? arguments
        : SessionArguments.fromArguments(arguments);
    Get.offNamed(AppRoutes.freeSession, arguments: sessionArgs);
  }

  static void toResults(dynamic result) {
    final SessionResultModel resultModel = result is SessionResultModel
        ? result
        : SessionResultModel.fromArguments(result);
    Get.offNamed(AppRoutes.results, arguments: resultModel);
  }

  static void toHistory() {
    Get.toNamed(AppRoutes.history);
  }

  static void toHistoryDetail(dynamic session) {
    final HistoryDetailArguments detailArgs = session is HistoryDetailArguments
        ? session
        : HistoryDetailArguments.fromArguments(session);
    Get.toNamed(AppRoutes.historyDetail, arguments: detailArgs);
  }

  static void toSettings() {
    Get.toNamed(AppRoutes.settings);
  }

  static void toDiagnostics() {
    Get.toNamed(AppRoutes.diagnostics);
  }

  static void back() {
    Get.back();
  }
}
