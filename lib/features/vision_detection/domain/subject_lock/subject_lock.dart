import 'dart:math';

import '../../../../core/utils/constants.dart';
import 'appearance_signature.dart';
import 'face_identity.dart';
import 'user_match_stats.dart';

/// What the subject lock thinks the tracked pose is.
enum SubjectLockState {
  /// No reference photo yet: waiting for the user to stand in front of the
  /// camera (near, shoulders / face visible).
  waitingForUser,

  /// The user is in place: counting down while they hold still.
  holdStill,

  /// Reference photo taken: learning the user's look (and face) from it and
  /// the next few frames.
  enrolling,

  /// The tracked pose is the user in the reference photo.
  locked,

  /// The tracked pose is someone else: their frames must not count.
  otherPerson,
}

/// One camera frame reduced to what the subject lock needs.
///
/// Pure data (no ML Kit types), so the lock can be unit tested with plain
/// numbers. Built from an ML Kit pose by `PoseSubjectMapper`.
class SubjectObservation {
  /// Time the camera frame arrived (epoch ms).
  final int tMs;

  /// Shoulder midpoint, or the face point when both shoulders are not
  /// visible (upright image pixels).
  final Point<double> anchor;

  /// True when [anchor] is the shoulder midpoint. Anchors of different kinds
  /// are never compared (switching kind is not a movement).
  final bool anchorIsShoulders;

  /// Body width in image pixels (same estimate as the body-motion gate).
  final double bodyScale;

  /// Colours of the clothing (shoulder band + sleeves), null when not visible.
  final AppearanceHistogram? torso;

  /// Colours above the eyes (hair / headgear / forehead), null when not visible.
  final AppearanceHistogram? head;

  /// Box around the person (upright pixels), used to hide them from ML Kit
  /// and to crop the reference photo.
  final Rectangle<double>? box;

  /// True when this frame may be used for the reference photo (the distance
  /// gate says the person is near, so a background person is never taken).
  final bool enrollEligible;

  const SubjectObservation({
    required this.tMs,
    required this.anchor,
    required this.anchorIsShoulders,
    required this.bodyScale,
    this.torso,
    this.head,
    this.box,
    this.enrollEligible = true,
  });
}

/// Result of one frame.
class SubjectDecision {
  final SubjectLockState state;

  /// False = this frame must not count: it shows someone else, or there is
  /// no reference photo yet.
  final bool isUser;

  /// Look match with the reference photo (0-1), null when unknown.
  final double? similarity;

  /// True when the tracked pose jumped or reappeared on this frame.
  final bool isBreak;

  /// True on the frame the reference photo was taken from.
  final bool isPhotoFrame;

  /// Countdown left while [SubjectLockState.holdStill], else null.
  final int? holdStillRemainingMs;

  /// What the recent face checks say.
  final FaceVerdict faceVerdict;

  final String reason;

  const SubjectDecision({
    required this.state,
    required this.isUser,
    required this.similarity,
    required this.isBreak,
    required this.reason,
    this.isPhotoFrame = false,
    this.holdStillRemainingMs,
    this.faceVerdict = FaceVerdict.none,
  });
}

/// Result of one face check given to [SubjectLock.addFace].
class FaceCheckResult {
  /// Cosine with the face template; null while the template is being built
  /// or when the check was ignored.
  final double? cosine;
  final FaceVerdict verdict;
  final SubjectLockState state;

  /// True when this check changed [state].
  final bool changedState;
  final String reason;

  const FaceCheckResult({
    required this.cosine,
    required this.verdict,
    required this.state,
    required this.changedState,
    required this.reason,
  });
}

/// Keeps the camera on the user in the reference photo.
///
/// ML Kit pose detection follows ONE person: "the most prominent" one. When
/// someone else walks in, or the user is hidden for a moment, ML Kit can
/// switch to that other person without telling us. Three signals decide who
/// is tracked, each where it is reliable:
///
///  1. CONTINUITY (every frame, physical): a person cannot teleport. A jump
///     of the shoulder midpoint larger than [jumpBase] + [jumpPer100Ms] ×
///     (time / 100 ms) body widths, or a gap of more than [gapMs] without a
///     person, is a BREAK: the next frames may be someone else.
///  2. LOOK (every frame, cheap): colours of the clothing and hair vs the
///     reference photo. Its accept / reject levels are learned from the
///     user's own scores this session ([UserMatchStats]), because clothes,
///     light and camera change what a "good" match is. Strong mismatches
///     ([confirmFramesAfterBreak] right after a break, [confirmFramesDrift]
///     otherwise) → [SubjectLockState.otherPerson].
///  3. FACE (when a clear frontal face is visible, a few times a second):
///     the face embedding vs the faces seen while the photo was taken
///     ([FaceIdentity]). It tells apart people in the same clothes and
///     outranks the look: face "other" blocks at once, face "user" keeps or
///     brings back the lock (and re-learns the look when the look kept
///     failing, i.e. the clothes or the light changed).
///
/// After a change (a break), a visible face must prove it is the user: an
/// "unsure" face then counts as someone else until it says "user" (the
/// user's own face scores clearly as "user" when visible; a look-alike
/// often only reaches "unsure"). While the same person is tracked, "unsure"
/// (head turned, blur) decides nothing.
///
/// Losing the lock is easy, getting it back needs proof: once someone else
/// is tracked, the look alone may bring the lock back only if no face was
/// checked since the tracked person changed; otherwise the face must say
/// "user". (A person who leans into a shadow can look like the user's
/// clothes; their face does not.)
///
/// Fail-open once locked: a frame without any evidence (look hidden, no face)
/// counts as the user. The user is only blocked by evidence that it is
/// someone else, never by missing evidence.
///
/// Pure: no clocks, no ML Kit / TFLite types; time comes from the inputs.
class SubjectLock {
  final int holdStillMs;
  final double holdStillMaxMove;
  final int enrollFrames;
  final int enrollMinSamples;
  final int gapMs;
  final double jumpBase;
  final double jumpPer100Ms;
  final int liveWindowFrames;
  final int minLiveSamples;
  final int confirmFramesAfterBreak;
  final int confirmFramesDrift;
  final int recoverFrames;

  /// Frames after a break that still count as "right after a break".
  final int recentBreakFrames;

  /// How long one steering attempt hides the wrong person, and the pause
  /// before the next attempt.
  final int steerMaxMs;
  final int steerCooldownMs;

  /// Time between face checks while the same person is tracked.
  final int faceCheckIntervalMs;

  /// Weight of the torso match vs. the head match.
  static const double torsoWeight = 0.7;

  final FaceIdentity _face;
  final UserMatchStats _stats;

  SubjectLock({
    this.holdStillMs = AppConstants.subjectHoldStillMs,
    this.holdStillMaxMove = AppConstants.subjectHoldStillMaxMove,
    this.enrollFrames = AppConstants.subjectEnrollFrames,
    this.enrollMinSamples = AppConstants.subjectEnrollMinSamples,
    this.gapMs = AppConstants.subjectGapMs,
    this.jumpBase = AppConstants.subjectJumpBase,
    this.jumpPer100Ms = AppConstants.subjectJumpPer100Ms,
    this.liveWindowFrames = AppConstants.subjectLiveWindowFrames,
    this.minLiveSamples = AppConstants.subjectMinLiveSamples,
    this.confirmFramesAfterBreak = AppConstants.subjectConfirmFramesAfterBreak,
    this.confirmFramesDrift = AppConstants.subjectConfirmFramesDrift,
    this.recoverFrames = AppConstants.subjectRecoverFrames,
    this.recentBreakFrames = AppConstants.subjectRecentBreakFrames,
    this.steerMaxMs = AppConstants.subjectSteerMaxMs,
    this.steerCooldownMs = AppConstants.subjectSteerCooldownMs,
    this.faceCheckIntervalMs = AppConstants.subjectFaceCheckIntervalMs,
    FaceIdentity? face,
    UserMatchStats? stats,
  }) : _face = face ?? FaceIdentity(),
       _stats = stats ?? UserMatchStats();

  SubjectLockState _state = SubjectLockState.waitingForUser;
  int _holdStillStartMs = 0;
  Point<double>? _holdStillAnchor;
  bool _holdStillAnchorIsShoulders = false;
  AppearanceHistogram? _refTorso;
  AppearanceHistogram? _refHead;
  final List<AppearanceHistogram> _enrollTorso = <AppearanceHistogram>[];
  final List<AppearanceHistogram> _enrollHead = <AppearanceHistogram>[];
  int _enrolledFrames = 0;
  final List<AppearanceHistogram> _liveTorso = <AppearanceHistogram>[];
  final List<AppearanceHistogram> _liveHead = <AppearanceHistogram>[];
  SubjectObservation? _last;
  int _framesSinceBreak = 0;
  int _lastBreakMs = 0;
  bool _breakSinceLock = false;

  /// False from a break until the face says "user" again: after the tracked
  /// person may have changed, a visible face must prove it is the user.
  bool _verifiedSinceBreak = true;
  int _lastFaceCheckMs = 0;
  int _strikes = 0;
  int _matches = 0;
  Rectangle<double>? _otherPersonBox;
  int _steerStartMs = 0;

  SubjectLockState get state => _state;

  /// True once the reference photo is taken and learned.
  bool get isLocked =>
      _state == SubjectLockState.locked ||
      _state == SubjectLockState.otherPerson;

  /// False when no colours could be learned from the photo: the look then
  /// never rejects anyone (the face still can).
  bool get hasSignature => _refTorso != null || _refHead != null;

  bool get hasFaceTemplate => _face.hasTemplate;

  /// Learning progress after the photo, 0-1 (for the capture screen).
  double get enrollProgress =>
      enrollFrames <= 0 ? 1 : min(1.0, _enrolledFrames / enrollFrames);

  /// Faces collected for the face template, 0-1 (for the capture screen).
  double get faceTemplateProgress => _face.hasTemplate
      ? 1
      : min(1.0, _face.enrolledFaces / max(1, _face.templateFaces));

  /// Current learned look levels (for logs).
  double get acceptLevel => _stats.accept;
  double get rejectLevel => _stats.reject;

  /// Average reference / live colour (torso, else head) for the debug dots.
  YuvColor? get referenceColor => (_refTorso ?? _refHead)?.meanColor;
  YuvColor? get liveColor =>
      (_liveTorso.isNotEmpty
              ? AppearanceHistogram.pooled(_liveTorso)
              : AppearanceHistogram.pooled(_liveHead))
          .meanColor;

  SubjectDecision observe(SubjectObservation obs) {
    final bool isBreak = _isBreak(obs);
    _last = obs;
    if (isBreak) {
      _framesSinceBreak = 0;
      _lastBreakMs = obs.tMs;
      if (isLocked) _breakSinceLock = true;
      _verifiedSinceBreak = false;
      _liveTorso.clear();
      _liveHead.clear();
      _face.clearScores();
      _strikes = 0;
      _matches = 0;
      // Someone new: the wrong person may have left, look again.
      if (_state == SubjectLockState.otherPerson) {
        _state = SubjectLockState.locked;
      }
    } else {
      _framesSinceBreak++;
    }

    switch (_state) {
      case SubjectLockState.waitingForUser:
      case SubjectLockState.holdStill:
        return _awaitPhoto(obs, isBreak);
      case SubjectLockState.enrolling:
        return _enroll(obs, isBreak);
      case SubjectLockState.locked:
      case SubjectLockState.otherPerson:
        return _check(obs, isBreak);
    }
  }

  /// True when a face check should start now (the caller also needs a clear
  /// frontal face and no check already running). While the photo is taken
  /// it collects faces for the template; right after the tracked person
  /// changed it checks as fast as checks finish; otherwise every
  /// [faceCheckIntervalMs].
  bool wantsFaceCheck(int nowMs) {
    if (_isCollectingFaces) {
      return _face.enrolledFaces < _face.maxTemplateFaces;
    }
    if (!_face.hasTemplate || !isLocked) return false;
    if (_face.recentScoreCount < _face.votes) return true;
    return nowMs - _lastFaceCheckMs >= faceCheckIntervalMs;
  }

  void faceCheckStarted(int nowMs) => _lastFaceCheckMs = nowMs;

  /// A finished face check of the frame that arrived at [frameMs].
  FaceCheckResult addFace(List<double> embedding, int frameMs) {
    if (frameMs < _lastBreakMs) {
      return _faceResult(null, false, 'ignored: from before a change');
    }
    if (_isCollectingFaces) {
      _face.enroll(embedding);
      return _faceResult(
        null,
        false,
        'reference face ${_face.enrolledFaces}'
        '${_face.hasTemplate ? ' (template ready)' : ''}',
      );
    }
    final double? cosine = _face.score(embedding);
    if (cosine == null || !isLocked) {
      return _faceResult(null, false, 'ignored: no face template');
    }
    _face.addScore(cosine, frameMs);
    final FaceVerdict verdict = _face.verdict(frameMs);
    final SubjectLockState before = _state;
    String reason = 'face ${verdict.name}';
    if (_state == SubjectLockState.locked && _faceSaysOther(verdict)) {
      _becomeOther(frameMs, _last?.box);
      reason = _faceOtherReason(verdict);
    } else if (verdict == FaceVerdict.user) {
      // The look kept failing (it would have called this someone else) but
      // the face says user: clothes or light changed. Learn the look again.
      final bool relearn = _strikes >= confirmFramesDrift && _relearnLook();
      _state = SubjectLockState.locked;
      _verifiedSinceBreak = true;
      _strikes = 0;
      _otherPersonBox = null;
      if (relearn) {
        reason = 'user (face); look re-learned';
      } else {
        reason = before == SubjectLockState.otherPerson
            ? 'user is back (face)'
            : 'user (face)';
      }
    }
    return _faceResult(cosine, _state != before, reason, verdict: verdict);
  }

  /// Region to hide from ML Kit on the next frame, or null. Hides the wrong
  /// person for [steerMaxMs], then pauses [steerCooldownMs] before trying
  /// again (the user may simply not be in frame).
  Rectangle<double>? steerBox(int nowMs) =>
      _isSteering(nowMs) ? _otherPersonBox : null;

  /// Retake the reference photo (Re-lock button). Movement continuity is
  /// kept.
  void relock() {
    _state = SubjectLockState.waitingForUser;
    _holdStillAnchor = null;
    _refTorso = null;
    _refHead = null;
    _enrollTorso.clear();
    _enrollHead.clear();
    _enrolledFrames = 0;
    _liveTorso.clear();
    _liveHead.clear();
    _face.reset();
    _stats.bootstrap(const <double>[]);
    _breakSinceLock = false;
    _verifiedSinceBreak = true;
    _strikes = 0;
    _matches = 0;
    _otherPersonBox = null;
  }

  /// Forget everything (new camera / new session).
  void reset() {
    relock();
    _last = null;
    _framesSinceBreak = 0;
    _lastBreakMs = 0;
  }

  bool get _isCollectingFaces =>
      _state == SubjectLockState.holdStill ||
      _state == SubjectLockState.enrolling ||
      (_state == SubjectLockState.locked &&
          !_breakSinceLock &&
          !_face.hasTemplate);

  FaceCheckResult _faceResult(
    double? cosine,
    bool changed,
    String reason, {
    FaceVerdict verdict = FaceVerdict.none,
  }) => FaceCheckResult(
    cosine: cosine,
    verdict: verdict,
    state: _state,
    changedState: changed,
    reason: reason,
  );

  SubjectDecision _awaitPhoto(SubjectObservation obs, bool isBreak) {
    // The photo needs a near person whose colours can be read.
    final bool ready =
        obs.enrollEligible && (obs.torso != null || obs.head != null);
    if (_state == SubjectLockState.holdStill) {
      final Point<double>? start = _holdStillAnchor;
      final bool moved =
          start == null ||
          obs.anchorIsShoulders != _holdStillAnchorIsShoulders ||
          obs.anchor.distanceTo(start) >
              holdStillMaxMove * max(obs.bodyScale, 1.0);
      if (!ready || isBreak || moved) {
        // Faces collected so far may be someone else's: start over.
        _state = SubjectLockState.waitingForUser;
        _face.reset();
      } else if (obs.tMs - _holdStillStartMs >= holdStillMs) {
        // This frame is the reference photo.
        _state = SubjectLockState.enrolling;
        _enrollTorso.clear();
        _enrollHead.clear();
        _enrolledFrames = 0;
        final SubjectDecision first = _enroll(obs, false);
        return SubjectDecision(
          state: first.state,
          isUser: first.isUser,
          similarity: null,
          isBreak: isBreak,
          isPhotoFrame: true,
          reason: 'reference photo taken',
        );
      }
    }
    if (_state == SubjectLockState.waitingForUser && ready) {
      _state = SubjectLockState.holdStill;
      _holdStillStartMs = obs.tMs;
      _holdStillAnchor = obs.anchor;
      _holdStillAnchorIsShoulders = obs.anchorIsShoulders;
    }
    final bool holding = _state == SubjectLockState.holdStill;
    return SubjectDecision(
      state: _state,
      isUser: false,
      similarity: null,
      isBreak: isBreak,
      holdStillRemainingMs: holding
          ? max(0, holdStillMs - (obs.tMs - _holdStillStartMs))
          : null,
      reason: holding
          ? 'hold still for the reference photo'
          : 'waiting for the user for the reference photo',
    );
  }

  SubjectDecision _enroll(SubjectObservation obs, bool isBreak) {
    // Learn ONE continuous person: a break means the next frames may be
    // someone else's, so take the photo again.
    if (isBreak) {
      relock();
      return _awaitPhoto(obs, isBreak);
    }
    if (obs.enrollEligible) {
      if (obs.torso != null) _enrollTorso.add(obs.torso!);
      if (obs.head != null) _enrollHead.add(obs.head!);
      _enrolledFrames++;
    }
    if (_enrolledFrames < enrollFrames) {
      return SubjectDecision(
        state: _state,
        isUser: false,
        similarity: null,
        isBreak: isBreak,
        reason: 'learning the user ($_enrolledFrames/$enrollFrames)',
      );
    }
    final AppearanceHistogram torso = AppearanceHistogram.pooled(_enrollTorso);
    final AppearanceHistogram head = AppearanceHistogram.pooled(_enrollHead);
    _refTorso = torso.sampleCount >= enrollMinSamples ? torso : null;
    _refHead = head.sampleCount >= enrollMinSamples ? head : null;
    // First look levels: the photo frames' own scores (sliding windows, like
    // the live check), with a wide spread floor until boxing frames come.
    _stats.bootstrap(<double>[
      for (int k = 0; k < _enrolledFrames; k++)
        ?_match(
          _window(_enrollTorso, k),
          _window(_enrollHead, k),
        ),
    ]);
    _state = SubjectLockState.locked;
    _breakSinceLock = false;
    // The photo is the verification.
    _verifiedSinceBreak = true;
    _framesSinceBreak = recentBreakFrames;
    return SubjectDecision(
      state: _state,
      isUser: true,
      similarity: null,
      isBreak: isBreak,
      reason: hasSignature
          ? 'locked on the user'
          : 'locked without colours (face / movement only)',
    );
  }

  List<AppearanceHistogram> _window(List<AppearanceHistogram> frames, int k) {
    if (frames.isEmpty) return const <AppearanceHistogram>[];
    final int end = min(k, frames.length - 1) + 1;
    return frames.sublist(max(0, end - liveWindowFrames), end);
  }

  SubjectDecision _check(SubjectObservation obs, bool isBreak) {
    _push(_liveTorso, obs.torso);
    _push(_liveHead, obs.head);
    final double? sim = _match(_liveTorso, _liveHead);
    if (sim != null && sim < _stats.reject) {
      _strikes++;
      _matches = 0;
    } else if (sim != null && sim >= _stats.accept) {
      _strikes = 0;
      _matches++;
    } else if (sim != null) {
      _matches = 0;
    }

    final FaceVerdict face = _face.verdict(obs.tMs);
    final bool justBroke = _framesSinceBreak < recentBreakFrames;
    String reason;
    if (_state == SubjectLockState.locked) {
      final int needed = justBroke
          ? confirmFramesAfterBreak
          : confirmFramesDrift;
      if (_faceSaysOther(face)) {
        _becomeOther(obs.tMs, obs.box);
        reason = _faceOtherReason(face);
      } else if (_strikes >= needed && face != FaceVerdict.user) {
        _becomeOther(obs.tMs, obs.box);
        reason = 'other person (look differs, $_strikes frames)';
      } else {
        reason = _strikes == 0 ? 'user' : 'user? ($_strikes/$needed)';
      }
    } else {
      if (face == FaceVerdict.user) {
        _state = SubjectLockState.locked;
        _verifiedSinceBreak = true;
        _strikes = 0;
        _otherPersonBox = null;
        reason = 'user is back (face)';
      } else if (_matches >= recoverFrames && !_face.seenSinceClear) {
        // Only when no face was checked since the change: a visible face
        // that is not the user's outranks a matching look.
        _state = SubjectLockState.locked;
        _strikes = 0;
        _otherPersonBox = null;
        reason = 'user is back (look)';
      } else {
        // Follow the wrong person, except while they are being hidden (a
        // pose seen then is only the part of them the mask did not cover).
        if (!_isSteering(obs.tMs)) _otherPersonBox = obs.box ?? _otherPersonBox;
        reason = face == FaceVerdict.none
            ? 'other person'
            : 'other person (face ${face.name})';
      }
    }

    // Right after a break the first mismatching frame already does not count,
    // so a newly tracked person never gets a free frame (unless the face
    // already says it is the user).
    final bool isUser =
        _state == SubjectLockState.locked &&
        !(justBroke && _strikes > 0 && face != FaceVerdict.user);
    if (isUser && !justBroke && sim != null) _stats.add(sim);
    return SubjectDecision(
      state: _state,
      isUser: isUser,
      similarity: sim,
      isBreak: isBreak,
      faceVerdict: face,
      reason: sim == null ? '$reason, no colour evidence' : reason,
    );
  }

  /// Face "other" always; face "unsure" only after a break, until the face
  /// has said "user" again (a person who may be new must prove it).
  bool _faceSaysOther(FaceVerdict face) =>
      face == FaceVerdict.other ||
      (face == FaceVerdict.unsure && !_verifiedSinceBreak);

  String _faceOtherReason(FaceVerdict face) => face == FaceVerdict.other
      ? 'other person (face)'
      : 'other person (face not the user\'s after a change)';

  void _becomeOther(int tMs, Rectangle<double>? box) {
    _state = SubjectLockState.otherPerson;
    _matches = 0;
    _otherPersonBox = box;
    _steerStartMs = tMs;
  }

  /// Takes the current live window as the new reference look. False when
  /// the window has too few colours to learn from.
  bool _relearnLook() {
    final AppearanceHistogram torso = AppearanceHistogram.pooled(_liveTorso);
    final AppearanceHistogram head = AppearanceHistogram.pooled(_liveHead);
    if (torso.sampleCount < minLiveSamples && head.sampleCount < minLiveSamples) {
      return false;
    }
    _refTorso = torso.sampleCount >= minLiveSamples ? torso : null;
    _refHead = head.sampleCount >= minLiveSamples ? head : null;
    // Old levels belong to the old look: measure again from the next frames.
    _stats.bootstrap(const <double>[]);
    _strikes = 0;
    return true;
  }

  bool _isSteering(int nowMs) {
    if (_state != SubjectLockState.otherPerson || _otherPersonBox == null) {
      return false;
    }
    final int elapsed = nowMs - _steerStartMs;
    if (elapsed <= steerMaxMs) return true;
    if (elapsed >= steerMaxMs + steerCooldownMs) {
      _steerStartMs = nowMs;
      return true;
    }
    return false;
  }

  bool _isBreak(SubjectObservation obs) {
    final SubjectObservation? last = _last;
    if (last == null) return true;
    final int dt = obs.tMs - last.tMs;
    if (dt < 0 || dt > gapMs) return true;
    if (obs.anchorIsShoulders != last.anchorIsShoulders) return false;
    final double jump = obs.anchor.distanceTo(last.anchor) /
        max(last.bodyScale, 1.0);
    return jump > jumpBase + jumpPer100Ms * dt / 100;
  }

  void _push(List<AppearanceHistogram> window, AppearanceHistogram? frame) {
    if (frame == null) return;
    window.add(frame);
    if (window.length > liveWindowFrames) window.removeAt(0);
  }

  /// Look match of a window of frames with the reference, null when unknown.
  double? _match(
    List<AppearanceHistogram> torsoWindow,
    List<AppearanceHistogram> headWindow,
  ) {
    double sum = 0;
    double weight = 0;
    void addRegion(
      AppearanceHistogram? reference,
      List<AppearanceHistogram> window,
      double regionWeight,
    ) {
      if (reference == null || window.isEmpty) return;
      final AppearanceHistogram live = AppearanceHistogram.pooled(window);
      if (live.sampleCount < minLiveSamples) return;
      sum += regionWeight * reference.similarity(live);
      weight += regionWeight;
    }

    addRegion(_refTorso, torsoWindow, torsoWeight);
    addRegion(_refHead, headWindow, 1 - torsoWeight);
    return weight == 0 ? null : sum / weight;
  }
}
