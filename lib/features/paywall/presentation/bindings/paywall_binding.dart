import 'package:get/get.dart';
import '../controllers/paywall_controller.dart';

class PaywallBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PaywallController>(() => PaywallController());
  }
}
