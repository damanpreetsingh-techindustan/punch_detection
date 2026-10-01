import 'package:flutter/material.dart';

class CommonFunction {
  /// Checks if current screen orientation is Landscape.
  static bool checkOrientationLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }
}
