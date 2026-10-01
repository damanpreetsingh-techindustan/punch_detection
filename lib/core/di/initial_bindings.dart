import 'package:get/get.dart';
import '../services/config_service.dart';
import '../services/monotonic_clock_service.dart';
import '../services/logger_service.dart';

class InitialBindings extends Bindings {
  @override
  void dependencies() {
    Get.put<LoggerService>(LoggerService(), permanent: true);
    Get.put<MonotonicClockService>(MonotonicClockService(), permanent: true);
    Get.put<ConfigService>(ConfigService(), permanent: true);
  }
}
