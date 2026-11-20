import 'package:get/get.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/services/storage_service.dart';
import '../../../drills/data/drill_service.dart';
import '../../../history/domain/entities/workout_record.dart';
import '../../../learn/data/learn_service.dart';
import '../../../history/domain/history_insights.dart';
import '../../../history/domain/repositories/history_repository.dart';

/// What the Results screen celebrates, worked out from the history saved
/// before this session.
class ResultHighlights {
  /// First session ever saved.
  final bool firstSession;
  final bool newMostPunches;
  final bool newBestPace;
  final bool newBestStreak;

  /// Punches compared with the last session of the same mode (null: none).
  final int? punchesVsLast;
  final int todayPunches;
  final int dayStreak;

  const ResultHighlights({
    this.firstSession = false,
    this.newMostPunches = false,
    this.newBestPace = false,
    this.newBestStreak = false,
    this.punchesVsLast,
    this.todayPunches = 0,
    this.dayStreak = 0,
  });

  bool get anyBest => newMostPunches || newBestPace || newBestStreak;
}

class ResultsController extends GetxController {
  final HistoryRepository _history = Get.find<HistoryRepository>();

  late final SessionResultModel result = SessionResultModel.fromArguments(
    Get.arguments,
  );

  /// Null while the history is loading.
  final Rxn<ResultHighlights> highlights = Rxn<ResultHighlights>();

  /// Set when this session was a lesson's practice and completed it.
  final RxnString lessonCompleted = RxnString();

  bool get isDrill => result.sessionType == 'prompt';

  /// Sessions with no counted punch are not saved (nothing to show later).
  bool get isSaved => result.totalPunches > 0;

  double get pace => result.durationSeconds <= 0
      ? 0
      : result.totalPunches * 60 / result.durationSeconds;

  String get title {
    if (!isDrill) return 'Free Fight';
    final d = result.drill?.difficulty;
    if (d == null || d.isEmpty) return 'Reaction Drill';
    return 'Reaction Drill · ${d[0].toUpperCase()}${d.substring(1)}';
  }

  @override
  void onInit() {
    super.onInit();
    // Enables Quick start on the next Get Ready for a few minutes.
    StorageService.to.setLastSessionEnd(DateTime.now());
    _saveAndCompare();
  }

  WorkoutRecord _toRecord() {
    final drill = result.drill;
    return WorkoutRecord(
      id: result.completedAt.microsecondsSinceEpoch.toString(),
      dateIso: result.completedAt.toIso8601String(),
      durationSeconds: result.durationSeconds,
      totalPunches: result.totalPunches,
      averageReactionMs: result.averageReactionTimeMs,
      bestReactionMs: 0,
      detectionMode: result.detectionMode,
      sessionType: result.sessionType,
      difficulty: drill?.difficulty,
      bestStreak: drill?.bestStreak ?? 0,
      callsAnswered: drill?.callsAnswered ?? 0,
      callsMade: drill?.callsMade ?? 0,
    );
  }

  Future<void> _saveAndCompare() async {
    final now = DateTime.now();
    List<WorkoutRecord> before = const [];
    try {
      before = await _history.getWorkoutHistory();
    } catch (_) {}

    final record = _toRecord();
    final bestsBefore = HistoryInsights.bests(before);
    final previous = HistoryInsights.previousOfType(before, result.sessionType);
    final hasHistory = before.isNotEmpty;

    if (isSaved) {
      try {
        await _history.saveWorkoutRecord(record);
      } catch (_) {}
      // Today's usage was already counted live during the session
      // (UsageService), so it is not added again here.
    }

    await _checkLesson();

    final after = isSaved ? [record, ...before] : before;
    final countsForPace =
        record.durationSeconds >= HistoryInsights.minSecondsForPace;
    highlights.value = ResultHighlights(
      firstSession: isSaved && !hasHistory,
      newMostPunches:
          isSaved &&
          hasHistory &&
          record.totalPunches > bestsBefore.mostPunches,
      newBestPace:
          isSaved &&
          hasHistory &&
          countsForPace &&
          record.punchesPerMinute > bestsBefore.bestPace,
      newBestStreak:
          isSaved &&
          isDrill &&
          hasHistory &&
          record.bestStreak > bestsBefore.longestStreak,
      punchesVsLast: previous == null
          ? null
          : record.totalPunches - previous.totalPunches,
      todayPunches: HistoryInsights.punchesOn(after, now),
      dayStreak: HistoryInsights.dayStreak(after, now),
    );
  }

  /// A lesson's practice drill (id `lesson_<id>`) with enough punches
  /// completes the lesson.
  Future<void> _checkLesson() async {
    if (!isDrill ||
        !Get.isRegistered<LearnService>() ||
        !Get.isRegistered<DrillService>()) {
      return;
    }
    try {
      final lesson = await LearnService.to.onDrillFinished(
        DrillService.to.active.value?.id,
        result.totalPunches,
      );
      if (lesson != null) {
        lessonCompleted.value =
            'Lesson ${lesson.number} complete: ${lesson.title}';
      }
    } catch (_) {}
  }

  void trainAgain() => AppNavigator.toGetReady(
    sessionType: result.sessionType,
    difficulty: result.drill?.difficulty,
    replace: true,
  );

  void done() => AppNavigator.toHome();
}
