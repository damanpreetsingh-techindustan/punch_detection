import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/widgets/common_permission_dialog.dart';

class OnboardingController extends GetxController {
  PageController pageController = PageController();
  final RxInt currentStep = 0.obs;

  final RxBool micGranted = false.obs;
  final RxBool cameraGranted = false.obs;
  final RxBool storageGranted = true.obs;

  bool _isRequesting = false;

  @override
  void onInit() {
    super.onInit();
    pageController = PageController();
    checkAllPermissions();
  }

  Future<void> checkAllPermissions() async {
    final micStatus = await Permission.microphone.status;
    final camStatus = await Permission.camera.status;

    micGranted.value = micStatus.isGranted;
    cameraGranted.value = camStatus.isGranted;
  }

  Future<void> requestMicrophone() async {
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

  Future<void> requestCamera() async {
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

  Future<void> requestRequiredPermissions() async {
    if (_isRequesting) return;
    _isRequesting = true;
    try {
      final Map<Permission, String> mapToRequest = {};
      if (!micGranted.value) {
        mapToRequest[Permission.microphone] = 'Microphone';
      }
      if (!cameraGranted.value) {
        mapToRequest[Permission.camera] = 'Camera';
      }

      if (mapToRequest.isNotEmpty) {
        final results = await CommonPermissionDialog.checkAndRequestMultiplePermissions(
          permissionNames: mapToRequest,
        );
        if (results.containsKey(Permission.microphone)) {
          micGranted.value = results[Permission.microphone] ?? false;
        }
        if (results.containsKey(Permission.camera)) {
          cameraGranted.value = results[Permission.camera] ?? false;
        }
      }
    } finally {
      _isRequesting = false;
    }
  }

  void onPageChanged(int index) {
    currentStep.value = index;
    if (index == 1) {
      checkAllPermissions();
    }
  }

  Future<void> nextStep() async {
    if (currentStep.value == 1) {
      if (!micGranted.value || !cameraGranted.value) {
        await requestRequiredPermissions();
      }
      if (!micGranted.value || !cameraGranted.value) {
        Get.snackbar(
          'Permissions Required',
          'Both Microphone and Camera permissions are required to use Hyper Hitter.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
    }

    if (currentStep.value < 2) {
      final targetStep = currentStep.value + 1;
      if (pageController.hasClients) {
        pageController.animateToPage(
          targetStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        currentStep.value = targetStep;
      }
    } else {
      AppNavigator.toHome();
    }
  }

  void previousStep() {
    if (currentStep.value > 0) {
      final targetStep = currentStep.value - 1;
      if (pageController.hasClients) {
        pageController.animateToPage(
          targetStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        currentStep.value = targetStep;
      }
    } else {
      if (Get.key.currentState?.canPop() ?? false) {
        Get.back();
      } else {
        AppNavigator.toHome();
      }
    }
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
