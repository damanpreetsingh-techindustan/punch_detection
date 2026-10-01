import 'package:get/get.dart';
import '../controllers/free_session_controller.dart';

class FreeSessionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FreeSessionController>(() => FreeSessionController());
  }
}
