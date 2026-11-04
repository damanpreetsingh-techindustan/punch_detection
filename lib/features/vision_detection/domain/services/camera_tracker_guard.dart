import '../../../../core/utils/constants.dart';

/// Notices when the pose tracker is stuck on something that is not a person.
///
/// In stream mode the detector keeps following what it is tracking and only
/// looks for the most prominent person again once it loses that. A weak pose on
/// an object can hold on for a long time: on real footage it stayed on balloons
/// for 14 s with two people in view. One blank frame ends the track, so the
/// next frame detects from scratch.
///
/// It only fires on frames that are already refused as "not a person", so it
/// cannot make anything count, and it cannot lose a frame that would have.
class CameraTrackerGuard {
  /// How long a pose must keep being refused before the tracker is reset.
  final int maxRefusedMs;

  int? _refusedSinceMs;
  bool _resetDue = false;

  CameraTrackerGuard({this.maxRefusedMs = AppConstants.cameraTrackerStuckMs});

  /// This frame's pose was refused as not being a person.
  void noteRefused(int tMs) {
    final int since = _refusedSinceMs ??= tMs;
    if (tMs - since >= maxRefusedMs) {
      _resetDue = true;
      _refusedSinceMs = null;
    }
  }

  /// A real person, or no pose at all: the tracker is not stuck.
  void clear() => _refusedSinceMs = null;

  /// True once when the next frame given to the detector should be blank.
  bool takeReset() {
    final bool due = _resetDue;
    _resetDue = false;
    return due;
  }
}
