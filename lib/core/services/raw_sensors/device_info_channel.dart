import 'package:flutter/services.dart';

/// Phone model / OS version from the app's native channel (no extra plugin).
class DeviceInfoChannel {
  DeviceInfoChannel._();

  static const MethodChannel _channel = MethodChannel('hyper_hitter/device');

  /// Never throws; a missing native side returns `{'error': ...}`.
  static Future<Map<String, Object?>> info() async {
    try {
      final Object? result = await _channel.invokeMethod<Object?>('info');
      if (result is Map) {
        return result.map(
          (Object? k, Object? v) => MapEntry<String, Object?>(k.toString(), v),
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
