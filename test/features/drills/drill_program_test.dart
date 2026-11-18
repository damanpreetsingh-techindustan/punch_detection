import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/drills/data/drill_service.dart';
import 'package:punch_detection_demo/features/drills/domain/bag_targets.dart';
import 'package:punch_detection_demo/features/drills/domain/drill_program.dart';
import 'package:punch_detection_demo/features/drills/domain/round_clock.dart';

void main() {
  group('DrillProgram.tryParse', () {
    test('keeps only numbers 1–6 and clamps the pace', () {
      final p = DrillProgram.tryParse({
        'id': 'x',
        'title': 'X',
        'combos': [
          [1, 9, 2],
          [0, 7],
          [3],
        ],
        'callIntervalMs': 50,
      })!;
      expect(p.combos, [
        [1, 2],
        [3],
      ]);
      expect(p.callIntervalMs, DrillProgram.minIntervalMs);
      expect(p.roundPlan.isOpen, isTrue);
    });

    test('rejects entries without id, title or any valid combo', () {
      expect(
        DrillProgram.tryParse({
          'title': 'X',
          'combos': [
            [1],
          ],
        }),
        isNull,
      );
      expect(
        DrillProgram.tryParse({
          'id': 'x',
          'combos': [
            [1],
          ],
        }),
        isNull,
      );
      expect(
        DrillProgram.tryParse({
          'id': 'x',
          'title': 'X',
          'combos': [
            [8],
          ],
        }),
        isNull,
      );
      expect(DrillProgram.tryParse('nonsense'), isNull);
    });

    test('round trip through JSON', () {
      const p = DrillProgram(
        id: 'c1',
        title: 'Mine',
        combos: [
          [1, 2, 3],
        ],
        callIntervalMs: 600,
        roundPlan: RoundPlan(rounds: 3, roundSeconds: 60, restSeconds: 30),
      );
      final back = DrillProgram.tryParse(jsonDecode(jsonEncode(p.toJson())))!;
      expect(back.combos, p.combos);
      expect(back.roundPlan.rounds, 3);
      expect(back.roundPlan.restSeconds, 30);
    });
  });

  test('built-in programs.json parses completely', () {
    final raw = jsonDecode(
      File('assets/drills/programs.json').readAsStringSync(),
    );
    final programs = DrillService.parseList(raw);
    expect(programs.length, (raw['programs'] as List).length);
    expect(programs.map((p) => p.id).toSet().length, programs.length);
    expect(programs.where((p) => p.category == 'basic').length, 3);
  });

  test('southpaw mirrors every target left↔right', () {
    for (final t in BagTargets.all) {
      final o = BagTargets.positionFor(t.number, southpaw: false);
      final s = BagTargets.positionFor(t.number, southpaw: true);
      expect(s.dx, closeTo(1 - o.dx, 1e-9));
      expect(s.dy, o.dy);
    }
    // Jab sits on the right of centre for orthodox, left for southpaw.
    expect(BagTargets.positionFor(1, southpaw: false).dx, greaterThan(0.5));
    expect(BagTargets.positionFor(1, southpaw: true).dx, lessThan(0.5));
  });

  group('RoundClock', () {
    test('work → rest → work → finished', () {
      final clock = RoundClock(
        const RoundPlan(rounds: 2, roundSeconds: 3, restSeconds: 4),
      );
      final events = <RoundEvent>[];
      for (var i = 0; i < 12; i++) {
        events.add(clock.tick());
      }
      expect(events.where((e) => e != RoundEvent.none).toList(), [
        RoundEvent.restStarted,
        RoundEvent.restEndingSoon,
        RoundEvent.roundStarted,
        RoundEvent.finished,
      ]);
      expect(clock.phase, RoundPhase.done);
      expect(clock.round, 2);
    });

    test('open plan never changes', () {
      final clock = RoundClock(RoundPlan.open);
      for (var i = 0; i < 500; i++) {
        expect(clock.tick(), RoundEvent.none);
      }
      expect(clock.phase, RoundPhase.work);
    });
  });
}
