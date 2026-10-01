import 'package:get/get.dart';
import '../controllers/workout_setup_controller.dart';

class WorkoutSetupBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<WorkoutSetupController>(() => WorkoutSetupController());
  }
}
