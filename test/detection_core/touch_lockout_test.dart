import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/detection_core/context/touch_lockout.dart';

void main() {
  group('TouchLockout window', () {
    late TouchLockout lockout;

    setUp(() {
      lockout = TouchLockout(beforeMs: 100, afterMs: 400);
      lockout.addTouch(10000);
    });

    test('covers 100 ms before to 400 ms after the touch (inclusive)', () {
      expect(lockout.isLocked(9899), isFalse);
      expect(lockout.isLocked(9900), isTrue);
      expect(lockout.isLocked(10000), isTrue);
      expect(lockout.isLocked(10400), isTrue);
      expect(lockout.isLocked(10401), isFalse);
    });

    test('reports the touch that covers a time', () {
      expect(lockout.touchCovering(10250), 10000);
      expect(lockout.touchCovering(11000), isNull);
    });

    test('each touch has its own window', () {
      lockout.addTouch(12000);
      expect(lockout.isLocked(11000), isFalse);
      expect(lockout.isLocked(11950), isTrue);
      expect(lockout.touchCovering(12100), 12000);
    });

    test('old touches are forgotten', () {
      final TouchLockout short = TouchLockout(historyMs: 5000)..addTouch(0);
      short.addTouch(10000);
      expect(short.touches, <int>[10000]);
      expect(short.isLocked(100), isFalse);
    });

    test('reset clears every touch', () {
      lockout.reset();
      expect(lockout.isLocked(10000), isFalse);
    });
  });
}
