// Visual check of the figure poses (writes PNGs when OUT is set).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/learn/domain/boxer_moves.dart';
import 'package:punch_detection_demo/features/learn/presentation/widgets/boxer_figure.dart';

const _out = String.fromEnvironment('OUT');

void main() {
  testWidgets('figure poses paint', (tester) async {
    final shots = <String, (String, int)>{
      // Times: first keyframe blends 300 ms, then holds, then the punch.
      'guard': ('stance', 0),
      'jab': ('jab', 300 + 500 + 170 + 60),
      'cross': ('cross', 300 + 500 + 170 + 60),
      'lead_hook': ('lead_hook', 300 + 500 + 220 + 60),
      'rear_hook': ('rear_hook', 300 + 500 + 220 + 60),
      'lead_upper': ('uppercuts', 300 + 400 + 200 + 200 + 60),
      'block': ('defense', 300 + 400 + 200 + 100),
      'roll': ('defense', 3350),
    };
    for (final e in shots.entries) {
      final key = GlobalKey();
      await tester.pumpWidget(
        Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              color: const Color(0xFF16161D),
              width: 300,
              height: 300,
              child: CustomPaint(
                painter: BoxerPainter(
                  move: BoxerMoves.of(e.value.$1),
                  ms: e.value.$2,
                  southpaw: false,
                ),
              ),
            ),
          ),
        ),
      );
      if (_out.isEmpty) continue;
      await tester.runAsync(() async {
        final b =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        final file = await File(
          '$_out/fig_${e.key}.png',
        ).create(recursive: true);
        file.writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
    expect(tester.takeException(), isNull);
  });

  test('moves loop back to their first pose and mirror for southpaw', () {
    for (final m in BoxerMoves.all.values) {
      final start = m.poseAt(0);
      final end = m.poseAt(m.durationMs);
      for (final j in J.values) {
        expect((start[j] - end[j]).distance, lessThan(1e-6), reason: m.id);
      }
      final mirrored = m.poseAt(123).mirrored();
      expect(
        mirrored[J.wristLead].dx,
        closeTo(1 - m.poseAt(123)[J.wristLead].dx, 1e-9),
      );
    }
  });
}
