import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../domain/subject_lock/appearance_signature.dart';
import '../../domain/subject_lock/subject_lock.dart';

/// Turns the camera frame the reference photo was taken from into a small
/// image of the user's head and shoulders, for showing on screen.
///
/// The photo stays in memory only (never written to disk).
class ReferencePhotoBuilder {
  static const int width = 96;
  static const int maxHeight = 160;

  /// [mirror]: flip left-right to match the mirrored front-camera preview.
  static Future<ui.Image?> build(
    FramePixels pixels,
    SubjectObservation photo, {
    required bool mirror,
  }) async {
    final Rectangle<double>? box = photo.box;
    if (box == null || box.width <= 1) return null;
    // Head to a little below the shoulders.
    final double bottom = min(box.bottom, photo.anchor.y + 0.8 * photo.bodyScale);
    final Rectangle<double> crop = Rectangle<double>(
      box.left,
      box.top,
      box.width,
      max(1.0, bottom - box.top),
    );
    final int height = (width * crop.height / crop.width).round().clamp(
      1,
      maxHeight,
    );
    final Uint8List rgba = pixels.uprightRgba(
      crop,
      width,
      height,
      mirror: mirror,
    );
    final Completer<ui.Image?> done = Completer<ui.Image?>();
    try {
      ui.decodeImageFromPixels(
        rgba,
        width,
        height,
        ui.PixelFormat.rgba8888,
        done.complete,
      );
    } catch (_) {
      return null;
    }
    return done.future;
  }
}
