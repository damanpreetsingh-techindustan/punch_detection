import 'dart:math';
import 'dart:typed_data';

/// Byte layout of a session camera frame: NV21 on Android, BGRA on iOS (the
/// iOS camera plugin falls back to BGRA when NV21 is requested).
enum FramePixelFormat { nv21, bgra8888 }

/// One colour sample in YUV (0-255 each).
class YuvColor {
  final int y;
  final int u;
  final int v;

  const YuvColor(this.y, this.u, this.v);

  /// BT.601 conversion, used for BGRA frames and the debug colour dots.
  factory YuvColor.fromRgb(int r, int g, int b) => YuvColor(
    (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255),
    (128 - 0.168736 * r - 0.331264 * g + 0.5 * b).round().clamp(0, 255),
    (128 + 0.5 * r - 0.418688 * g - 0.081312 * b).round().clamp(0, 255),
  );

  /// Red / green / blue (0-255) for showing this colour on screen.
  List<int> toRgb() {
    final double d = u - 128.0;
    final double e = v - 128.0;
    return <int>[
      (y + 1.402 * e).round().clamp(0, 255),
      (y - 0.344136 * d - 0.714136 * e).round().clamp(0, 255),
      (y + 1.772 * d).round().clamp(0, 255),
    ];
  }
}

/// A camera frame's bytes exactly as ML Kit received them.
///
/// ML Kit returns landmarks in the UPRIGHT image: the raw buffer turned
/// clockwise by [rotationDegrees]. [colorAt] takes such an upright point and
/// reads the matching raw pixel, so pose landmarks can be used directly.
///
/// [rotationDegrees] must be the rotation ML Kit really applied: the camera
/// rotation on Android, but 0 on iOS (google_mlkit_commons ignores the
/// rotation of byte images there, so iOS landmarks are already buffer pixels).
class FramePixels {
  final Uint8List bytes;

  /// Raw buffer size in pixels (sensor orientation).
  final int width;
  final int height;
  final int bytesPerRow;
  final FramePixelFormat format;
  final int rotationDegrees;

  const FramePixels({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.format,
    this.rotationDegrees = 0,
  });

  bool get _isTurned => rotationDegrees == 90 || rotationDegrees == 270;

  /// Size of the upright image (the space ML Kit landmarks are in).
  int get uprightWidth => _isTurned ? height : width;
  int get uprightHeight => _isTurned ? width : height;

  /// Raw buffer pixel for an upright point, or null outside the image.
  Point<int>? rawPixelFor(double ux, double uy) {
    final int ix = ux.floor();
    final int iy = uy.floor();
    if (ix < 0 || iy < 0 || ix >= uprightWidth || iy >= uprightHeight) {
      return null;
    }
    return switch (rotationDegrees) {
      90 => Point<int>(iy, height - 1 - ix),
      180 => Point<int>(width - 1 - ix, height - 1 - iy),
      270 => Point<int>(width - 1 - iy, ix),
      _ => Point<int>(ix, iy),
    };
  }

  /// Colour at an upright point, or null outside the image / buffer.
  /// An NV21 buffer without its chroma plane gives neutral chroma (128).
  YuvColor? colorAt(double ux, double uy) {
    final Point<int>? p = rawPixelFor(ux, uy);
    if (p == null) return null;
    if (format == FramePixelFormat.bgra8888) {
      final int i = p.y * bytesPerRow + p.x * 4;
      if (i + 2 >= bytes.length) return null;
      return YuvColor.fromRgb(bytes[i + 2], bytes[i + 1], bytes[i]);
    }
    final int i = p.y * bytesPerRow + p.x;
    if (i >= bytes.length) return null;
    // NV21: full Y plane, then one interleaved V,U pair per 2x2 pixels.
    final int vu = bytesPerRow * height + (p.y >> 1) * bytesPerRow + (p.x & ~1);
    if (vu + 1 >= bytes.length) return YuvColor(bytes[i], 128, 128);
    return YuvColor(bytes[i], bytes[vu + 1], bytes[vu]);
  }

  /// Packed 0xRRGGBB at an upright integer pixel, or -1 outside the frame.
  /// No allocation: called for every pixel when aligning a face.
  int rgbAt(int ux, int uy) {
    if (ux < 0 || uy < 0 || ux >= uprightWidth || uy >= uprightHeight) {
      return -1;
    }
    final int x, y;
    switch (rotationDegrees) {
      case 90:
        x = uy;
        y = height - 1 - ux;
      case 180:
        x = width - 1 - ux;
        y = height - 1 - uy;
      case 270:
        x = width - 1 - uy;
        y = ux;
      default:
        x = ux;
        y = uy;
    }
    if (format == FramePixelFormat.bgra8888) {
      final int i = y * bytesPerRow + x * 4;
      if (i + 2 >= bytes.length) return -1;
      return (bytes[i + 2] << 16) | (bytes[i + 1] << 8) | bytes[i];
    }
    final int i = y * bytesPerRow + x;
    if (i >= bytes.length) return -1;
    final int vu = bytesPerRow * height + (y >> 1) * bytesPerRow + (x & ~1);
    final double luma = bytes[i].toDouble();
    final double d = vu + 1 < bytes.length ? bytes[vu + 1] - 128.0 : 0;
    final double e = vu + 1 < bytes.length ? bytes[vu] - 128.0 : 0;
    final int r = (luma + 1.402 * e).round().clamp(0, 255);
    final int g = (luma - 0.344136 * d - 0.714136 * e).round().clamp(0, 255);
    final int b = (luma + 1.772 * d).round().clamp(0, 255);
    return (r << 16) | (g << 8) | b;
  }

  /// Upright position of a raw buffer pixel (inverse of [rawPixelFor]).
  Point<int> uprightPointFor(int rx, int ry) => switch (rotationDegrees) {
    90 => Point<int>(height - 1 - ry, rx),
    180 => Point<int>(width - 1 - rx, height - 1 - ry),
    270 => Point<int>(ry, width - 1 - rx),
    _ => Point<int>(rx, ry),
  };

  /// The part of the frame under the upright rectangle [box], as a smaller
  /// frame of the same format and rotation (e.g. to run a face detector on
  /// the tracked person's head only). Null when [box] misses the frame.
  FrameCrop? crop(Rectangle<double> box) {
    final Point<int>? a = rawPixelFor(
      box.left.clamp(0, uprightWidth - 1).toDouble(),
      box.top.clamp(0, uprightHeight - 1).toDouble(),
    );
    final Point<int>? b = rawPixelFor(
      box.right.clamp(0, uprightWidth - 1).toDouble(),
      box.bottom.clamp(0, uprightHeight - 1).toDouble(),
    );
    if (a == null || b == null) return null;
    // Even origin and size keep NV21's 2×2 colour blocks whole.
    final int x0 = min(a.x, b.x) & ~1;
    final int y0 = min(a.y, b.y) & ~1;
    final int w = (max(a.x, b.x) - x0 + 1) & ~1;
    final int h = (max(a.y, b.y) - y0 + 1) & ~1;
    if (w < 2 || h < 2 || x0 + w > width || y0 + h > height) return null;

    final Uint8List out;
    final int stride;
    if (format == FramePixelFormat.bgra8888) {
      stride = w * 4;
      out = Uint8List(stride * h);
      for (int y = 0; y < h; y++) {
        final int src = (y0 + y) * bytesPerRow + x0 * 4;
        out.setRange(y * stride, (y + 1) * stride, bytes, src);
      }
    } else {
      stride = w;
      out = Uint8List(w * h * 3 ~/ 2);
      for (int y = 0; y < h; y++) {
        final int src = (y0 + y) * bytesPerRow + x0;
        out.setRange(y * w, (y + 1) * w, bytes, src);
      }
      final int srcVu = bytesPerRow * height;
      for (int y = 0; y < h ~/ 2; y++) {
        final int src = srcVu + (y0 ~/ 2 + y) * bytesPerRow + x0;
        if (src + w > bytes.length) break;
        out.setRange(w * h + y * w, w * h + (y + 1) * w, bytes, src);
      }
    }
    // Where the crop's upright image starts in the frame's upright image.
    final Point<int> c0 = uprightPointFor(x0, y0);
    final Point<int> c1 = uprightPointFor(x0 + w - 1, y0 + h - 1);
    return FrameCrop(
      pixels: FramePixels(
        bytes: out,
        width: w,
        height: h,
        bytesPerRow: stride,
        format: format,
        rotationDegrees: rotationDegrees,
      ),
      uprightOrigin: Point<double>(
        min(c0.x, c1.x).toDouble(),
        min(c0.y, c1.y).toDouble(),
      ),
    );
  }

  /// Adds the colours at [points] (upright pixels) to [into]. Points outside
  /// the image are skipped.
  void sampleInto(AppearanceHistogram into, Iterable<Point<double>> points) {
    for (final Point<double> point in points) {
      final YuvColor? color = colorAt(point.x, point.y);
      if (color != null) into.add(color);
    }
  }

  /// Upright RGBA image of [crop] scaled to [outWidth] × [outHeight]
  /// (nearest pixel), e.g. the reference photo shown on screen. Outside the
  /// frame is black. [mirror] flips it left-right (selfie view).
  Uint8List uprightRgba(
    Rectangle<double> crop,
    int outWidth,
    int outHeight, {
    bool mirror = false,
  }) {
    final Uint8List out = Uint8List(outWidth * outHeight * 4);
    for (int oy = 0; oy < outHeight; oy++) {
      final double uy = crop.top + (oy + 0.5) * crop.height / outHeight;
      for (int ox = 0; ox < outWidth; ox++) {
        final int sx = mirror ? outWidth - 1 - ox : ox;
        final double ux = crop.left + (sx + 0.5) * crop.width / outWidth;
        final int i = (oy * outWidth + ox) * 4;
        final YuvColor? color = colorAt(ux, uy);
        if (color != null) {
          final List<int> rgb = color.toRgb();
          out[i] = rgb[0];
          out[i + 1] = rgb[1];
          out[i + 2] = rgb[2];
        }
        out[i + 3] = 255;
      }
    }
    return out;
  }

  /// Copy of the bytes with the whole frame painted neutral grey.
  Uint8List blankCopy() => maskedCopy(
    Rectangle<double>(0, 0, uprightWidth.toDouble(), uprightHeight.toDouble()),
  );

  /// Copy of the bytes with the upright rectangle [box] painted neutral grey.
  /// Used to hide a wrong person from ML Kit for a few frames; this frame's
  /// own bytes are never changed.
  Uint8List maskedCopy(Rectangle<double> box) {
    final Uint8List out = Uint8List.fromList(bytes);
    final Point<int>? a = rawPixelFor(
      box.left.clamp(0, uprightWidth - 1).toDouble(),
      box.top.clamp(0, uprightHeight - 1).toDouble(),
    );
    final Point<int>? b = rawPixelFor(
      box.right.clamp(0, uprightWidth - 1).toDouble(),
      box.bottom.clamp(0, uprightHeight - 1).toDouble(),
    );
    if (a == null || b == null) return out;
    // A 90° turn keeps a rectangle a rectangle: only its corners swap.
    final int x0 = min(a.x, b.x);
    final int x1 = max(a.x, b.x);
    final int y0 = min(a.y, b.y);
    final int y1 = max(a.y, b.y);

    if (format == FramePixelFormat.bgra8888) {
      final Uint8List greyRow = Uint8List((x1 - x0 + 1) * 4);
      for (int i = 0; i < greyRow.length; i += 4) {
        greyRow[i] = 128;
        greyRow[i + 1] = 128;
        greyRow[i + 2] = 128;
        greyRow[i + 3] = 255;
      }
      for (int y = y0; y <= y1; y++) {
        final int start = y * bytesPerRow + x0 * 4;
        if (start + greyRow.length > out.length) break;
        out.setRange(start, start + greyRow.length, greyRow);
      }
      return out;
    }

    for (int y = y0; y <= y1; y++) {
      final int start = y * bytesPerRow + x0;
      if (start + (x1 - x0 + 1) > out.length) break;
      out.fillRange(start, start + (x1 - x0 + 1), 128);
    }
    final int vuBase = bytesPerRow * height;
    final int vx0 = x0 & ~1;
    final int vx1 = x1 | 1;
    for (int y = y0 >> 1; y <= y1 >> 1; y++) {
      final int start = vuBase + y * bytesPerRow + vx0;
      if (start + (vx1 - vx0 + 1) > out.length) break;
      out.fillRange(start, start + (vx1 - vx0 + 1), 128);
    }
    return out;
  }
}

/// A cut-out of a frame: [pixels] in the frame's format and rotation, and
/// where its upright image starts in the frame's upright image (add it to a
/// point found in the crop to get the point in the frame).
class FrameCrop {
  final FramePixels pixels;
  final Point<double> uprightOrigin;

  const FrameCrop({required this.pixels, required this.uprightOrigin});
}

/// Colour histogram of one body region: 12 brightness × 5 × 5 colour bins.
///
/// Brightness needs 12 levels to tell a black jacket from a dark grey shirt
/// (most gym clothes are black / grey / white, so brightness carries most of
/// the difference; 3 levels could not, measured on a test video).
/// Each sample is shared between its two nearest brightness bins, so a small
/// auto-exposure change moves the histogram smoothly instead of jumping a
/// whole bin. The colour bins are centred on neutral (128) so black, white
/// and grey clothes land in the middle of a bin instead of on an edge.
class AppearanceHistogram {
  static const int lumaBins = 12;
  static const int chromaBins = 5;
  static const int binCount = lumaBins * chromaBins * chromaBins;
  static const double _lumaBinWidth = 256 / lumaBins;

  final Float64List _counts = Float64List(binCount);
  int _total = 0;
  int _sumY = 0;
  int _sumU = 0;
  int _sumV = 0;

  AppearanceHistogram();

  /// Several histograms pooled into one (e.g. the last few frames).
  factory AppearanceHistogram.pooled(Iterable<AppearanceHistogram> parts) {
    final AppearanceHistogram pooled = AppearanceHistogram();
    for (final AppearanceHistogram part in parts) {
      pooled.addAll(part);
    }
    return pooled;
  }

  int get sampleCount => _total;

  static int _chromaBin(int c) => ((c - 128) / 32).round().clamp(-2, 2) + 2;

  void add(YuvColor color) {
    final int chroma = _chromaBin(color.u) * chromaBins + _chromaBin(color.v);
    // Position between brightness bin centres, shared linearly.
    final double at = (color.y / _lumaBinWidth - 0.5).clamp(
      0.0,
      lumaBins - 1.0,
    );
    final int low = at.floor();
    final int high = min(low + 1, lumaBins - 1);
    final double toHigh = at - low;
    const int perLuma = chromaBins * chromaBins;
    _counts[low * perLuma + chroma] += 1 - toHigh;
    if (toHigh > 0) _counts[high * perLuma + chroma] += toHigh;
    _total++;
    _sumY += color.y;
    _sumU += color.u;
    _sumV += color.v;
  }

  void addAll(AppearanceHistogram other) {
    for (int i = 0; i < binCount; i++) {
      _counts[i] += other._counts[i];
    }
    _total += other._total;
    _sumY += other._sumY;
    _sumU += other._sumU;
    _sumV += other._sumV;
  }

  void clear() {
    _counts.fillRange(0, binCount, 0);
    _total = 0;
    _sumY = 0;
    _sumU = 0;
    _sumV = 0;
  }

  /// Bhattacharyya coefficient: 1 = same colour mix, 0 = nothing in common.
  double similarity(AppearanceHistogram other) {
    if (_total == 0 || other._total == 0) return 0;
    double sum = 0;
    for (int i = 0; i < binCount; i++) {
      sum += sqrt(_counts[i] * other._counts[i]);
    }
    return sum / sqrt(_total.toDouble() * other._total);
  }

  /// Average colour (for the debug colour dots), null when empty.
  YuvColor? get meanColor => _total == 0
      ? null
      : YuvColor(_sumY ~/ _total, _sumU ~/ _total, _sumV ~/ _total);
}
