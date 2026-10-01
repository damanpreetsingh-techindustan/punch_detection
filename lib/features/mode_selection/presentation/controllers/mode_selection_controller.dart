import 'package:get/get.dart';

class ModeSelectionController extends GetxController {
  final RxString selectedMode = 'prompt'.obs;

  void selectMode(String mode) {
    selectedMode.value = mode;
  }
}
