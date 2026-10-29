import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HyperHitterAudioSession") {
      AudioSessionChannel.register(with: registrar)
    }
  }

}

/// App-owned channel for audio-session settings the `record` plugin does not expose.
/// Dart side: lib/core/services/audio_level/audio_session_channel.dart
final class AudioSessionChannel: NSObject {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "hyper_hitter/audio_session", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "configureSession":
        let args = call.arguments as? [String: Any]
        let measurement = (args?["measurement"] as? Bool) ?? false
        result(configureSession(measurement: measurement))
      case "capabilities":
        result(sessionInfo())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Category playAndRecord with mode `measurement` (minimal input processing) or `default`.
  private static func configureSession(measurement: Bool) -> [String: Any] {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(
        .playAndRecord, mode: measurement ? .measurement : .default, options: [.defaultToSpeaker])
      try session.setActive(true)
      var info = sessionInfo()
      info["ok"] = true
      return info
    } catch {
      var info = sessionInfo()
      info["ok"] = false
      info["error"] = error.localizedDescription
      return info
    }
  }

  private static func sessionInfo() -> [String: Any] {
    let session = AVAudioSession.sharedInstance()
    return [
      "category": session.category.rawValue,
      "mode": session.mode.rawValue,
      "sampleRate": session.sampleRate,
      "ioBufferDuration": session.ioBufferDuration,
    ]
  }
}
