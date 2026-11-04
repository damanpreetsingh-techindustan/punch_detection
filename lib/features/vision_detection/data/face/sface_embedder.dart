import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../domain/subject_lock/appearance_signature.dart';
import '../../domain/subject_lock/face_alignment.dart';
import '../../domain/subject_lock/i_face_embedder.dart';

/// Face embedding for the subject lock's face check:
///  1. cut out the tracked person's head (from the pose's face points), so
///     the face found is always theirs and the detector works on a small
///     image;
///  2. ML Kit face detection with contours on that cut-out: eye centres from
///     the eye outlines, nose tip, mouth corners from the lip outline (the
///     coarse pose points are not precise enough to align a face). Only the
///     face on the pose's own nose is used: the cut-out can show a neighbour;
///  3. align to the 112 × 112 template and run SFace (TFLite, int8 weights,
///     assets/models/README.md) in a background isolate.
///
/// Only called a few times a second and never awaited by the pose loop.
class SFaceEmbedder implements IFaceEmbedder {
  static const String modelAsset =
      'assets/models/face_recognition_sface_int8.tflite';
  static const int embeddingSize = 128;

  final FaceDetector _detector;
  final Interpreter _interpreter;
  final IsolateInterpreter _isolate;

  SFaceEmbedder._(this._detector, this._interpreter, this._isolate);

  /// Null when the model or the detector cannot be loaded (the lock then
  /// works without the face check).
  static Future<SFaceEmbedder?> create() async {
    try {
      final Interpreter interpreter = await Interpreter.fromAsset(
        modelAsset,
        options: InterpreterOptions()..threads = 2,
      );
      final IsolateInterpreter isolate = await IsolateInterpreter.create(
        address: interpreter.address,
      );
      final FaceDetector detector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: true,
          performanceMode: FaceDetectorMode.fast,
          // The cut-out is mostly face.
          minFaceSize: 0.15,
        ),
      );
      return SFaceEmbedder._(detector, interpreter, isolate);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<double>?> embed(FramePixels pixels, FacePoints poseFace) async {
    final FrameCrop? head = pixels.crop(_headBox(poseFace));
    if (head == null) return null;
    final FramePixels crop = head.pixels;
    final List<Face> faces = await _detector.processImage(
      InputImage.fromBytes(
        bytes: crop.bytes,
        metadata: InputImageMetadata(
          size: Size(crop.width.toDouble(), crop.height.toDouble()),
          rotation:
              InputImageRotationValue.fromRawValue(crop.rotationDegrees) ??
              InputImageRotation.rotation0deg,
          format: crop.format == FramePixelFormat.bgra8888
              ? InputImageFormat.bgra8888
              : InputImageFormat.nv21,
          bytesPerRow: crop.bytesPerRow,
        ),
      ),
    );
    final int? own = poseFace.indexOfOwnFace(<Rectangle<double>>[
      for (final Face f in faces)
        Rectangle<double>(
          head.uprightOrigin.x + f.boundingBox.left,
          head.uprightOrigin.y + f.boundingBox.top,
          f.boundingBox.width,
          f.boundingBox.height,
        ),
    ]);
    if (own == null) return null;
    final FacePoints? points = _facePoints(faces[own], head.uprightOrigin);
    if (points == null) return null;

    final Float32List input = FaceAlignment.alignedRgb(pixels, points);
    final Float32List output = Float32List(embeddingSize);
    await _isolate.run(input.buffer.asUint8List(), output.buffer.asUint8List());
    return output.toList();
  }

  @override
  Future<void> close() async {
    await _isolate.close();
    _interpreter.close();
    await _detector.close();
  }

  /// A square around the face, about four eye distances wide.
  static Rectangle<double> _headBox(FacePoints face) {
    final double side = 4 * face.eyeDistance;
    final double cx = (face.leftEye.x + face.rightEye.x) / 2;
    final double cy =
        (face.leftEye.y + face.rightEye.y + face.leftMouth.y + face.rightMouth.y) /
        4;
    return Rectangle<double>(cx - side / 2, cy - side / 2, side, side);
  }

  /// Eye centres, nose tip and mouth corners in frame (upright) pixels.
  static FacePoints? _facePoints(Face face, Point<double> origin) {
    Point<double> shift(Point<num> p) =>
        Point<double>(origin.x + p.x, origin.y + p.y);
    List<Point<int>>? contour(FaceContourType type) {
      final List<Point<int>>? points = face.contours[type]?.points;
      return points == null || points.isEmpty ? null : points;
    }

    Point<double>? centre(List<Point<int>>? points) {
      if (points == null) return null;
      double x = 0, y = 0;
      for (final Point<int> p in points) {
        x += p.x;
        y += p.y;
      }
      return shift(Point<double>(x / points.length, y / points.length));
    }

    Point<double>? landmark(FaceLandmarkType type) {
      final Point<int>? p = face.landmarks[type]?.position;
      return p == null ? null : shift(p);
    }

    final List<Point<int>>? lip = contour(FaceContourType.upperLipTop);
    final List<Point<int>>? bridge = contour(FaceContourType.noseBridge);
    final Point<double>? eyeA =
        centre(contour(FaceContourType.leftEye)) ??
        landmark(FaceLandmarkType.leftEye);
    final Point<double>? eyeB =
        centre(contour(FaceContourType.rightEye)) ??
        landmark(FaceLandmarkType.rightEye);
    final Point<double>? nose = bridge != null
        ? shift(bridge.last)
        : landmark(FaceLandmarkType.noseBase);
    final Point<double>? mouthA = lip != null
        ? shift(lip.first)
        : landmark(FaceLandmarkType.leftMouth);
    final Point<double>? mouthB = lip != null
        ? shift(lip.last)
        : landmark(FaceLandmarkType.rightMouth);
    if (eyeA == null ||
        eyeB == null ||
        nose == null ||
        mouthA == null ||
        mouthB == null) {
      return null;
    }
    return FacePoints.ordered(
      eyeA: eyeA,
      eyeB: eyeB,
      nose: nose,
      mouthA: mouthA,
      mouthB: mouthB,
    );
  }
}
