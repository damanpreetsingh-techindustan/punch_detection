import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart';
import '../../utils/constants.dart';

/// ANDROID_CALL_MODE_AEC
///
/// Dart side of `CallModeAudioChannel.kt`. Android's echo canceller only removes
/// sound it knows the phone is playing, and only for voice-call audio, so the
/// Prompt session on Android:
///  - puts the phone in call mode (loud speaker) while the mic is recording;
///  - speaks the prompt numbers on the voice-call stream instead of flutter_tts.
///
/// Everything here is a no-op unless [isEnabled] (Android + the constant flag).
class AndroidCallModeAudio {
  AndroidCallModeAudio._();

  static const MethodChannel _channel = MethodChannel(
    'punch_detection_demo/call_mode_audio',
  );

  static bool get isEnabled =>
      AppConstants.androidCallModeEchoCancel && Platform.isAndroid;

  /// Switches to call mode. Returns native diagnostics (echo canceller
  /// availability, audio mode, speaker route, call volume) or null on failure.
  static Future<Map<String, Object?>?> enterCallMode() async {
    if (!isEnabled) return null;
    try {
      final Map<Object?, Object?>? info = await _channel
          .invokeMapMethod<Object?, Object?>('enterCallMode');
      final Map<String, Object?> result = <String, Object?>{
        for (final MapEntry<Object?, Object?> e
            in (info ?? const <Object?, Object?>{}).entries)
          '${e.key}': e.value,
      };
      developer.log('Call mode entered: $result', name: 'AndroidCallModeAudio');
      return result;
    } catch (e) {
      developer.log('enterCallMode failed: $e', name: 'AndroidCallModeAudio');
      return null;
    }
  }

  static Future<void> exitCallMode() async {
    if (!isEnabled) return;
    try {
      await _channel.invokeMethod<void>('exitCallMode');
    } catch (e) {
      developer.log('exitCallMode failed: $e', name: 'AndroidCallModeAudio');
    }
  }

  /// [rate] and [pitch] use Android's native scale (1.0 = normal).
  static Future<void> initTts({
    required String language,
    required double rate,
    required double pitch,
    void Function()? onStart,
    void Function()? onDone,
    void Function(String message)? onError,
    void Function()? onCancel,
  }) async {
    if (!isEnabled) return;
    _channel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'onStart':
          onStart?.call();
        case 'onDone':
          onDone?.call();
        case 'onError':
          onError?.call('${call.arguments}');
        case 'onCancel':
          onCancel?.call();
      }
    });
    await _channel.invokeMethod<void>('initTts', <String, Object?>{
      'language': language,
      'rate': rate,
      'pitch': pitch,
    });
  }

  static Future<void> speak(String text) async {
    if (!isEnabled) return;
    await _channel.invokeMethod<void>('speak', <String, Object?>{'text': text});
  }

  static Future<void> stop() async {
    if (!isEnabled) return;
    await _channel.invokeMethod<void>('stop');
  }

  static Future<void> shutdownTts() async {
    if (!isEnabled) return;
    _channel.setMethodCallHandler(null);
    try {
      await _channel.invokeMethod<void>('shutdownTts');
    } catch (_) {}
  }
}
