import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/services/camera_near_latch.dart';

void main() {
  group('CameraNearLatch (hook / side-stance hold)', () {
    test('a short run of far frames after near is held as near (hook)', () {
      final CameraNearLatch latch = CameraNearLatch(farFramesToLeave: 10);
      expect(latch.update(measuredNear: true), isTrue);
      // Hook: body turned for ~6 frames, shoulders look narrow.
      for (int i = 0; i < 6; i++) {
        expect(latch.update(measuredNear: false), isTrue, reason: 'frame $i');
      }
      expect(latch.update(measuredNear: true), isTrue);
      expect(latch.farFrames, 0);
    });

    test('a user who walks away is rejected after farFramesToLeave frames', () {
      final CameraNearLatch latch = CameraNearLatch(farFramesToLeave: 10);
      latch.update(measuredNear: true);
      for (int i = 1; i < 10; i++) {
        expect(latch.update(measuredNear: false), isTrue);
      }
      expect(latch.update(measuredNear: false), isFalse);
      expect(latch.update(measuredNear: false), isFalse);
    });

    test('a person who was never near gets no hold (background person)', () {
      final CameraNearLatch latch = CameraNearLatch(farFramesToLeave: 10);
      expect(latch.update(measuredNear: false), isFalse);
    });

    test('reset forgets the user (left the frame)', () {
      final CameraNearLatch latch = CameraNearLatch(farFramesToLeave: 10);
      latch.update(measuredNear: true);
      latch.reset();
      expect(latch.update(measuredNear: false), isFalse);
    });
  });
}
