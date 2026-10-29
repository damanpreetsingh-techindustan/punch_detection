import 'package:flutter/services.dart';

/// Small app-owned platform channel for microphone/session settings the
/// `record` plugin does not expose.
///
/// - Android (`MainActivity.kt`): `capabilities` → whether the UNPROCESSED
///   audio source is supported, native sample rate and buffer size.
/// - iOS (`AppDelegate.swift`): `configureSession` → category playAndRecord,
///   mode `measurement` (or `default`), active.
///
/// Every call is safe: a missing native side (unit tests, old builds) returns
/// an empty map instead of throwing.
class AudioSessionChannel {
  AudioSessionChannel._();

  static const MethodChannel _channel = MethodChannel(
    'hyper_hitter/audio_session',
  );

  static Future<Map<String, Object?>> capabilities() =>
      _invoke('capabilities', const <String, Object?>{});

  /// iOS only: configures the shared AVAudioSession for recording.
  static Future<Map<String, Object?>> configureIosSession({
    required bool measurementMode,
  }) => _invoke('configureSession', <String, Object?>{
    'measurement': measurementMode,
  });

  static Future<Map<String, Object?>> _invoke(
    String method,
    Map<String, Object?> args,
  ) async {
    try {
      final Object? result = await _channel.invokeMethod<Object?>(method, args);
      if (result is Map) {
        return result.map(
          (Object? key, Object? value) => MapEntry(key.toString(), value),
        );
      }
      return const <String, Object?>{};
    } on MissingPluginException {
      return const <String, Object?>{'error': 'missing_native_channel'};
    } catch (e) {
      return <String, Object?>{'error': e.toString()};
    }
  }
}
