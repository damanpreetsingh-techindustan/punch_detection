import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/widgets/common_permission_dialog.dart';

class PermissionsController extends GetxController {
  final RxBool micGranted = false.obs;
  final RxBool cameraGranted = false.obs;
  final RxBool storageGranted = true.obs;

  bool _isRequesting = false;

  @override
  void onInit() {
    super.onInit();
    checkPermissionsStatus();
  }

  Future<void> checkPermissionsStatus() async {
    final micStatus = await Permission.microphone.status;
    final camStatus = await Permission.camera.status;

    micGranted.value = micStatus.isGranted;
    cameraGranted.value = camStatus.isGranted;
  }

  Future<void> requestMicrophonePermission() async {
    if (_isRequesting) return;
    _isRequesting = true;
    try {
      final isGranted = await CommonPermissionDialog.requestAndCheckPermission(
        Permission.microphone,
        permissionName: 'Microphone',
      );
      micGranted.value = isGranted;
    } finally {
      _isRequesting = false;
    }
  }

  Future<void> requestCameraPermission() async {
    if (_isRequesting) return;
    _isRequesting = true;
    try {
      final isGranted = await CommonPermissionDialog.requestAndCheckPermission(
        Permission.camera,
        permissionName: 'Camera',
      );
      cameraGranted.value = isGranted;
    } finally {
      _isRequesting = false;
    }
  }

  Future<void> continueNext() async {
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      await requestMicrophonePermission();
      if (!micGranted.value) {
        Get.snackbar(
          'Microphone Permission Required',
          'You cannot proceed without granting microphone permission.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
    }

    AppNavigator.toHome();
  }
}
