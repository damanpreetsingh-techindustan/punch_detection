import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Hides everything outside one area of a camera frame by painting it grey.
///
/// The image keeps its size, format and row stride, so every coordinate the
/// pose detector returns stays exactly where it was without masking.
///
/// [keepUpright] is given in UPRIGHT image coordinates (after [rotation], the
/// space of face boxes and pose landmarks) and is mapped back to the raw buffer.
/// Supports NV21 (Android) and BGRA8888 (iOS); other formats return null so the
/// caller keeps the original frame.
///
/// Pure: bytes in, bytes out.
class FrameMasker {
  static const int _grey = 128;

  const FrameMasker();

  Uint8List? mask({
    required Uint8List bytes,
    required int width,
    required int height,
    required int bytesPerRow,
    required InputImageFormat format,
    required InputImageRotation rotation,
    required Rect keepUpright,
  }) {
    if (width <= 0 || height <= 0) return null;
    final Rect raw = uprightToRaw(keepUpright, width, height, rotation);
    final int x0 = raw.left.floor().clamp(0, width);
    final int x1 = raw.right.ceil().clamp(x0, width);
    final int y0 = raw.top.floor().clamp(0, height);
    final int y1 = raw.bottom.ceil().clamp(y0, height);

    switch (format) {
      case InputImageFormat.nv21:
        return _maskNv21(bytes, width, height, bytesPerRow, x0, x1, y0, y1);
      case InputImageFormat.bgra8888:
        return _maskBgra(bytes, width, height, bytesPerRow, x0, x1, y0, y1);
      case InputImageFormat.yuv_420_888:
      case InputImageFormat.yv12:
      case InputImageFormat.yuv420:
        return null;
    }
  }

  /// Maps a rect from upright coordinates to raw buffer coordinates.
  /// ML Kit turns the raw buffer [rotation] degrees clockwise to make it upright.
  static Rect uprightToRaw(
    Rect r,
    int rawWidth,
    int rawHeight,
    InputImageRotation rotation,
  ) {
    final double w = rawWidth.toDouble();
    final double h = rawHeight.toDouble();
    switch (rotation) {
      case InputImageRotation.rotation0deg:
        return r;
      case InputImageRotation.rotation90deg:
        return Rect.fromLTRB(r.top, h - r.right, r.bottom, h - r.left);
      case InputImageRotation.rotation180deg:
        return Rect.fromLTRB(w - r.right, h - r.bottom, w - r.left, h - r.top);
      case InputImageRotation.rotation270deg:
        return Rect.fromLTRB(w - r.bottom, r.left, w - r.top, r.right);
    }
  }

  Uint8List? _maskNv21(
    Uint8List src,
    int width,
    int height,
    int stride,
    int x0,
    int x1,
    int y0,
    int y1,
  ) {
    final int rowStride = max(stride, width);
    final int yPlaneSize = rowStride * height;
    if (src.length < yPlaneSize + width * (height ~/ 2)) return null;
    final Uint8List out = Uint8List.fromList(src);

    // Luma plane: one byte per pixel.
    for (int y = 0; y < height; y++) {
      _maskRow(out, y * rowStride, width, 1, y >= y0 && y < y1, x0, x1);
    }

    // Interleaved VU plane: half the rows, one VU pair per 2 pixels.
    final int cx0 = x0 & ~1;
    final int cx1 = min(width, (x1 + 1) & ~1);
    final int chromaRows = (height + 1) ~/ 2;
    for (int r = 0; r < chromaRows; r++) {
      final int start = yPlaneSize + r * rowStride;
      final int rowLength = min(width, out.length - start);
      if (rowLength <= 0) break;
      final int py = r * 2;
      _maskRow(out, start, rowLength, 1, py >= y0 && py < y1, cx0, cx1);
    }
    return out;
  }

  Uint8List? _maskBgra(
    Uint8List src,
    int width,
    int height,
    int stride,
    int x0,
    int x1,
    int y0,
    int y1,
  ) {
    final int rowStride = max(stride, width * 4);
    if (src.length < rowStride * (height - 1) + width * 4) return null;
    final Uint8List out = Uint8List.fromList(src);
    final Uint8List greyRow = Uint8List(width * 4);
    for (int i = 0; i < greyRow.length; i += 4) {
      greyRow[i] = _grey;
      greyRow[i + 1] = _grey;
      greyRow[i + 2] = _grey;
      greyRow[i + 3] = 255;
    }
    for (int y = 0; y < height; y++) {
      final int start = y * rowStride;
      if (y < y0 || y >= y1) {
        out.setRange(start, start + width * 4, greyRow);
      } else {
        out.setRange(start, start + x0 * 4, greyRow);
        out.setRange(start + x1 * 4, start + width * 4, greyRow);
      }
    }
    return out;
  }

  /// Greys one single-byte-per-sample row: all of it when [inside] is false,
  /// otherwise only the parts left of [x0] and right of [x1].
  static void _maskRow(
    Uint8List out,
    int start,
    int length,
    int bytesPerSample,
    bool inside,
    int x0,
    int x1,
  ) {
    if (!inside) {
      out.fillRange(start, start + length, _grey);
      return;
    }
    out.fillRange(start, start + min(x0, length), _grey);
    if (x1 < length) out.fillRange(start + x1, start + length, _grey);
  }
}
