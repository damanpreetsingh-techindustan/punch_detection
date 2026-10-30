import 'package:flutter/material.dart';

/// How the pose skeleton overlay is drawn (colours and line width).
///
/// Pure value object: the painter only reads it, so a new look is a new
/// style here, not a change in the painter.
@immutable
class SkeletonStyle {
  final Color lineColor;
  final Color jointFillColor;
  final Color jointBorderColor;
  final double lineWidth;

  const SkeletonStyle({
    required this.lineColor,
    required this.jointFillColor,
    required this.jointBorderColor,
    this.lineWidth = 6.5,
  });

  /// User is a valid camera user (close enough): cyan lines, red joints with a
  /// white outline. The original overlay look.
  static const SkeletonStyle active = SkeletonStyle(
    lineColor: Color(0xFF00B4D8),
    jointFillColor: Color(0xFFFF1744),
    jointBorderColor: Color(0xFFFFFFFF),
  );

  /// User is not valid for the camera (too far, or not seen as a person):
  /// faded grey lines and joints, so the overlay reads as inactive.
  static const SkeletonStyle inactive = SkeletonStyle(
    lineColor: Color(0xB393A1B8),
    jointFillColor: Color(0xFF6B7280),
    jointBorderColor: Color(0x9993A1B8),
  );

  @override
  bool operator ==(Object other) =>
      other is SkeletonStyle &&
      other.lineColor == lineColor &&
      other.jointFillColor == jointFillColor &&
      other.jointBorderColor == jointBorderColor &&
      other.lineWidth == lineWidth;

  @override
  int get hashCode =>
      Object.hash(lineColor, jointFillColor, jointBorderColor, lineWidth);
}
