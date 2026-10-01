import 'package:get/get.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/utils/app_version_info.dart';

class SplashController extends GetxController {
  final RxString versionDisplay = AppVersionInfo.fullVersion.obs;

  @override
  void onInit() {
    super.onInit();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    await AppVersionInfo.init();
    versionDisplay.value = AppVersionInfo.fullVersion;
    await Future.delayed(const Duration(seconds: 2));
    AppNavigator.toHome();
  }
}

