import 'dart:isolate';
import 'dart:typed_data';

import '../vision/arm_motion_tracker.dart';

/// Isolate running the [ArmMotionTracker] at the camera rate, so optical flow
/// never blocks audio, the accelerometer or the UI.
///
/// main -> worker: {op: frame, bytes: TransferableTypedData, width, height,
///   rowStride, rotation, t, format: 'luma' | 'bgra'} | {op: pose, t, lw, rw,
///   ls, rs: [x, y, conf]?} | {op: stop}
/// worker -> main: {type: arm, result: ArmMotionResult.toMap()}
void armMotionWorkerMain(SendPort toMain) {
  final ReceivePort inbox = ReceivePort();
  toMain.send(inbox.sendPort);
  final ArmMotionTracker tracker = ArmMotionTracker();
  inbox.listen((Object? message) {
    if (message is! Map) return;
    switch (message['op']) {
      case 'frame':
        final Uint8List bytes = (message['bytes']! as TransferableTypedData)
            .materialize()
            .asUint8List();
        final int width = message['width']! as int;
        final int height = message['height']! as int;
        final int stride = message['rowStride']! as int;
        final int t = message['t']! as int;
        final int rotation = message['rotation'] as int? ?? 0;
        final LumaFrame frame = message['format'] == 'bgra'
            ? LumaFrame.fromBgra(
                bytes,
                width: width,
                height: height,
                rowStride: stride,
                tUs: t,
                rotationDegrees: rotation,
              )
            : LumaFrame(
                data: bytes,
                width: width,
                height: height,
                rowStride: stride,
                tUs: t,
                rotationDegrees: rotation,
              );
        toMain.send(<String, Object?>{
          'type': 'arm',
          'result': tracker.processFrame(frame).toMap(),
        });
      case 'pose':
        List<double>? lm(Object? v) => v is List
            ? <double>[for (final Object? x in v) (x! as num).toDouble()]
            : null;
        tracker.addPose(
          ArmPose(
            tUs: message['t']! as int,
            leftWrist: lm(message['lw']),
            rightWrist: lm(message['rw']),
            leftShoulder: lm(message['ls']),
            rightShoulder: lm(message['rs']),
          ),
        );
      case 'stop':
        inbox.close();
    }
  });
}
