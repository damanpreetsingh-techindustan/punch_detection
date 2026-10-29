import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/detection_core/context/presence_window.dart';

void main() {
  group('PresenceWindow', () {
    test('present when a valid person was seen in the last 1500 ms', () {
      final PresenceWindow presence = PresenceWindow(windowMs: 1500);
      expect(presence.isPresentAt(5000), isFalse, reason: 'never seen');
      presence.noteValid(1000);
      expect(presence.isPresentAt(2000), isTrue);
      expect(presence.isPresentAt(2500), isTrue);
      expect(presence.isPresentAt(2501), isFalse);
      expect(presence.msSinceValid(2501), 1501);
    });

    test('a valid frame after the impact (decision still open) counts', () {
      final PresenceWindow presence = PresenceWindow()..noteValid(3100);
      expect(presence.isPresentAt(3000), isTrue);
      expect(presence.msSinceValid(3000), -100);
    });

    test('an older observation never replaces a newer one', () {
      final PresenceWindow presence = PresenceWindow()
        ..noteValid(5000)
        ..noteValid(4000);
      expect(presence.lastValidMs, 5000);
    });

    test('startup grace covers the first 3 s of the session only', () {
      final PresenceWindow presence = PresenceWindow(startupGraceMs: 3000);
      expect(presence.isInStartupGrace(10000, 10000), isTrue);
      expect(presence.isInStartupGrace(12999, 10000), isTrue);
      expect(presence.isInStartupGrace(13000, 10000), isFalse);
      expect(presence.isInStartupGrace(9999, 10000), isFalse);
      expect(
        presence.isInStartupGrace(100, 0),
        isFalse,
        reason: 'unknown session start never grants grace',
      );
    });

    test('reset forgets the person', () {
      final PresenceWindow presence = PresenceWindow()..noteValid(1000);
      presence.reset();
      expect(presence.isPresentAt(1000), isFalse);
    });
  });
}
