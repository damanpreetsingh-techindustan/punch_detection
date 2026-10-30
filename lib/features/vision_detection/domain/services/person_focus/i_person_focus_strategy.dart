import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// What one [IPersonFocusStrategy.prepare] call did (for the session log).
class PersonFocusResult {
  /// The image to give to the pose detector.
  final InputImage image;

  /// True when everything outside the focused person was hidden.
  final bool masked;

  /// Faces found by a face check in this call, null when no check ran.
  final int? facesSeen;

  /// True when the focus moved to a different person in this call.
  final bool switched;

  const PersonFocusResult({
    required this.image,
    this.masked = false,
    this.facesSeen,
    this.switched = false,
  });
}

/// Decides which image the pose detector sees, so the skeleton follows the
/// right person when several people are in front of the camera.
abstract class IPersonFocusStrategy {
  Future<PersonFocusResult> prepare(InputImage original);

  /// Forgets the focused person (e.g. when the setting is switched).
  void reset();

  Future<void> close();
}
