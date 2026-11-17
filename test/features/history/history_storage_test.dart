import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/history/data/datasources/local_history_datasource.dart';
import 'package:punch_detection_demo/features/history/data/repositories/history_repository_impl.dart';
import 'package:punch_detection_demo/features/history/domain/entities/lifetime_summary_stats.dart';
import 'package:punch_detection_demo/features/history/domain/entities/workout_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalHistoryDatasource datasource;
  late HistoryRepositoryImpl repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    datasource = LocalHistoryDatasource();
    repository = HistoryRepositoryImpl(localDatasource: datasource);
  });

  group('Phase 8: Local Storage Persistence Unit Tests', () {
    test(
      '1. WorkoutRecord JSON serialization and deserialization works seamlessly',
      () {
        const record = WorkoutRecord(
          id: 'rec_1',
          dateIso: '2026-07-31T12:00:00Z',
          durationSeconds: 180,
          totalPunches: 42,
          averageReactionMs: 310.5,
          bestReactionMs: 250,
          detectionMode: 'fusion',
        );

        final json = record.toJson();
        final restored = WorkoutRecord.fromJson(json);

        expect(restored, equals(record));
      },
    );

    test(
      '2. LocalHistoryDatasource writes, reads, and clears workout records',
      () async {
        const rec1 = WorkoutRecord(
          id: '1',
          dateIso: '2026-07-31',
          durationSeconds: 180,
          totalPunches: 30,
          averageReactionMs: 340.0,
          bestReactionMs: 280,
          detectionMode: 'fusion',
        );

        await repository.saveWorkoutRecord(rec1);

        final list = await repository.getWorkoutHistory();
        expect(list.length, equals(1));
        expect(list.first.id, equals('1'));

        await repository.clearHistory();
        final emptyList = await repository.getWorkoutHistory();
        expect(emptyList.isEmpty, isTrue);
      },
    );

    test('3. LifetimeSummaryStats calculates correct aggregates', () {
      const list = [
        WorkoutRecord(
          id: '1',
          dateIso: '2026-07-31',
          durationSeconds: 180,
          totalPunches: 50,
          averageReactionMs: 300.0,
          bestReactionMs: 220,
          detectionMode: 'fusion',
        ),
        WorkoutRecord(
          id: '2',
          dateIso: '2026-07-31',
          durationSeconds: 180,
          totalPunches: 30,
          averageReactionMs: 400.0,
          bestReactionMs: 280,
          detectionMode: 'fusion',
        ),
      ];

      final stats = LifetimeSummaryStats.fromRecords(list);

      expect(stats.totalWorkouts, equals(2));
      expect(stats.totalPunches, equals(80));
      expect(stats.lifetimeAvgReactionMs, equals(350.0));
      expect(stats.bestReactionMs, equals(220));
    });

    test(
      '4. Saved sessions survive a restart (new datasource instance)',
      () async {
        const drill = WorkoutRecord(
          id: 'd1',
          dateIso: '2026-11-17T18:00:00',
          durationSeconds: 120,
          totalPunches: 90,
          averageReactionMs: 0,
          bestReactionMs: 0,
          detectionMode: 'fusion',
          sessionType: 'prompt',
          difficulty: 'advanced',
          bestStreak: 12,
          callsAnswered: 80,
          callsMade: 100,
        );
        await repository.saveWorkoutRecord(drill);

        final restarted = HistoryRepositoryImpl(
          localDatasource: LocalHistoryDatasource(),
        );
        final list = await restarted.getWorkoutHistory();
        expect(list, equals([drill]));
      },
    );

    test('5. Newest first; saving the same id twice keeps one copy', () async {
      WorkoutRecord rec(String id, int punches) => WorkoutRecord(
        id: id,
        dateIso: '2026-11-17T10:00:00',
        durationSeconds: 60,
        totalPunches: punches,
        averageReactionMs: 0,
        bestReactionMs: 0,
        detectionMode: 'fusion',
      );
      await repository.saveWorkoutRecord(rec('a', 1));
      await repository.saveWorkoutRecord(rec('b', 2));
      await repository.saveWorkoutRecord(rec('a', 3));

      final list = await repository.getWorkoutHistory();
      expect(list.map((r) => r.id), equals(['a', 'b']));
      expect(list.first.totalPunches, equals(3));
    });

    test('6. Records saved before the drill fields existed still load', () {
      final old = datasource.decodeList(
        '[{"id":"x","dateIso":"2026-07-31","durationSeconds":60,'
        '"totalPunches":5,"averageReactionMs":0,"bestReactionMs":0}]',
      );
      expect(old.single.sessionType, equals('free'));
      expect(old.single.bestStreak, equals(0));
      expect(old.single.detectionMode, equals('fusion'));
    });

    test(
      '7. Unreadable saved data gives an empty history, not a crash',
      () async {
        SharedPreferences.setMockInitialValues({
          'workout_history_v1': 'not json',
        });
        expect(await LocalHistoryDatasource().readAllRecords(), isEmpty);
      },
    );
  });
}
