import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../../../core/utils/constants.dart';
import '../../domain/services/person_focus/i_face_locator.dart';
import '../../domain/services/person_focus/models/face_box.dart';

/// [IFaceLocator] backed by ML Kit face detection: fast mode, face tracking on
/// (stable ids across frames), no landmarks / contours / classification.
class MlKitFaceLocator implements IFaceLocator {
  /// Created on first use, so building a session controller (e.g. in tests)
  /// never touches the native plugin.
  FaceDetector? _detector;

  MlKitFaceLocator({FaceDetector? detector}) : _detector = detector;

  FaceDetector get _faceDetector => _detector ??= FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableTracking: true,
      minFaceSize: AppConstants.personFocusMinFaceSize,
    ),
  );

  @override
  Future<List<FaceBox>> locate(InputImage image) async {
    final List<Face> faces = await _faceDetector.processImage(image);
    return faces
        .map(
          (Face face) =>
              FaceBox(box: face.boundingBox, trackingId: face.trackingId),
        )
        .toList();
  }

  @override
  Future<void> close() async {
    final FaceDetector? detector = _detector;
    _detector = null;
    if (detector != null) await detector.close();
  }
}
