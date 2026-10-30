import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:punch_detection_demo/features/vision_detection/data/image/frame_masker.dart';

/// Where raw pixel (x, y) ends up after ML Kit turns the buffer upright.
(int, int) toUpright(int x, int y, int w, int h, InputImageRotation r) =>
    switch (r) {
      InputImageRotation.rotation0deg => (x, y),
      InputImageRotation.rotation90deg => (h - 1 - y, x),
      InputImageRotation.rotation180deg => (w - 1 - x, h - 1 - y),
      InputImageRotation.rotation270deg => (y, w - 1 - x),
    };

void main() {
  const FrameMasker masker = FrameMasker();

  group('uprightToRaw', () {
    for (final InputImageRotation rotation in InputImageRotation.values) {
      test('maps every pixel back for ${rotation.name}', () {
        const int w = 6;
        const int h = 4;
        for (int y = 0; y < h; y++) {
          for (int x = 0; x < w; x++) {
            final (int u, int v) = toUpright(x, y, w, h, rotation);
            final Rect raw = FrameMasker.uprightToRaw(
              Rect.fromLTWH(u.toDouble(), v.toDouble(), 1, 1),
              w,
              h,
              rotation,
            );
            expect(
              raw,
              Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
              reason: 'raw ($x,$y) -> upright ($u,$v)',
            );
          }
        }
      });
    }
  });

  group('NV21', () {
    const int w = 8;
    const int h = 4;
    Uint8List frame() => Uint8List(w * h + w * h ~/ 2); // all 0

    test('keeps the area, greys the rest of luma and chroma', () {
      final Uint8List out = masker.mask(
        bytes: frame(),
        width: w,
        height: h,
        bytesPerRow: w,
        format: InputImageFormat.nv21,
        rotation: InputImageRotation.rotation0deg,
        keepUpright: const Rect.fromLTRB(2, 0, 6, 2),
      )!;
      expect(out.length, w * h + w * h ~/ 2);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final bool inside = y < 2 && x >= 2 && x < 6;
          expect(out[y * w + x], inside ? 0 : 128, reason: 'Y ($x,$y)');
        }
      }
      // Chroma row 0 covers pixel rows 0-1 (inside), row 1 covers 2-3.
      for (int x = 0; x < w; x++) {
        expect(out[w * h + x], x >= 2 && x < 6 ? 0 : 128, reason: 'VU0 $x');
        expect(out[w * h + w + x], 128, reason: 'VU1 $x');
      }
    });

    test('rotated frame keeps the right raw pixels', () {
      // Upright pixel (1, 0) of a 90° frame is raw pixel (0, h - 2).
      final Uint8List out = masker.mask(
        bytes: frame(),
        width: w,
        height: h,
        bytesPerRow: w,
        format: InputImageFormat.nv21,
        rotation: InputImageRotation.rotation90deg,
        keepUpright: const Rect.fromLTWH(1, 0, 1, 1),
      )!;
      expect(out[(h - 2) * w + 0], 0);
      expect(out[0], 128);
    });

    test('too short buffer -> null', () {
      expect(
        masker.mask(
          bytes: Uint8List(10),
          width: w,
          height: h,
          bytesPerRow: w,
          format: InputImageFormat.nv21,
          rotation: InputImageRotation.rotation0deg,
          keepUpright: const Rect.fromLTRB(0, 0, 4, 4),
        ),
        isNull,
      );
    });
  });

  group('BGRA', () {
    test('keeps the area, greys the rest as opaque grey', () {
      const int w = 4;
      const int h = 2;
      final Uint8List out = masker.mask(
        bytes: Uint8List(w * h * 4),
        width: w,
        height: h,
        bytesPerRow: w * 4,
        format: InputImageFormat.bgra8888,
        rotation: InputImageRotation.rotation0deg,
        keepUpright: const Rect.fromLTRB(1, 0, 3, 1),
      )!;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final int i = (y * w + x) * 4;
          final bool inside = y == 0 && x >= 1 && x < 3;
          expect(
            out.sublist(i, i + 4),
            inside ? <int>[0, 0, 0, 0] : <int>[128, 128, 128, 255],
            reason: '($x,$y)',
          );
        }
      }
    });
  });

  test('unsupported format -> null (caller keeps the original)', () {
    expect(
      masker.mask(
        bytes: Uint8List(100),
        width: 4,
        height: 4,
        bytesPerRow: 4,
        format: InputImageFormat.yuv420,
        rotation: InputImageRotation.rotation0deg,
        keepUpright: const Rect.fromLTRB(0, 0, 2, 2),
      ),
      isNull,
    );
  });
}
