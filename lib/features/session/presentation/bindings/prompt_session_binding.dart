import 'package:get/get.dart';
import '../controllers/prompt_session_controller.dart';

class PromptSessionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PromptSessionController>(() => PromptSessionController());
  }
}
