import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/services/camera_tracker_guard.dart';

void main() {
  test('asks for one reset once a pose has been refused long enough', () {
    final CameraTrackerGuard guard = CameraTrackerGuard(maxRefusedMs: 1000);
    guard.noteRefused(0);
    guard.noteRefused(999);
    expect(guard.takeReset(), isFalse);
    guard.noteRefused(1000);
    expect(guard.takeReset(), isTrue);
    expect(guard.takeReset(), isFalse);
  });

  test('a real person or no pose starts the wait over', () {
    final CameraTrackerGuard guard = CameraTrackerGuard(maxRefusedMs: 1000);
    guard.noteRefused(0);
    guard.clear();
    guard.noteRefused(900);
    guard.noteRefused(1500);
    expect(guard.takeReset(), isFalse);
    guard.noteRefused(1900);
    expect(guard.takeReset(), isTrue);
  });

  test('still stuck after a reset: waits the full time again', () {
    final CameraTrackerGuard guard = CameraTrackerGuard(maxRefusedMs: 1000);
    guard.noteRefused(0);
    guard.noteRefused(1000);
    expect(guard.takeReset(), isTrue);
    guard.noteRefused(1100);
    guard.noteRefused(2000);
    expect(guard.takeReset(), isFalse);
    guard.noteRefused(2100);
    expect(guard.takeReset(), isTrue);
  });
}
