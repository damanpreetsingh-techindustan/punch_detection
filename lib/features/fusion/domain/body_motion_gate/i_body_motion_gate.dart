import 'models/body_motion_evaluation.dart';
import 'models/body_motion_frame.dart';

/// Abstract contract for body-motion gating strategies (DIP & ISP).
///
/// Answers "did the user's upper body move around this impact?", so a loud
/// sound + a bump on the mount while the user stands still is not a punch.
/// The session controller depends on this interface only; the measuring rule
/// lives in an implementation (see `LandmarkMotionGate`) and can be swapped
/// or faked in tests.
abstract class IBodyMotionGate {
  /// Descriptive name of the strategy (for logs).
  String get name;

  /// Adds one camera frame (call for every analysed pose of a real person).
  void addFrame(BodyMotionFrame frame);

  /// Measures movement around the audio spike at [audioTsMs].
  ///
  /// Always computes the score (so it can be logged while the gate is off).
  /// [isRequired] false → the returned state is notRequired.
  BodyMotionEvaluation evaluate({
    required int audioTsMs,
    required double minScore,
    required bool isRequired,
  });

  /// Number of frames currently kept (diagnostics / tests).
  int get frameCount;

  /// Clears all frames (session end, user left the frame).
  void reset();
}
