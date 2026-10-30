import 'dart:math';
import 'dart:ui';
import '../../../../../core/utils/constants.dart';

/// Turns a face box into the area the person's body (shoulders, arms, gloves)
/// can be in: [widthFactor] face widths to each side, [topFactor] face heights
/// above, down to the bottom of the image.
///
/// Pure: works in upright image coordinates.
class BodyRegion {
  final double widthFactor;
  final double topFactor;

  const BodyRegion({
    this.widthFactor = AppConstants.personFocusBodyWidthFactor,
    this.topFactor = AppConstants.personFocusBodyTopFactor,
  });

  Rect fromFace(Rect face, Size uprightImageSize) {
    final double left = face.left - face.width * widthFactor;
    final double right = face.right + face.width * widthFactor;
    final double top = face.top - face.height * topFactor;
    return Rect.fromLTRB(
      max(0.0, left),
      max(0.0, top),
      min(uprightImageSize.width, right),
      uprightImageSize.height,
    );
  }
}
