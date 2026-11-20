import 'package:get/get.dart';
import '../controllers/learn_controller.dart';
import '../controllers/lesson_controller.dart';

class LearnBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LearnController>(() => LearnController());
  }
}

class LessonBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LessonController>(() => LessonController());
  }
}
