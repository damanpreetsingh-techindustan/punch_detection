import 'package:get/get.dart';
import '../utils/constants.dart';
import 'app_routes.dart';
import '../../features/drills/domain/drill_program.dart';
import '../../features/history/domain/entities/workout_record.dart';
import 'models/session_arguments.dart';
import 'models/session_precheck_arguments.dart';
import 'models/session_result_model.dart';

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

  /// First launch: onboarding replaces the splash.
  static void startOnboarding() {
    Get.offAllNamed(AppRoutes.onboarding);
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

  /// One-screen setup (photo + room check) that opens the session itself.
  /// [replace]: swap out the current screen ("Train again" on Results), so
  /// repeated sessions don't pile up screens behind Home.
  static void toGetReady({
    String sessionType = 'free',
    String? difficulty,
    bool replace = false,
  }) {
    final args = SessionPreCheckArguments(
      sessionType: sessionType,
      difficulty: difficulty,
    );
    if (replace) {
      Get.offNamed(AppRoutes.getReady, arguments: args);
    } else {
      Get.toNamed(AppRoutes.getReady, arguments: args);
    }
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

  /// Completes when the user comes back from History.
  static Future<void> toHistory() async {
    await Get.toNamed(AppRoutes.history);
  }

  static void toHistoryDetail(WorkoutRecord record) {
    Get.toNamed(AppRoutes.historyDetail, arguments: record);
  }

  /// Reaction Drill library (built-in, fight styles, your own drills).
  static void toDrills() {
    Get.toNamed(AppRoutes.drills);
  }

  /// Create a drill, or edit [program] (one of the user's own).
  static void toDrillEditor({DrillProgram? program}) {
    Get.toNamed(AppRoutes.drillEditor, arguments: program);
  }

  /// KnockUp Pro plans. [fromLimit]: opened because today's free punches
  /// are used up (the paywall says so).
  static void toPaywall({bool fromLimit = false}) {
    Get.toNamed(AppRoutes.paywall, arguments: {'fromLimit': fromLimit});
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
