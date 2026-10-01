import 'package:get/get.dart';

class WorkoutSetupController extends GetxController {
  final RxString difficulty = 'beginner'.obs; // 'beginner', 'intermediate', 'advanced'

  void selectDifficulty(String value) {
    difficulty.value = value;
  }

  void setDifficulty(String value) {
    difficulty.value = value;
  }
}
