import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'models/face_box.dart';

/// Finds every face in a camera frame (pose detection only ever sees one
/// person, a face detector sees all of them).
abstract class IFaceLocator {
  Future<List<FaceBox>> locate(InputImage image);

  Future<void> close();
}
