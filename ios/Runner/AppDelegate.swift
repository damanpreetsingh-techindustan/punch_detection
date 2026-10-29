import AVFoundation
import CoreMotion
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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HyperHitterRawSensors") {
      RawSensorChannels.register(with: registrar)
    }
  }

}

/// Raw accelerometer stream and device info. Dart side:
/// lib/core/services/raw_sensors/raw_accelerometer_service.dart and device_info_channel.dart
final class RawSensorChannels: NSObject {
  private static let accelHandler = RawAccelStreamHandler()
  private static let pcmHandler = PcmCaptureStreamHandler()

  static func register(with registrar: FlutterPluginRegistrar) {
    let events = FlutterEventChannel(
      name: "hyper_hitter/raw_accel", binaryMessenger: registrar.messenger())
    events.setStreamHandler(accelHandler)

    let pcm = FlutterEventChannel(
      name: "hyper_hitter/pcm_capture", binaryMessenger: registrar.messenger())
    pcm.setStreamHandler(pcmHandler)

    let device = FlutterMethodChannel(
      name: "hyper_hitter/device", binaryMessenger: registrar.messenger())
    device.setMethodCallHandler { call, result in
      switch call.method {
      case "info":
        result(deviceInfo())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func deviceInfo() -> [String: Any] {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machine = withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
    }
    return [
      "platform": "ios",
      "manufacturer": "Apple",
      "model": machine,
      "device": UIDevice.current.model,
      "osVersion": UIDevice.current.systemVersion,
    ]
  }
}

/// CoreMotion accelerometer at 100 Hz. Batches (every ~20 ms or 5 samples) are
/// sent as {type: "batch", now, t, x, y, z}: `t` is CMAccelerometerData.timestamp
/// and `now` is ProcessInfo.systemUptime (same time base), both in nanoseconds.
/// Values are converted from g to m/s² and sign-flipped to Android's convention
/// (a phone lying face up reads z = +9.81).
final class RawAccelStreamHandler: NSObject, FlutterStreamHandler {
  private let motion = CMMotionManager()
  private let queue: OperationQueue = {
    let q = OperationQueue()
    q.maxConcurrentOperationCount = 1
    q.name = "hyper-hitter-raw-accel"
    return q
  }()
  private var sink: FlutterEventSink?
  private var batchT: [Int64] = []
  private var batchX: [Double] = []
  private var batchY: [Double] = []
  private var batchZ: [Double] = []
  private var lastFlushNs: Int64 = 0
  private static let gToMs2 = -9.80665

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    guard motion.isAccelerometerAvailable else {
      return FlutterError(code: "no_sensor", message: "No accelerometer", details: nil)
    }
    sink = events
    lastFlushNs = Self.nowNs()
    motion.accelerometerUpdateInterval = 1.0 / 100.0
    motion.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
      guard let self = self, let data = data else { return }
      self.add(data)
    }
    events([
      "type": "info",
      "platform": "ios",
      "sensor": "CMMotionManager.accelerometer",
      "requestedHz": 100,
    ])
    return nil
  }

  private func add(_ data: CMAccelerometerData) {
    batchT.append(Int64(data.timestamp * 1e9))
    batchX.append(data.acceleration.x * Self.gToMs2)
    batchY.append(data.acceleration.y * Self.gToMs2)
    batchZ.append(data.acceleration.z * Self.gToMs2)
    let now = Self.nowNs()
    if batchT.count >= 5 || now - lastFlushNs >= 20_000_000 {
      flush(now)
    }
  }

  private func flush(_ nowNs: Int64) {
    lastFlushNs = nowNs
    if batchT.isEmpty { return }
    let payload: [String: Any] = [
      "type": "batch",
      "now": nowNs,
      "t": batchT,
      "x": batchX,
      "y": batchY,
      "z": batchZ,
    ]
    batchT.removeAll(keepingCapacity: true)
    batchX.removeAll(keepingCapacity: true)
    batchY.removeAll(keepingCapacity: true)
    batchZ.removeAll(keepingCapacity: true)
    DispatchQueue.main.async { [weak self] in self?.sink?(payload) }
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    motion.stopAccelerometerUpdates()
    sink = nil
    return nil
  }

  private static func nowNs() -> Int64 {
    Int64(ProcessInfo.processInfo.systemUptime * 1e9)
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

/// Low-latency microphone capture for the fusionV2 detector: AVAudioEngine with
/// an AVAudioSinkNode (installTap ignores small buffer sizes) and a 5 ms
/// preferred IO buffer (~256 frames at 48 kHz). Buffers are sent to Dart as
/// {type: "pcm", data: PCM16 LE mono at the hardware rate, count,
/// tsNs: buffer host time, now: mach_absolute_time, both in ns, sampleRate};
/// the Dart worker resamples to 16 kHz. Arguments: {measurement: Bool}.
final class PcmCaptureStreamHandler: NSObject, FlutterStreamHandler {
  private var engine: AVAudioEngine?
  private var sink: FlutterEventSink?
  private var timebase = mach_timebase_info_data_t()

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    let args = arguments as? [String: Any]
    let measurement = (args?["measurement"] as? Bool) ?? false
    mach_timebase_info(&timebase)
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(
        .playAndRecord, mode: measurement ? .measurement : .default, options: [.defaultToSpeaker])
      try session.setPreferredIOBufferDuration(0.005)
      try session.setActive(true)
    } catch {
      return FlutterError(code: "session", message: error.localizedDescription, details: nil)
    }
    sink = events
    let engine = AVAudioEngine()
    let input = engine.inputNode
    let format = input.inputFormat(forBus: 0)
    let rate = format.sampleRate
    let interleaved = format.isInterleaved
    let channels = Int(format.channelCount)
    let numer = Int64(timebase.numer)
    let denom = Int64(timebase.denom)
    let sinkNode = AVAudioSinkNode { [weak self] timestamp, frameCount, audioBufferList -> OSStatus in
      guard let self = self else { return noErr }
      let buffers = UnsafeMutableAudioBufferListPointer(
        UnsafeMutablePointer(mutating: audioBufferList))
      guard let first = buffers.first, let raw = first.mData else { return noErr }
      let n = Int(frameCount)
      let floats = raw.assumingMemoryBound(to: Float.self)
      let stride = interleaved ? max(1, channels) : 1
      var bytes = Data(count: n * 2)
      bytes.withUnsafeMutableBytes { (p: UnsafeMutableRawBufferPointer) in
        let out = p.bindMemory(to: Int16.self)
        for i in 0..<n {
          let v = max(-1, min(1, floats[i * stride]))
          out[i] = Int16(v * 32767).littleEndian
        }
      }
      let tsNs = Int64(timestamp.pointee.mHostTime) * numer / denom
      let nowNs = Int64(mach_absolute_time()) * numer / denom
      let payload: [String: Any] = [
        "type": "pcm",
        "data": FlutterStandardTypedData(bytes: bytes),
        "count": n,
        "frame": -1,
        "tsFrame": -1,
        "tsNs": tsNs,
        "now": nowNs,
        "sampleRate": Int(rate),
      ]
      DispatchQueue.main.async { self.sink?(payload) }
      return noErr
    }
    engine.attach(sinkNode)
    engine.connect(input, to: sinkNode, format: format)
    do {
      try engine.start()
    } catch {
      return FlutterError(code: "engine", message: error.localizedDescription, details: nil)
    }
    self.engine = engine
    events([
      "type": "info",
      "platform": "ios",
      "sampleRate": Int(rate),
      "channels": channels,
      "ioBufferDuration": session.ioBufferDuration,
      "mode": session.mode.rawValue,
    ])
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    engine?.stop()
    engine = nil
    sink = nil
    return nil
  }
}
