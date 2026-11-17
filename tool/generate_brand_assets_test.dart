// Renders the KnockUp placeholder brand images (ember tile + glove) to PNG for
// flutter_launcher_icons and flutter_native_splash.
//
//   flutter test tool/generate_brand_assets_test.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
//
// When the real artwork arrives, replace the PNGs in assets/brand/ and run the
// last two commands only.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/theme/app_colors.dart';

const double _px = 1024;
const String _outDir = 'assets/brand';

void main() {
  setUpAll(() async {
    // Tests have no fonts by default: load the Material icons for the glove.
    final loader = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await loader.load();
  });

  testWidgets('generate brand assets', (tester) async {
    // iOS / legacy Android icon: full-bleed square, the OS rounds the corners.
    await _render(
      tester,
      'app_icon.png',
      const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        child: _Glove(scale: 0.58),
      ),
    );
    // Android adaptive icon: gradient background + glove inside the safe zone.
    await _render(
      tester,
      'app_icon_background.png',
      const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.primaryGradient),
      ),
    );
    await _render(tester, 'app_icon_foreground.png', const _Glove(scale: 0.4));
    // Native splash: rounded ember tile on a transparent canvas.
    await _render(
      tester,
      'splash_logo.png',
      Center(
        child: Container(
          width: _px * 0.5,
          height: _px * 0.5,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(_px * 0.15),
          ),
          child: const _Glove(scale: 0.6),
        ),
      ),
    );
  });
}

class _Glove extends StatelessWidget {
  final double scale;

  const _Glove({required this.scale});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => Center(
        child: Icon(
          Icons.sports_mma_rounded,
          color: AppColors.onPrimary,
          size: box.biggest.shortestSide * scale,
          shadows: const [
            Shadow(
              color: Color(0x40000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _render(WidgetTester tester, String name, Widget child) async {
  final key = GlobalKey();
  tester.view
    ..physicalSize = const Size(_px, _px)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: SizedBox(width: _px, height: _px, child: child),
      ),
    ),
  );
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_outDir/$name');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}
