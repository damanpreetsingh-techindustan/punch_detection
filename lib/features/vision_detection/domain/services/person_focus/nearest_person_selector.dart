import '../../../../../core/utils/constants.dart';
import 'models/face_box.dart';

/// Outcome of one face check.
class PersonSelection {
  /// The person to focus on, or null when no focus is needed (0 or 1 face).
  final FaceBox? target;

  /// True when this check moved the focus to a different person.
  final bool switched;

  const PersonSelection({required this.target, this.switched = false});
}

/// Chooses the nearest person (the biggest face) when several are in view.
///
/// Sticky, so the focus does not flicker between two people at a similar
/// distance:
///  - the current person is kept while still seen;
///  - another face takes over only when it is at least [switchRatio] times
///    bigger for [switchChecks] checks in a row;
///  - when the current face disappears (gloves up, head turned) its last box is
///    kept for [holdMs], so the focus does not jump to a person further away.
/// With only the current person (or nobody) in view, no focus is needed.
///
/// Pure: time is passed in, no ML Kit types.
class NearestPersonSelector {
  final double switchRatio;
  final int switchChecks;
  final int holdMs;

  FaceBox? _current;
  int _lastSeenMs = 0;
  FaceBox? _challenger;
  int _challengeCount = 0;

  NearestPersonSelector({
    this.switchRatio = AppConstants.personFocusSwitchRatio,
    this.switchChecks = AppConstants.personFocusSwitchChecks,
    this.holdMs = AppConstants.personFocusHoldMs,
  });

  FaceBox? get current => _current;

  PersonSelection select(List<FaceBox> faces, {required int nowMs}) {
    final FaceBox? current = _current;
    if (current == null) {
      if (faces.length < 2) return const PersonSelection(target: null);
      _current = _biggest(faces);
      _lastSeenMs = nowMs;
      _clearChallenge();
      return PersonSelection(target: _current);
    }

    final int matchIndex = faces.indexWhere(current.isSamePersonAs);
    if (matchIndex < 0) {
      // Current face not seen: hold its last box for a short time.
      if (nowMs - _lastSeenMs <= holdMs) {
        return PersonSelection(target: current);
      }
      reset();
      return select(faces, nowMs: nowMs);
    }

    final FaceBox matched = faces[matchIndex];
    _current = matched;
    _lastSeenMs = nowMs;
    if (faces.length < 2) {
      // Only the current person in view: nothing to hide.
      _clearChallenge();
      return PersonSelection(target: null);
    }

    final List<FaceBox> others = <FaceBox>[
      for (int i = 0; i < faces.length; i++)
        if (i != matchIndex) faces[i],
    ];
    final FaceBox biggestOther = _biggest(others);
    if (biggestOther.size < matched.size * switchRatio) {
      _clearChallenge();
      return PersonSelection(target: matched);
    }

    final FaceBox? challenger = _challenger;
    _challengeCount =
        challenger != null && biggestOther.isSamePersonAs(challenger)
        ? _challengeCount + 1
        : 1;
    _challenger = biggestOther;
    if (_challengeCount < switchChecks) {
      return PersonSelection(target: matched);
    }

    _current = biggestOther;
    _clearChallenge();
    return PersonSelection(target: biggestOther, switched: true);
  }

  void reset() {
    _current = null;
    _lastSeenMs = 0;
    _clearChallenge();
  }

  void _clearChallenge() {
    _challenger = null;
    _challengeCount = 0;
  }

  static FaceBox _biggest(List<FaceBox> faces) =>
      faces.reduce((FaceBox a, FaceBox b) => b.size > a.size ? b : a);
}
