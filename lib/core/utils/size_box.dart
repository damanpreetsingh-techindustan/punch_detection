import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

extension TextSize on num {
  /// Scales font size down by 2.2 in landscape mode to prevent vertical overflow.
  double ts(BuildContext context) {
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return isLandscape ? (toDouble() / 2.2).sp : toDouble().sp;
  }
}

/// Custom control for explicit font sizes per orientation
double tsLP(BuildContext context, double landscapeSize, double portraitSize) {
  bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
  return isLandscape ? landscapeSize.sp : portraitSize.sp;
}

extension EmptySpace on num {
  /// Responsive height SizedBox
  SizedBox get height => SizedBox(height: (1.sw > 600 ? (toDouble() / 2.2) : toDouble()).sp);

  /// Responsive width SizedBox
  SizedBox get width => SizedBox(width: (1.sw > 600 ? (toDouble() / 2.2) : toDouble()).sp);
}
