import 'package:get/get.dart';
import '../../../../core/navigation/models/session_precheck_arguments.dart';
import '../controllers/session_precheck_controller.dart';

class SessionPreCheckBinding extends Bindings {
  @override
  void dependencies() {
    final SessionPreCheckArguments preCheckArgs =
        SessionPreCheckArguments.fromArguments(Get.arguments);
    if (Get.isRegistered<SessionPreCheckController>()) {
      Get.delete<SessionPreCheckController>(force: true);
    }
    Get.put<SessionPreCheckController>(
      SessionPreCheckController(sessionType: preCheckArgs.sessionType),
    );
  }
}
