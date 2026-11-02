import 'appearance_signature.dart';
import 'face_alignment.dart';

/// Turns the face of the tracked person into an embedding (a list of
/// numbers; the same person's faces give similar lists).
///
/// The subject lock depends on this contract only; the ML Kit + TFLite
/// implementation lives in the data layer (SFaceEmbedder), and tests use
/// fakes.
abstract class IFaceEmbedder {
  /// The embedding of the face near [poseFace] (the pose's own face points,
  /// used to find the face) in [pixels], or null when no clear face is found.
  Future<List<double>?> embed(FramePixels pixels, FacePoints poseFace);

  Future<void> close();
}
