import 'dart:async';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../domain/subject_lock/appearance_signature.dart';
import '../../domain/subject_lock/face_alignment.dart';
import '../../domain/subject_lock/i_face_embedder.dart';
import '../../domain/subject_lock/subject_lock.dart';
import '../mappers/pose_subject_mapper.dart';
import 'sface_embedder.dart';

/// Runs the subject lock's face checks without ever holding up the pose
/// loop: at most one check at a time, only when the lock wants one and the
/// tracked pose shows a clear frontal face. The caller never awaits it; a
/// finished check is handed to the lock and reported through `onResult`.
class SubjectFaceChecker {
  final PoseSubjectMapper _mapper;
  IFaceEmbedder? _embedder;
  bool _busy = false;
  int _generation = 0;

  /// Without [embedder], [load] creates the SFace one.
  SubjectFaceChecker({IFaceEmbedder? embedder, PoseSubjectMapper? mapper})
    : _mapper = mapper ?? const PoseSubjectMapper() {
    _embedder = embedder;
  }

  bool get isAvailable => _embedder != null;

  /// Loads the face model (no-op when an embedder was given). Without it the
  /// lock simply works on look and movement.
  Future<void> load() async {
    _embedder ??= await SFaceEmbedder.create();
  }

  /// Call for every tracked frame after [SubjectLock.observe].
  void maybeCheck(
    SubjectLock lock,
    Pose pose,
    FramePixels pixels,
    int frameMs,
    void Function(FaceCheckResult result, int tookMs) onResult, {
    void Function()? onNoFace,
  }) {
    final IFaceEmbedder? embedder = _embedder;
    if (embedder == null || _busy || !lock.wantsFaceCheck(frameMs)) return;
    final FacePoints? face = _mapper.checkableFace(pose, pixels);
    if (face == null) return;
    _busy = true;
    lock.faceCheckStarted(frameMs);
    final int generation = _generation;
    final Stopwatch took = Stopwatch()..start();
    unawaited(
      embedder
          .embed(pixels, face)
          .then((List<double>? embedding) {
            // The lock was reset / the photo retaken meanwhile.
            if (generation != _generation) return;
            if (embedding == null) {
              onNoFace?.call();
              return;
            }
            onResult(
              lock.addFace(embedding, frameMs),
              took.elapsedMilliseconds,
            );
          })
          .catchError((Object _) => onNoFace?.call())
          .whenComplete(() => _busy = false),
    );
  }

  /// Drops the results of checks still running (call when the lock is reset).
  void cancelRunning() => _generation++;

  Future<void> close() async {
    _generation++;
    await _embedder?.close();
    _embedder = null;
  }
}
