import 'dart:async';
import 'dart:math';
import 'dart:developer' as developer;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/services/audio_level/android_call_mode_audio.dart';
import '../../../../core/services/audio_level/i_audio_level_service.dart';
import '../../../../core/services/audio_level/record_audio_level_service.dart';
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
  List<int> _activeCombo = [1, 2];
  int _currentComboStepIndex = 0;

  Timer? _promptTimer;
  Timer? _promptWarmupTimer;

  @override
  void onInit() {
    super.onInit();
    _readPromptArguments();
    _initTts();
    _startPromptRotation();
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

  void _speakSingleNumber(int number) async {
    if (!isTtsEnabled.value) return;
    try {
      _isTtsSpeaking = true;
      _lastTtsSpeechStartTimeMs = DateTime.now().millisecondsSinceEpoch;
      // ANDROID_CALL_MODE_AEC: native speak() flushes the previous number itself.
      if (AndroidCallModeAudio.isEnabled) {
        await AndroidCallModeAudio.speak('$number');
        return;
      }
      await _flutterTts.stop();
      await _flutterTts.speak('$number');
    } catch (e) {
      _isTtsSpeaking = false;
      developer.log('TTS speak error: $e', name: 'PromptSessionController');
    }
  }

  void _tickComboStep() {
    // If we reached the end of the current active combo sequence, pick a new random combination from comboList
    if (_currentComboStepIndex >= _activeCombo.length) {
      final List<List<int>> list = AppConstants.comboList;
      _activeCombo = list[Random().nextInt(list.length)];
      _currentComboStepIndex = 0;
      currentComboSequence.assignAll(_activeCombo);
    }

    final int numberToSpeak = _activeCombo[_currentComboStepIndex];
    promptNumber.value = numberToSpeak;
    promptText.value = '$numberToSpeak'; // Show ONLY ONE number on UI

    _speakSingleNumber(numberToSpeak);
    _currentComboStepIndex++;
  }

  int get promptRotationIntervalMs {
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

  @override
  void onClose() {
    _promptTimer?.cancel();
    _promptWarmupTimer?.cancel();
    try {
      _flutterTts.stop().catchError((_) {});
    } catch (_) {}
    // ANDROID_CALL_MODE_AEC: release the native TTS (call mode itself is
    // left when the Free session stops the mic).
    unawaited(AndroidCallModeAudio.shutdownTts());
    super.onClose();
  }
}
