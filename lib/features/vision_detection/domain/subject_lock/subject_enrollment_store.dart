import 'dart:ui' as ui;

import 'subject_lock.dart';

/// Result of the reference-photo step on the pre-check screen, handed to the
/// session that starts next.
class SubjectEnrollment {
  /// The lock that learned the user (state locked). Null when skipped.
  final SubjectLock? lock;

  /// The reference photo shown on screen. In memory only.
  final ui.Image? photo;

  /// True when the user skipped the photo: the session runs without the
  /// lock.
  final bool skipped;

  const SubjectEnrollment.captured(SubjectLock this.lock, this.photo)
    : skipped = false;

  const SubjectEnrollment.skipped() : lock = null, photo = null, skipped = true;
}

/// One-shot hand-off from the pre-check screen to the session: put before
/// navigating, taken once by the session. Nothing in it = the session takes
/// the reference photo itself (old flow).
class SubjectEnrollmentStore {
  static SubjectEnrollment? _pending;

  static void put(SubjectEnrollment enrollment) {
    if (!identical(_pending?.photo, enrollment.photo)) {
      _pending?.photo?.dispose();
    }
    _pending = enrollment;
  }

  /// Returns the pending result and forgets it (the caller owns the photo).
  static SubjectEnrollment? take() {
    final SubjectEnrollment? pending = _pending;
    _pending = null;
    return pending;
  }

  static void clear() {
    _pending?.photo?.dispose();
    _pending = null;
  }

  static bool get hasPending => _pending != null;
}
