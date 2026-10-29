import 'package:get/get.dart';
import '../utils/monotonic_clock.dart';

class MonotonicClockService extends GetxService {
  int nowMs() => MonotonicClock.nowMilliseconds();
  int nowUs() => MonotonicClock.nowMicroseconds();

  /// Monotonic epoch milliseconds, the time base of all detection timestamps.
  int epochMs() => MonotonicClock.epochMs();

  Future<MonotonicClockService> init() async {
    return this;
  }
}
