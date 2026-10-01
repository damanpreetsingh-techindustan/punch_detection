import 'package:get/get.dart';
import '../controllers/mode_selection_controller.dart';

class ModeSelectionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ModeSelectionController>(() => ModeSelectionController());
  }
}
