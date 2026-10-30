import 'dart:typed_data';
import 'dart:ui';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../../../core/utils/constants.dart';
import '../../domain/services/person_focus/body_region.dart';
import '../../domain/services/person_focus/i_face_locator.dart';
import '../../domain/services/person_focus/i_person_focus_strategy.dart';
import '../../domain/services/person_focus/models/face_box.dart';
import '../../domain/services/person_focus/nearest_person_selector.dart';
import '../image/frame_masker.dart';

/// Keeps the pose detector on the NEAREST person when several are in view.
///
/// Why: ML Kit pose detection sees one person, and in stream mode it keeps
/// following the first person it found, even when someone else stands closer.
///
/// How: every [checkIntervalMs] the faces in the frame are found
/// ([IFaceLocator]) and the nearest person is chosen ([NearestPersonSelector]).
/// Every frame then hides everything outside that person's body area
/// ([BodyRegion] + [FrameMasker]), so the pose detector only sees them. With
/// one person (or nobody) in view the original frame is used unchanged. Any
/// error also falls back to the original frame.
class NearestFacePersonFocus implements IPersonFocusStrategy {
  final IFaceLocator faceLocator;
  final NearestPersonSelector _selector;
  final BodyRegion bodyRegion;
  final FrameMasker masker;
  final int checkIntervalMs;
  final int Function() _clock;

  int? _lastCheckMs;
  Rect? _keepRegion;

  NearestFacePersonFocus({
    required this.faceLocator,
    NearestPersonSelector? selector,
    this.bodyRegion = const BodyRegion(),
    this.masker = const FrameMasker(),
    this.checkIntervalMs = AppConstants.personFocusCheckIntervalMs,
    int Function()? clock,
  }) : _selector = selector ?? NearestPersonSelector(),
       _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  @override
  Future<PersonFocusResult> prepare(InputImage original) async {
    final InputImageMetadata? metadata = original.metadata;
    final Uint8List? bytes = original.bytes;
    if (metadata == null || bytes == null) {
      return PersonFocusResult(image: original);
    }
    try {
      int? facesSeen;
      bool switched = false;
      final int nowMs = _clock();
      final int? lastCheckMs = _lastCheckMs;
      if (lastCheckMs == null || nowMs - lastCheckMs >= checkIntervalMs) {
        _lastCheckMs = nowMs;
        final List<FaceBox> faces = await faceLocator.locate(original);
        facesSeen = faces.length;
        final PersonSelection selection = _selector.select(faces, nowMs: nowMs);
        switched = selection.switched;
        final FaceBox? target = selection.target;
        _keepRegion = target == null
            ? null
            : bodyRegion.fromFace(target.box, _uprightSize(metadata));
      }

      final Rect? keep = _keepRegion;
      if (keep == null) {
        return PersonFocusResult(
          image: original,
          facesSeen: facesSeen,
          switched: switched,
        );
      }
      final Uint8List? masked = masker.mask(
        bytes: bytes,
        width: metadata.size.width.round(),
        height: metadata.size.height.round(),
        bytesPerRow: metadata.bytesPerRow,
        format: metadata.format,
        rotation: metadata.rotation,
        keepUpright: keep,
      );
      if (masked == null) {
        return PersonFocusResult(
          image: original,
          facesSeen: facesSeen,
          switched: switched,
        );
      }
      return PersonFocusResult(
        image: InputImage.fromBytes(bytes: masked, metadata: metadata),
        masked: true,
        facesSeen: facesSeen,
        switched: switched,
      );
    } catch (_) {
      return PersonFocusResult(image: original);
    }
  }

  @override
  void reset() {
    _selector.reset();
    _keepRegion = null;
    _lastCheckMs = null;
  }

  @override
  Future<void> close() => faceLocator.close();

  /// Image size after ML Kit's rotation (the space of face boxes).
  static Size _uprightSize(InputImageMetadata metadata) {
    final bool swapped =
        metadata.rotation == InputImageRotation.rotation90deg ||
        metadata.rotation == InputImageRotation.rotation270deg;
    return swapped
        ? Size(metadata.size.height, metadata.size.width)
        : metadata.size;
  }
}
