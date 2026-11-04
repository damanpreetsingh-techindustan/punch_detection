import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/subject_lock/appearance_signature.dart';

const YuvColor red = YuvColor(82, 90, 240);
const YuvColor blue = YuvColor(41, 240, 110);
const int rawW = 40;
const int rawH = 30;

/// Upright position of a raw pixel when ML Kit turns the buffer clockwise by
/// [rotation] (written independently of FramePixels' inverse mapping).
Point<int> uprightOf(int x, int y, int rotation) => switch (rotation) {
  90 => Point<int>(rawH - 1 - y, x),
  180 => Point<int>(rawW - 1 - x, rawH - 1 - y),
  270 => Point<int>(y, rawW - 1 - x),
  _ => Point<int>(x, y),
};

/// Red in the upright top-left 10×10 block, blue everywhere else.
YuvColor sceneAt(Point<int> upright) =>
    upright.x < 10 && upright.y < 10 ? red : blue;

FramePixels nv21Frame(int rotation, {bool withChroma = true}) {
  final Uint8List bytes = Uint8List(rawW * rawH + (withChroma ? rawW * rawH ~/ 2 : 0));
  for (int y = 0; y < rawH; y++) {
    for (int x = 0; x < rawW; x++) {
      bytes[y * rawW + x] = sceneAt(uprightOf(x, y, rotation)).y;
    }
  }
  if (withChroma) {
    for (int y = 0; y < rawH; y += 2) {
      for (int x = 0; x < rawW; x += 2) {
        final YuvColor c = sceneAt(uprightOf(x, y, rotation));
        final int i = rawW * rawH + (y >> 1) * rawW + x;
        bytes[i] = c.v;
        bytes[i + 1] = c.u;
      }
    }
  }
  return FramePixels(
    bytes: bytes,
    width: rawW,
    height: rawH,
    bytesPerRow: rawW,
    format: FramePixelFormat.nv21,
    rotationDegrees: rotation,
  );
}

FramePixels bgraFrame(int rotation, {int padding = 16}) {
  final int stride = rawW * 4 + padding;
  final Uint8List bytes = Uint8List(stride * rawH);
  for (int y = 0; y < rawH; y++) {
    for (int x = 0; x < rawW; x++) {
      final List<int> rgb = sceneAt(uprightOf(x, y, rotation)).toRgb();
      final int i = y * stride + x * 4;
      bytes[i] = rgb[2];
      bytes[i + 1] = rgb[1];
      bytes[i + 2] = rgb[0];
      bytes[i + 3] = 255;
    }
  }
  return FramePixels(
    bytes: bytes,
    width: rawW,
    height: rawH,
    bytesPerRow: stride,
    format: FramePixelFormat.bgra8888,
    rotationDegrees: rotation,
  );
}

void expectNear(YuvColor? actual, YuvColor expected, {int tolerance = 3}) {
  expect(actual, isNotNull);
  expect((actual!.y - expected.y).abs(), lessThanOrEqualTo(tolerance));
  expect((actual.u - expected.u).abs(), lessThanOrEqualTo(tolerance));
  expect((actual.v - expected.v).abs(), lessThanOrEqualTo(tolerance));
}

void main() {
  group('FramePixels reads the pixel under an upright (ML Kit) point', () {
    for (final int rotation in <int>[0, 90, 180, 270]) {
      test('NV21, rotation $rotation', () {
        final FramePixels pixels = nv21Frame(rotation);
        expectNear(pixels.colorAt(5, 5), red, tolerance: 0);
        expectNear(
          pixels.colorAt(pixels.uprightWidth - 3.0, pixels.uprightHeight - 3.0),
          blue,
          tolerance: 0,
        );
      });

      test('BGRA with padded rows, rotation $rotation', () {
        final FramePixels pixels = bgraFrame(rotation);
        expectNear(pixels.colorAt(5, 5), red);
        expectNear(
          pixels.colorAt(pixels.uprightWidth - 3.0, pixels.uprightHeight - 3.0),
          blue,
        );
      });
    }

    test('upright size swaps for 90 / 270', () {
      expect(nv21Frame(90).uprightWidth, rawH);
      expect(nv21Frame(90).uprightHeight, rawW);
      expect(nv21Frame(0).uprightWidth, rawW);
    });

    test('points outside the image give nothing', () {
      final FramePixels pixels = nv21Frame(90);
      expect(pixels.colorAt(-1, 5), isNull);
      expect(pixels.colorAt(5, pixels.uprightHeight.toDouble()), isNull);
    });

    test('NV21 without its chroma plane falls back to neutral colour', () {
      final YuvColor? c = nv21Frame(0, withChroma: false).colorAt(5, 5);
      expect(c!.y, red.y);
      expect(c.u, 128);
      expect(c.v, 128);
    });
  });

  group('uprightRgba (reference photo)', () {
    for (final int rotation in <int>[0, 90, 270]) {
      test('crops the upright image, rotation $rotation', () {
        final FramePixels pixels = nv21Frame(rotation);
        // 20×20 upright crop from the corner, scaled to 4×4: the top-left
        // 2×2 output pixels are the red block, the bottom-right are blue.
        final Uint8List rgba = pixels.uprightRgba(
          const Rectangle<double>(0, 0, 20, 20),
          4,
          4,
        );
        List<int> px(int x, int y) =>
            rgba.sublist((y * 4 + x) * 4, (y * 4 + x) * 4 + 4);
        expect(px(0, 0), <int>[...red.toRgb(), 255]);
        expect(px(3, 3), <int>[...blue.toRgb(), 255]);
      });
    }

    test('mirror flips left-right; outside the frame is black', () {
      final FramePixels pixels = nv21Frame(0);
      final Uint8List rgba = pixels.uprightRgba(
        const Rectangle<double>(0, 0, 20, 20),
        4,
        4,
        mirror: true,
      );
      expect(rgba.sublist(12, 16), <int>[...red.toRgb(), 255]); // (3, 0)
      final Uint8List outside = pixels.uprightRgba(
        const Rectangle<double>(-100, -100, 10, 10),
        2,
        2,
      );
      expect(outside.sublist(0, 4), <int>[0, 0, 0, 255]);
    });
  });

  group('crop (head cut-out for the face detector)', () {
    for (final int rotation in <int>[0, 90, 180, 270]) {
      test('keeps format / rotation and reports where it sits, rotation $rotation',
          () {
        final FramePixels pixels = nv21Frame(rotation);
        // Upright box over the red block's corner region.
        final FrameCrop crop = pixels.crop(
          const Rectangle<double>(2, 2, 14, 14),
        )!;
        expect(crop.pixels.rotationDegrees, rotation);
        expect(crop.pixels.format, FramePixelFormat.nv21);
        // A frame point inside the red block, read through the crop.
        const Point<double> inFrame = Point<double>(6, 6);
        final Point<double> inCrop = inFrame - crop.uprightOrigin;
        expectNear(crop.pixels.colorAt(inCrop.x, inCrop.y), red, tolerance: 0);
        // And one in the blue part of the box.
        const Point<double> blueInFrame = Point<double>(13, 13);
        final Point<double> blueInCrop = blueInFrame - crop.uprightOrigin;
        expectNear(
          crop.pixels.colorAt(blueInCrop.x, blueInCrop.y),
          blue,
          tolerance: 0,
        );
      });
    }

    test('BGRA crop keeps padded rows out', () {
      final FramePixels pixels = bgraFrame(0);
      final FrameCrop crop = pixels.crop(const Rectangle<double>(0, 0, 20, 20))!;
      expect(crop.pixels.bytesPerRow, crop.pixels.width * 4);
      expectNear(crop.pixels.colorAt(5, 5), red);
    });

    test('rgbAt matches colorAt', () {
      final FramePixels pixels = nv21Frame(90);
      final List<int> rgb = pixels.colorAt(5, 5)!.toRgb();
      final int packed = pixels.rgbAt(5, 5);
      expect(<int>[packed >> 16, (packed >> 8) & 0xFF, packed & 0xFF], rgb);
      expect(pixels.rgbAt(-1, 0), -1);
    });
  });

  group('maskedCopy', () {
    for (final int rotation in <int>[90, 270]) {
      test('greys exactly the upright box and leaves the frame untouched '
          '(rotation $rotation)', () {
        final FramePixels pixels = nv21Frame(rotation);
        final Uint8List before = Uint8List.fromList(pixels.bytes);
        final Uint8List masked = pixels.maskedCopy(
          const Rectangle<double>(0, 0, 11, 11),
        );
        final FramePixels maskedPixels = FramePixels(
          bytes: masked,
          width: rawW,
          height: rawH,
          bytesPerRow: rawW,
          format: FramePixelFormat.nv21,
          rotationDegrees: rotation,
        );
        expectNear(maskedPixels.colorAt(5, 5), const YuvColor(128, 128, 128),
            tolerance: 0);
        expectNear(
          maskedPixels.colorAt(
            maskedPixels.uprightWidth - 3.0,
            maskedPixels.uprightHeight - 3.0,
          ),
          blue,
          tolerance: 0,
        );
        expect(pixels.bytes, before);
      });
    }

    test('BGRA box is grey with opaque alpha', () {
      final FramePixels pixels = bgraFrame(0);
      final Uint8List masked = pixels.maskedCopy(
        const Rectangle<double>(0, 0, 9, 9),
      );
      final int i = 5 * pixels.bytesPerRow + 5 * 4;
      expect(masked.sublist(i, i + 4), <int>[128, 128, 128, 255]);
    });

    for (final int rotation in <int>[0, 90, 270]) {
      test('blankCopy greys every pixel and leaves the frame untouched '
          '(rotation $rotation)', () {
        final FramePixels pixels = nv21Frame(rotation);
        final Uint8List before = Uint8List.fromList(pixels.bytes);
        expect(pixels.blankCopy(), everyElement(128));
        expect(pixels.bytes, before);
      });
    }
  });

  group('AppearanceHistogram', () {
    AppearanceHistogram of(YuvColor color, int n) {
      final AppearanceHistogram h = AppearanceHistogram();
      for (int i = 0; i < n; i++) {
        h.add(color);
      }
      return h;
    }

    test('same colours match fully, different colours not at all', () {
      expect(of(red, 30).similarity(of(red, 90)), closeTo(1.0, 1e-9));
      expect(of(red, 30).similarity(of(blue, 30)), 0.0);
    });

    test('a partly covered region still mostly matches', () {
      final AppearanceHistogram covered = of(blue, 28)..addAll(of(red, 8));
      expect(of(blue, 100).similarity(covered), greaterThan(0.85));
    });

    test('black, grey and white land in different bins', () {
      const YuvColor black = YuvColor(30, 128, 128);
      const YuvColor white = YuvColor(220, 128, 128);
      expect(of(black, 20).similarity(of(white, 20)), 0.0);
    });

    test('a small exposure change scores far closer than a different shirt',
        () {
      // A black jacket, the same jacket slightly brighter (auto-exposure),
      // and a dark grey shirt (the case 3 brightness bins could not tell).
      final YuvColor jacket = YuvColor.fromRgb(62, 58, 57);
      final YuvColor brighter = YuvColor.fromRgb(68, 64, 63);
      final YuvColor greyShirt = YuvColor.fromRgb(93, 80, 72);
      final double same = of(jacket, 20).similarity(of(brighter, 20));
      final double other = of(jacket, 20).similarity(of(greyShirt, 20));
      expect(same, greaterThan(0.8));
      expect(same - other, greaterThan(0.3));
    });

    test('pooled and meanColor', () {
      final AppearanceHistogram pooled = AppearanceHistogram.pooled(
        <AppearanceHistogram>[of(red, 2), of(red, 2)],
      );
      expect(pooled.sampleCount, 4);
      expect(pooled.meanColor!.v, red.v);
      expect(AppearanceHistogram().meanColor, isNull);
    });
  });
}
