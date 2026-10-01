import 'package:get/get.dart';
import '../utils/monotonic_clock.dart';

class MonotonicClockService extends GetxService {
  int nowMs() => MonotonicClock.nowMilliseconds();
  int nowUs() => MonotonicClock.nowMicroseconds();

  Future<MonotonicClockService> init() async {
    return this;
  }
}
