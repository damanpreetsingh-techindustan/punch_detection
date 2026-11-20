import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/services/usage_service.dart';
import '../../../drills/data/drill_service.dart';
import '../../data/learn_service.dart';
import '../../domain/lesson.dart';

/// One lesson: the figure controls (speed, pause) and the practice, either a
/// counted bag drill (opens Get Ready) or a follow-along timer with spoken
/// cues right here.
class LessonController extends GetxController {
  final LearnService service = LearnService.to;

  /// The lesson shown (route argument: its id). Changes on "Next lesson".
  late final Rxn<Lesson> current = Rxn<Lesson>(
    service.byId(Get.arguments as String? ?? ''),
  );
  Lesson? get lesson => current.value;

  final RxBool slowMotion = false.obs;
  final RxBool paused = false.obs;

  // Follow-along practice.
  final RxBool following = false.obs;
  final RxInt secondsLeft = 0.obs;
  final RxString cue = ''.obs;
  Timer? _clock;
  Timer? _cueTimer;
  int _cueIndex = 0;
  FlutterTts? _tts;

  /// Reactive (reads [current] and the completed set).
  bool get isDone {
    final l = current.value;
    return l != null && service.completed.contains(l.id);
  }

  Lesson? get next {
    final all = service.lessons;
    final i = all.indexWhere((l) => l.id == lesson?.id);
    return i >= 0 && i + 1 < all.length ? all[i + 1] : null;
  }

  void toggleSpeed() => slowMotion.toggle();
  void togglePause() => paused.toggle();

  void startPractice() {
    final l = lesson;
    if (l == null) return;
    if (l.practice.isDrill) {
      if (UsageService.to.limitReached) {
        AppNavigator.toPaywall(fromLimit: true);
        return;
      }
      DrillService.to.select(l.practice.drill!);
      AppNavigator.toGetReady(
        sessionType: 'prompt',
        difficulty: l.practice.drill!.title,
      );
      return;
    }
    _startFollow(l.practice);
  }

  void _startFollow(LessonPractice p) {
    stopFollow();
    following.value = true;
    secondsLeft.value = p.followSeconds;
    _cueIndex = 0;
    _nextCue(p);
    _cueTimer = Timer.periodic(
      Duration(milliseconds: p.cueIntervalMs),
      (_) => _nextCue(p),
    );
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      secondsLeft.value--;
      if (secondsLeft.value <= 0) _finishFollow();
    });
  }

  void _nextCue(LessonPractice p) {
    if (p.cues.isEmpty) return;
    cue.value = p.cues[_cueIndex % p.cues.length];
    _cueIndex++;
    HapticFeedback.selectionClick();
    _speak(cue.value);
  }

  Future<void> _finishFollow() async {
    stopFollow();
    HapticFeedback.heavyImpact();
    _speak('Done. Great work.');
    if (lesson != null) await service.markComplete(lesson!.id);
    cue.value = '';
  }

  void stopFollow() {
    _clock?.cancel();
    _cueTimer?.cancel();
    following.value = false;
  }

  Future<void> _speak(String text) async {
    try {
      _tts ??= FlutterTts();
      await _tts!.stop();
      await _tts!.speak(text);
    } catch (_) {
      // No voice available (or tests): the cue still shows on screen.
    }
  }

  void openNext() {
    final n = next;
    if (n == null) {
      Get.back();
      return;
    }
    if (service.isLocked(n)) {
      AppNavigator.toPaywall();
      return;
    }
    stopFollow();
    paused.value = false;
    current.value = n;
  }

  @override
  void onClose() {
    stopFollow();
    try {
      _tts?.stop();
    } catch (_) {}
    super.onClose();
  }
}
