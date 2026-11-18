import 'dart:async';
import 'dart:math';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/services/audio_level/android_call_mode_audio.dart';
import '../../../../core/services/audio_level/i_audio_level_service.dart';
import '../../../../core/services/audio_level/record_audio_level_service.dart';
import '../../../drills/data/drill_service.dart';
import '../../../drills/domain/drill_program.dart';
import '../../../drills/domain/round_clock.dart';
import 'free_session_controller.dart';

/// Prompt session: the Free session's detection (audio + vibration + camera
/// impact window, reference photo, subject lock, distance gate) plus spoken
/// number callouts. The callouts do not change how punches are counted.
class PromptSessionController extends FreeSessionController {
  PromptSessionController({
    IAudioLevelService? audioLevelService,
    super.vibrationService,
    FlutterTts? flutterTts,
  }) : _flutterTts = flutterTts ?? FlutterTts(),
       super(
         audioLevelService:
             audioLevelService ??
             RecordAudioLevelService(
               enableSubBlockPcm: AppConstants.useSubBlockPcmLevels,
               // ANDROID_CALL_MODE_AEC (no effect on iOS).
               useAndroidCallMode: AndroidCallModeAudio.isEnabled,
             ),
       );

  @override
  String get sessionTypeId => 'prompt';

  // TTS Engine for speaking prompt numbers
  final FlutterTts _flutterTts;
  final RxBool isTtsEnabled = true.obs;
  bool _isTtsSpeaking = false;
  int _lastTtsSpeechStartTimeMs = 0;
  int _lastTtsSpeechEndTimeMs = 0;

  bool get isTtsSpeaking => _isTtsSpeaking;
  int get lastTtsSpeechStartTimeMs => _lastTtsSpeechStartTimeMs;
  int get lastTtsSpeechEndTimeMs => _lastTtsSpeechEndTimeMs;

  // Prompt difficulty tier: 'beginner' (1.2s), 'intermediate' (0.6s), 'advanced' (0.3s)
  final RxString difficulty = 'beginner'.obs;

  final RxInt promptNumber = 1.obs;
  final RxString promptText = '1 - 2'.obs;
  final RxList<int> currentComboSequence = <int>[1, 2].obs;

  /// +1 on every call, so the screen can restart its countdown ring even when
  /// the same number is called twice in a row (promptNumber would not change).
  final RxInt promptTick = 0.obs;
  List<int> _activeCombo = [1, 2];
  int _currentComboStepIndex = 0;

  /// Combo after the current one, picked early so the bag can preview it.
  List<int>? _upcomingCombo;

  /// The number that will be called next (faint ring on the bag).
  final RxnInt nextNumber = RxnInt();

  /// A punch was counted since the current call (the bag target turns green).
  final RxBool currentCallHit = false.obs;

  // ─── Drill program & rounds (screen and calls only; not detection) ───────

  /// The drill picked on the Drills page; null = the original difficulty
  /// presets with [AppConstants.comboList].
  DrillProgram? program;

  RoundClock? _clock;
  Timer? _roundTimer;
  final Rx<RoundPhase> roundPhase = RoundPhase.work.obs;
  final RxInt round = 1.obs;
  final RxInt roundSecondsLeft = 0.obs;
  /// 0 = open-ended drill. Observable, so the round banner's Obx always
  /// listens to something (it reads [hasRounds] first).
  final RxInt roundsTotal = 0.obs;
  int get totalRounds => roundsTotal.value;
  bool get hasRounds => roundsTotal.value > 0;

  /// Punch counting is held off during rest (same gate as the pause menu).
  bool _restGateClosed = false;

  List<List<int>> get _comboPool => program?.combos ?? AppConstants.comboList;

  Timer? _promptTimer;
  Timer? _promptWarmupTimer;

  // ─── Drill score (screen and results only; detection does not read it) ───
  // A call is answered when at least one punch is counted before the next
  // call. The last call of the session is not scored.

  /// Calls answered in a row right now, and the best run this session.
  final RxInt streak = 0.obs;
  final RxInt bestStreak = 0.obs;

  /// Result of the most recent scored call; null before the first one.
  final Rxn<bool> lastCallAnswered = Rxn<bool>();
  int _callsMade = 0;
  int _callsAnswered = 0;
  int _countAtCall = 0;

  /// The first call after a pause is not scored: no punch could be counted
  /// for the call that was showing when the user paused.
  bool _skipNextScore = false;
  bool _callsPaused = false;
  final List<Worker> _scoreWorkers = <Worker>[];

  @override
  DrillScore get drillScore => DrillScore(
    difficulty: difficulty.value,
    bestStreak: bestStreak.value,
    callsAnswered: _callsAnswered,
    callsMade: _callsMade,
  );

  @override
  void onInit() {
    super.onInit();
    _readPromptArguments();
    _loadProgram();
    _initTts();
    _scoreWorkers.addAll([
      ever<int>(promptTick, _scoreCall),
      ever<int>(punchCount, _onCountForScore),
    ]);
    _startPromptRotation();
    _startRoundClock();
  }

  void _loadProgram() {
    if (!Get.isRegistered<DrillService>()) return;
    program = DrillService.to.active.value;
    if (program != null) difficulty.value = program!.title;
  }

  void _scoreCall(int tick) {
    final int count = punchCount.value;
    if (_skipNextScore) {
      _skipNextScore = false;
    } else if (tick > 1) {
      final bool answered = count > _countAtCall;
      _callsMade++;
      if (answered) _callsAnswered++;
      streak.value = answered ? streak.value + 1 : 0;
      if (streak.value > bestStreak.value) bestStreak.value = streak.value;
      lastCallAnswered.value = answered;
    }
    _countAtCall = count;
  }

  /// The count was reset from the pause menu: the score starts over too.
  void _onCountForScore(int count) {
    if (count > _countAtCall) currentCallHit.value = true;
    if (count >= _countAtCall) return;
    _countAtCall = count;
    _callsMade = 0;
    _callsAnswered = 0;
    streak.value = 0;
    bestStreak.value = 0;
    lastCallAnswered.value = null;
  }

  /// Prompt-only route arguments; everything else is read by the Free session.
  void _readPromptArguments() {
    final SessionArguments sessionArgs = SessionArguments.fromArguments(
      Get.arguments,
    );
    isTtsEnabled.value = sessionArgs.ttsEnabled;
    if (sessionArgs.difficulty != null && sessionArgs.difficulty!.isNotEmpty) {
      difficulty.value = sessionArgs.difficulty!;
    }
  }

  void _initTts() async {
    // ANDROID_CALL_MODE_AEC: speak on the voice-call stream so the mic's echo
    // canceller removes the prompt voice. iOS keeps flutter_tts below.
    if (AndroidCallModeAudio.isEnabled) {
      try {
        await AndroidCallModeAudio.initTts(
          language: 'en-US',
          rate: 1.0, // Same speed as flutter_tts setSpeechRate(0.5) on Android.
          pitch: 1.0,
          onStart: () {
            _isTtsSpeaking = true;
            _lastTtsSpeechStartTimeMs = DateTime.now().millisecondsSinceEpoch;
          },
          onDone: _markTtsEnded,
          onError: (_) => _markTtsEnded(),
          onCancel: _markTtsEnded,
        );
      } catch (e) {
        developer.log(
          'Call mode TTS init error: $e',
          name: 'PromptSessionController',
        );
      }
      return;
    }

    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);

      // On iOS: Configure Audio Session Category so TTS audio playback routes to connected Bluetooth Earbuds/Headphones!
      await _flutterTts
          .setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ], IosTextToSpeechAudioMode.defaultMode);

      _flutterTts.setStartHandler(() {
        _isTtsSpeaking = true;
        _lastTtsSpeechStartTimeMs = DateTime.now().millisecondsSinceEpoch;
      });
      _flutterTts.setCompletionHandler(_markTtsEnded);
      _flutterTts.setErrorHandler((msg) => _markTtsEnded());
      _flutterTts.setCancelHandler(_markTtsEnded);
    } catch (e) {
      developer.log('TTS init error: $e', name: 'PromptSessionController');
    }
  }

  void _markTtsEnded() {
    _isTtsSpeaking = false;
    _lastTtsSpeechEndTimeMs = DateTime.now().millisecondsSinceEpoch;
  }

  void _speakSingleNumber(int number) => _speak('$number');

  void _speak(String text) async {
    if (!isTtsEnabled.value) return;
    try {
      _isTtsSpeaking = true;
      _lastTtsSpeechStartTimeMs = DateTime.now().millisecondsSinceEpoch;
      // ANDROID_CALL_MODE_AEC: native speak() flushes the previous number itself.
      if (AndroidCallModeAudio.isEnabled) {
        await AndroidCallModeAudio.speak(text);
        return;
      }
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (e) {
      _isTtsSpeaking = false;
      developer.log('TTS speak error: $e', name: 'PromptSessionController');
    }
  }

  void _tickComboStep() {
    // If we reached the end of the current active combo sequence, pick a new random combination from comboList
    if (_currentComboStepIndex >= _activeCombo.length) {
      _activeCombo = _upcomingCombo ?? _randomCombo();
      _upcomingCombo = _randomCombo();
      _currentComboStepIndex = 0;
      currentComboSequence.assignAll(_activeCombo);
    }

    final int numberToSpeak = _activeCombo[_currentComboStepIndex];
    promptNumber.value = numberToSpeak;
    promptText.value = '$numberToSpeak'; // Show ONLY ONE number on UI

    _speakSingleNumber(numberToSpeak);
    _currentComboStepIndex++;
    nextNumber.value = _currentComboStepIndex < _activeCombo.length
        ? _activeCombo[_currentComboStepIndex]
        : _upcomingCombo?.first;
    currentCallHit.value = false;
    promptTick.value++;
  }

  List<int> _randomCombo() {
    final list = _comboPool;
    return list[Random().nextInt(list.length)];
  }

  int get promptRotationIntervalMs {
    if (program != null) return program!.callIntervalMs;
    final String diff = difficulty.value.toLowerCase().trim();
    if (diff == 'advanced') return 300; // 0.3s cadence per number
    if (diff == 'intermediate') return 600; // 0.6s cadence per number
    return 1200; // 1.2s cadence per number - Beginner default
  }

  void _startPromptRotation() {
    _promptTimer?.cancel();
    _promptWarmupTimer?.cancel();
    final int warmupMs = AppConstants.warmUpDurationInMiliSeconds.round();
    _promptWarmupTimer = Timer(Duration(milliseconds: warmupMs), () {
      if (isClosed) return;
      _currentComboStepIndex =
          _activeCombo.length; // Force fresh combo selection on session start
      _upcomingCombo = null;
      _tickComboStep();
      _promptTimer?.cancel();
      _promptTimer = Timer.periodic(
        Duration(milliseconds: promptRotationIntervalMs),
        (timer) {
          _tickComboStep();
        },
      );
    });
  }

  /// Pause menu open: no more calls, the voice stops mid-word and the round
  /// clock stops.
  @override
  void onSessionPaused() {
    if (_callsPaused) return;
    _callsPaused = true;
    _stopCalls();
  }

  /// Pause menu closed: calls continue where the combo left off (unless it's
  /// rest time, then they start with the next round).
  @override
  void onSessionResumed() {
    if (!_callsPaused || isClosed) return;
    _callsPaused = false;
    if (roundPhase.value != RoundPhase.work) return;
    _skipNextScore = true;
    // A short beat before the first call, so the user is back in stance.
    _startCalls(delayMs: 600);
  }

  void _startCalls({required int delayMs}) {
    _promptTimer?.cancel();
    _promptWarmupTimer?.cancel();
    _promptWarmupTimer = Timer(Duration(milliseconds: delayMs), () {
      if (isClosed || _callsPaused) return;
      _tickComboStep();
      _promptTimer = Timer.periodic(
        Duration(milliseconds: promptRotationIntervalMs),
        (_) => _tickComboStep(),
      );
    });
  }

  void _stopCalls() {
    _promptTimer?.cancel();
    _promptWarmupTimer?.cancel();
    _stopSpeaking();
    nextNumber.value = null;
  }

  // ─── Rounds ──────────────────────────────────────────────────────────────

  void _startRoundClock() {
    final plan = program?.roundPlan;
    if (plan == null || plan.isOpen) return;
    _clock = RoundClock(plan);
    roundsTotal.value = plan.rounds;
    _syncRound();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_callsPaused || isClosed) return;
      _onRoundEvent(_clock!.tick());
      _syncRound();
    });
  }

  void _syncRound() {
    final c = _clock;
    if (c == null) return;
    round.value = c.round;
    roundPhase.value = c.phase;
    roundSecondsLeft.value = c.secondsLeft;
  }

  void _onRoundEvent(RoundEvent event) {
    switch (event) {
      case RoundEvent.none:
        break;
      case RoundEvent.restStarted:
        _stopCalls();
        if (!_restGateClosed) {
          _restGateClosed = true;
          notifySettingsViewOpened();
        }
        HapticFeedback.heavyImpact();
        _speak('Rest');
      case RoundEvent.restEndingSoon:
        HapticFeedback.mediumImpact();
      case RoundEvent.roundStarted:
        _openRestGate();
        HapticFeedback.heavyImpact();
        _speak('Round ${_clock!.round}');
        _skipNextScore = true;
        _startCalls(delayMs: 1200);
      case RoundEvent.finished:
        _stopCalls();
        HapticFeedback.heavyImpact();
        _speak('Time');
        Timer(const Duration(milliseconds: 1500), () {
          if (!isClosed) finishSession();
        });
    }
  }

  void _openRestGate() {
    if (!_restGateClosed) return;
    _restGateClosed = false;
    notifySettingsViewClosed();
  }

  @override
  void finishSession() {
    _roundTimer?.cancel();
    _openRestGate();
    super.finishSession();
  }

  void _stopSpeaking() {
    try {
      if (AndroidCallModeAudio.isEnabled) {
        unawaited(AndroidCallModeAudio.stop());
      } else {
        _flutterTts.stop().catchError((_) {});
      }
    } catch (_) {}
    _markTtsEnded();
  }

  @override
  void onClose() {
    for (final w in _scoreWorkers) {
      w.dispose();
    }
    _promptTimer?.cancel();
    _promptWarmupTimer?.cancel();
    _roundTimer?.cancel();
    try {
      _flutterTts.stop().catchError((_) {});
    } catch (_) {}
    // ANDROID_CALL_MODE_AEC: release the native TTS (call mode itself is
    // left when the Free session stops the mic).
    unawaited(AndroidCallModeAudio.shutdownTts());
    super.onClose();
  }
}
