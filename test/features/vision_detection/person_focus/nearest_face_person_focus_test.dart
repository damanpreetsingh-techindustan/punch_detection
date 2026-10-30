import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:punch_detection_demo/features/vision_detection/data/person_focus/nearest_face_person_focus.dart';
import 'package:punch_detection_demo/features/vision_detection/data/person_focus/no_person_focus.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/services/person_focus/i_face_locator.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/services/person_focus/i_person_focus_strategy.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/services/person_focus/models/face_box.dart';

class _FakeFaceLocator implements IFaceLocator {
  List<FaceBox> faces = <FaceBox>[];
  bool throwOnLocate = false;
  int calls = 0;
  bool closed = false;

  @override
  Future<List<FaceBox>> locate(InputImage image) async {
    calls++;
    if (throwOnLocate) throw Exception('face detector failed');
    return faces;
  }

  @override
  Future<void> close() async => closed = true;
}

const int _w = 40;
const int _h = 40;

InputImage nv21Frame() => InputImage.fromBytes(
  bytes: Uint8List(_w * _h + _w * _h ~/ 2),
  metadata: InputImageMetadata(
    size: const Size(40, 40),
    rotation: InputImageRotation.rotation0deg,
    format: InputImageFormat.nv21,
    bytesPerRow: _w,
  ),
);

FaceBox face(int id, double left, double size) =>
    FaceBox(box: Rect.fromLTWH(left, 2, size, size), trackingId: id);

void main() {
  late _FakeFaceLocator locator;
  late int now;
  late NearestFacePersonFocus focus;

  setUp(() {
    locator = _FakeFaceLocator();
    now = 1000;
    focus = NearestFacePersonFocus(
      faceLocator: locator,
      checkIntervalMs: 150,
      clock: () => now,
    );
  });

  test('one person in view -> original frame, unchanged', () async {
    locator.faces = <FaceBox>[face(1, 10, 8)];
    final InputImage original = nv21Frame();
    final PersonFocusResult result = await focus.prepare(original);
    expect(identical(result.image, original), isTrue);
    expect(result.masked, isFalse);
    expect(result.facesSeen, 1);
  });

  test('several people -> masked frame with the same metadata', () async {
    locator.faces = <FaceBox>[face(1, 0, 3), face(2, 30, 6)];
    final InputImage original = nv21Frame();
    final PersonFocusResult result = await focus.prepare(original);
    expect(result.masked, isTrue);
    expect(result.facesSeen, 2);
    expect(result.image.metadata?.size, original.metadata?.size);
    expect(result.image.metadata?.rotation, original.metadata?.rotation);
    expect(result.image.bytes!.length, original.bytes!.length);
    // Top-left corner is far from the nearest face (x 30..36) -> greyed.
    expect(result.image.bytes![0], 128);
    // A pixel inside the nearest person's body area stays as it was.
    expect(result.image.bytes![20 * _w + 32], 0);
  });

  test(
    'faces are looked for at most every 150 ms; masking runs every frame',
    () async {
      locator.faces = <FaceBox>[face(1, 0, 3), face(2, 30, 6)];
      await focus.prepare(nv21Frame());
      now += 50;
      final PersonFocusResult second = await focus.prepare(nv21Frame());
      expect(locator.calls, 1);
      expect(second.masked, isTrue, reason: 'last body area reused');
      expect(second.facesSeen, isNull, reason: 'no face check in this call');
      now += 150;
      await focus.prepare(nv21Frame());
      expect(locator.calls, 2);
    },
  );

  test('face detector error -> original frame', () async {
    locator.throwOnLocate = true;
    final InputImage original = nv21Frame();
    final PersonFocusResult result = await focus.prepare(original);
    expect(identical(result.image, original), isTrue);
    expect(result.masked, isFalse);
  });

  test('image without bytes -> original, no face check', () async {
    final InputImage fileImage = InputImage.fromFilePath('/tmp/x.jpg');
    final PersonFocusResult result = await focus.prepare(fileImage);
    expect(identical(result.image, fileImage), isTrue);
    expect(locator.calls, 0);
  });

  test('reset drops the focus and checks again on the next frame', () async {
    locator.faces = <FaceBox>[face(1, 0, 3), face(2, 30, 6)];
    await focus.prepare(nv21Frame());
    focus.reset();
    locator.faces = <FaceBox>[face(2, 30, 6)];
    final PersonFocusResult result = await focus.prepare(nv21Frame());
    expect(locator.calls, 2);
    expect(result.masked, isFalse);
  });

  test('close closes the face locator', () async {
    await focus.close();
    expect(locator.closed, isTrue);
  });

  test('NoPersonFocus always returns the original frame', () async {
    final InputImage original = nv21Frame();
    final PersonFocusResult result = await const NoPersonFocus().prepare(
      original,
    );
    expect(identical(result.image, original), isTrue);
    expect(result.masked, isFalse);
  });
}
