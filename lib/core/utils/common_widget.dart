import 'package:flutter/material.dart';
import 'common_function.dart';

class CommonWidget {
  /// Converts layout to Row in Landscape mode and Column in Portrait mode.
  static Widget rowOrColumn(
    BuildContext context, {
    required List<Widget> children,
    bool isExpand = false,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  }) {
    bool isLandscape = CommonFunction.checkOrientationLandscape(context);
    final List<Widget> content = isExpand
        ? children.map((e) => Expanded(child: e)).toList()
        : children;

    if (isLandscape) {
      return Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: content,
      );
    }
    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: content,
    );
  }
}
