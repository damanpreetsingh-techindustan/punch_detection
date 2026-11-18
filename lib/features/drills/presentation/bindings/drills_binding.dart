import 'package:get/get.dart';
import '../controllers/drill_editor_controller.dart';
import '../controllers/drills_controller.dart';

class DrillsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DrillsController>(() => DrillsController());
  }
}

class DrillEditorBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DrillEditorController>(() => DrillEditorController());
  }
}
