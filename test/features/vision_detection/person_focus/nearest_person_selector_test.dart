import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/services/person_focus/models/face_box.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/services/person_focus/nearest_person_selector.dart';

FaceBox face(int id, double left, double size) =>
    FaceBox(box: Rect.fromLTWH(left, 100, size, size), trackingId: id);

void main() {
  late NearestPersonSelector selector;

  setUp(() {
    selector = NearestPersonSelector(
      switchRatio: 1.2,
      switchChecks: 3,
      holdMs: 1000,
    );
  });

  test('no face or one face -> no focus needed', () {
    expect(selector.select(<FaceBox>[], nowMs: 0).target, isNull);
    expect(
      selector.select(<FaceBox>[face(1, 0, 80)], nowMs: 150).target,
      isNull,
    );
  });

  test('several faces -> the biggest (nearest) is focused', () {
    final PersonSelection s = selector.select(<FaceBox>[
      face(1, 0, 40),
      face(2, 200, 90),
      face(3, 400, 60),
    ], nowMs: 0);
    expect(s.target?.trackingId, 2);
    expect(s.switched, isFalse);
  });

  test('focus stays while the other face is less than 1.2x bigger', () {
    selector.select(<FaceBox>[face(1, 0, 100), face(2, 300, 60)], nowMs: 0);
    for (int i = 1; i <= 5; i++) {
      final PersonSelection s = selector.select(<FaceBox>[
        face(1, 0, 100),
        face(2, 300, 115),
      ], nowMs: i * 150);
      expect(s.target?.trackingId, 1);
      expect(s.switched, isFalse);
    }
  });

  test('a clearly closer person takes over only after 3 checks in a row', () {
    selector.select(<FaceBox>[face(1, 0, 60), face(2, 300, 40)], nowMs: 0);
    final List<FaceBox> closer = <FaceBox>[face(1, 0, 60), face(2, 300, 100)];
    expect(selector.select(closer, nowMs: 150).target?.trackingId, 1);
    expect(selector.select(closer, nowMs: 300).target?.trackingId, 1);
    final PersonSelection third = selector.select(closer, nowMs: 450);
    expect(third.target?.trackingId, 2);
    expect(third.switched, isTrue);
  });

  test('an interrupted challenge starts counting again', () {
    selector.select(<FaceBox>[face(1, 0, 60), face(2, 300, 40)], nowMs: 0);
    final List<FaceBox> closer = <FaceBox>[face(1, 0, 60), face(2, 300, 100)];
    selector.select(closer, nowMs: 150);
    selector.select(closer, nowMs: 300);
    selector.select(<FaceBox>[face(1, 0, 60), face(2, 300, 50)], nowMs: 450);
    expect(selector.select(closer, nowMs: 600).target?.trackingId, 1);
  });

  test('focused face hidden (gloves): held for 1 s, then released', () {
    selector.select(<FaceBox>[face(1, 0, 100), face(2, 300, 40)], nowMs: 0);
    final List<FaceBox> onlyFar = <FaceBox>[face(2, 300, 40)];
    final PersonSelection held = selector.select(onlyFar, nowMs: 900);
    expect(held.target?.trackingId, 1, reason: 'last box kept');
    final PersonSelection after = selector.select(onlyFar, nowMs: 1200);
    expect(after.target, isNull, reason: 'only one face left -> no focus');
  });

  test('only the focused person left in view -> no focus needed', () {
    selector.select(<FaceBox>[face(1, 0, 100), face(2, 300, 40)], nowMs: 0);
    expect(
      selector.select(<FaceBox>[face(1, 0, 100)], nowMs: 150).target,
      isNull,
    );
  });

  test('without tracking ids the same person is matched by box overlap', () {
    FaceBox untracked(double left, double size) =>
        FaceBox(box: Rect.fromLTWH(left, 100, size, size));
    selector.select(<FaceBox>[untracked(0, 100), untracked(300, 40)], nowMs: 0);
    final PersonSelection s = selector.select(<FaceBox>[
      untracked(5, 100),
      untracked(300, 45),
    ], nowMs: 150);
    expect(s.target?.box.left, 5);
  });

  test('reset forgets the focused person', () {
    selector.select(<FaceBox>[face(1, 0, 100), face(2, 300, 40)], nowMs: 0);
    selector.reset();
    expect(selector.current, isNull);
  });
}
