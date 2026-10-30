import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/services/person_focus/body_region.dart';

void main() {
  const BodyRegion region = BodyRegion(widthFactor: 2.5, topFactor: 1.0);
  const Size image = Size(1000, 2000);

  test('widens the face to the body and reaches the bottom of the image', () {
    final Rect body = region.fromFace(
      const Rect.fromLTWH(400, 300, 100, 120),
      image,
    );
    expect(body.left, 150); // 400 - 2.5 * 100
    expect(body.right, 750); // 500 + 2.5 * 100
    expect(body.top, 180); // 300 - 1.0 * 120
    expect(body.bottom, 2000);
  });

  test('is clamped to the image', () {
    final Rect body = region.fromFace(
      const Rect.fromLTWH(20, 30, 200, 200),
      image,
    );
    expect(body.left, 0);
    expect(body.top, 0);
    expect(body.right, 720);
  });
}
