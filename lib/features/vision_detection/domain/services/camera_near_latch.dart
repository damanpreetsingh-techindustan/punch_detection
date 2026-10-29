import '../../../../core/utils/constants.dart';

/// Keeps a user who was confirmed NEAR counted as near through a short run of
/// "too far" frames.
///
/// Why: distance is measured from the shoulder width on screen. When the boxer
/// throws a hook or stands side-on, the body turns ~90° and the shoulders look
/// narrow, exactly like a user standing far away. That lasts ~200 ms, so the
/// punch would be rejected as "too far". The latch ignores up to
/// [farFramesToLeave] − 1 far frames in a row after a near frame; a user who
/// really walks away keeps producing far frames and is rejected after that.
///
/// A user who was never near (e.g. a person in the background) gets no help:
/// the latch only holds after at least one real near frame.
class CameraNearLatch {
  /// Far frames in a row needed before the user stops counting as near.
  final int farFramesToLeave;

  bool _isNear = false;
  int _farFrames = 0;

  CameraNearLatch({
    this.farFramesToLeave = AppConstants.cameraFarFramesToLeaveNear,
  });

  /// Far frames seen in a row since the last near frame.
  int get farFrames => _farFrames;

  /// Feeds one measured frame. Returns true when the frame should be treated
  /// as near: either it was measured near, or it is a short far run that is
  /// still held.
  bool update({required bool measuredNear}) {
    if (measuredNear) {
      _isNear = true;
      _farFrames = 0;
      return true;
    }
    if (!_isNear) return false;
    _farFrames++;
    if (_farFrames < farFramesToLeave) return true;
    _isNear = false;
    return false;
  }

  /// Forgets the user (no person in frame any more).
  void reset() {
    _isNear = false;
    _farFrames = 0;
  }
}
