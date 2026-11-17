import 'package:get/get.dart';
import '../../../../core/navigation/models/session_precheck_arguments.dart';
import '../controllers/session_precheck_controller.dart';

/// "Get Ready" screen: the same controller as the pre-check, in express mode.
class GetReadyBinding extends Bindings {
  @override
  void dependencies() {
    final SessionPreCheckArguments args =
        SessionPreCheckArguments.fromArguments(Get.arguments);
    if (Get.isRegistered<SessionPreCheckController>()) {
      Get.delete<SessionPreCheckController>(force: true);
    }
    Get.put<SessionPreCheckController>(
      SessionPreCheckController(
        sessionType: args.sessionType,
        difficulty: args.difficulty,
        express: true,
      ),
    );
  }
}
