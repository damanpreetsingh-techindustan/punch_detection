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

  /// The tracked pose is the user in the reference photo: their frames count.
  locked,

  /// The tracked pose may have changed (the tracker lost the person or jumped,
  /// or a face check failed). Nothing counts until the face proves who it is.
  verifying,

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

  /// Why the tracked pose may be someone new from this frame on (it reappeared
  /// or jumped), null while the same person is followed.
  final String? breakReason;

  /// True on the frame the reference photo was taken from.
  final bool isPhotoFrame;

  /// Countdown left while [SubjectLockState.holdStill], else null.
  final int? holdStillRemainingMs;

  final String reason;

  const SubjectDecision({
    required this.state,
    required this.isUser,
    required this.similarity,
    required this.breakReason,
    required this.reason,
    this.isPhotoFrame = false,
    this.holdStillRemainingMs,
  });

  bool get isBreak => breakReason != null;
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

  /// True when two different faces were seen during the photo, which was
  /// therefore thrown away.
  final bool faceConflict;
  final String reason;

  const FaceCheckResult({
    required this.cosine,
    required this.verdict,
    required this.state,
    required this.changedState,
    required this.reason,
    this.faceConflict = false,
  });
}

/// Decides whether the tracked pose is the user in the reference photo.
///
/// ML Kit pose detection follows ONE person and can move to someone else
/// without telling us: when it loses the user it picks whoever is most
/// prominent. So identity is verified, then tracked:
///
///  1. FACE proves who the tracked pose is. Each check counts on its own
///     ([FaceIdentity]): "user" → [SubjectLockState.locked]. Not the user →
///     frames stop counting at once, and after [faceOtherChecks] such checks
///     in a row it is [SubjectLockState.otherPerson].
///  2. CONTINUITY carries that proof between face checks, so a guard or a
///     turned head does not matter while the same person is followed. Anything
///     that may have changed the person is a BREAK: the tracker reported no
///     pose ([poseLost]), a gap of more than [gapMs], or a jump of the shoulder
///     midpoint larger than [jumpBase] + [jumpPer100Ms] × (time / 100 ms) body
///     widths. After a break nothing counts until the face proves it again.
///  3. LOOK (colours of the clothing and hair, levels learned per session by
///     [UserMatchStats]) can only take trust away: other people can match the
///     user's look (0.92-0.94 for a face scoring 0.3 in a real session), so
///     with a face template it never proves anyone. It catches a slow drift
///     onto someone whose face is not visible, and marks a stranger as
///     [SubjectLockState.otherPerson] so steering can look for the user.
///
/// Without a face template (face model unavailable) the look has to stand in
/// and can bring the lock back. With neither, only continuity is left.
///
/// Requiring proof after a break costs the user little: a real session lost no
/// pose in 16 s of the user boxing, and a check takes about 300 ms.
///
/// Pure: no clocks, no ML Kit / TFLite types; time comes from the inputs.
class SubjectLock {
  final int holdStillMs;
  final double holdStillMaxMove;
  final int enrollFrames;
  final int enrollMinSamples;
  final int gapMs;
  final int faceOtherChecks;
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

  /// How long a "user" face check overrules a look that disagrees.
  final int faceTrustMs;

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
    this.faceOtherChecks = AppConstants.subjectFaceOtherChecks,
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
    this.faceTrustMs = AppConstants.subjectFaceTrustMs,
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
  int _lastFaceCheckMs = 0;

  /// Frame of the last "user" face check on this track; null when there is
  /// none or a later check disagreed.
  int? _faceUserAtMs;
  int _notUserChecks = 0;
  int _strikes = 0;
  int _matches = 0;
  Rectangle<double>? _otherPersonBox;
  int _steerStartMs = 0;

  SubjectLockState get state => _state;

  /// True once the reference photo is taken and learned.
  bool get isLocked =>
      _state == SubjectLockState.locked ||
      _state == SubjectLockState.verifying ||
      _state == SubjectLockState.otherPerson;

  /// What a frame that does not count is reported as.
  String get blockedMessage => switch (_state) {
    SubjectLockState.verifying => 'Confirming it is you',
    SubjectLockState.otherPerson => 'Other person in view',
    _ => 'Waiting for the reference photo',
  };

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
    final String? breakReason = _breakReasonFor(obs);
    _last = obs;
    if (breakReason != null) {
      _framesSinceBreak = 0;
      _lastBreakMs = obs.tMs;
      if (isLocked) _breakSinceLock = true;
      _liveTorso.clear();
      _liveHead.clear();
      _strikes = 0;
      _matches = 0;
      _faceUserAtMs = null;
      _notUserChecks = 0;
      // A break proves nothing about the new pose. It never clears
      // otherPerson, and it takes away the trust of locked.
      if (_state == SubjectLockState.locked && _canVerify) {
        _state = SubjectLockState.verifying;
      }
    } else {
      _framesSinceBreak++;
    }

    switch (_state) {
      case SubjectLockState.waitingForUser:
      case SubjectLockState.holdStill:
        return _awaitPhoto(obs, breakReason);
      case SubjectLockState.enrolling:
        return _enroll(obs, breakReason);
      case SubjectLockState.locked:
      case SubjectLockState.verifying:
      case SubjectLockState.otherPerson:
        return _check(obs, breakReason);
    }
  }

  /// The pose detector found nobody on this frame. It re-detects from scratch
  /// after that and takes the most prominent person, who may be someone else,
  /// so the next pose is a break however close in time and place it is.
  void poseLost() => _last = null;

  /// The face model cannot run: the lock goes on without the face.
  void dropFaceTemplate() {
    _face.reset();
    if (_state == SubjectLockState.verifying && !_canVerify) {
      _state = SubjectLockState.locked;
    }
  }

  /// True when a face check should start now (the caller also needs a clear
  /// frontal face and no check already running). While the photo is taken
  /// it collects faces for the template; while it is unproven who is tracked
  /// it checks as fast as checks finish; otherwise every [faceCheckIntervalMs].
  bool wantsFaceCheck(int nowMs) {
    if (_isCollectingFaces) {
      return _face.enrolledFaces < _face.maxTemplateFaces;
    }
    if (!_face.hasTemplate || !isLocked) return false;
    if (_state == SubjectLockState.verifying) return true;
    return nowMs - _lastFaceCheckMs >= faceCheckIntervalMs;
  }

  void faceCheckStarted(int nowMs) => _lastFaceCheckMs = nowMs;

  /// A finished face check of the frame that arrived at [frameMs].
  FaceCheckResult addFace(List<double> embedding, int frameMs) {
    if (frameMs < _lastBreakMs) {
      return _faceResult(null, false, 'ignored: from before a change');
    }
    if (_isCollectingFaces) {
      if (!_face.enroll(embedding)) {
        relock();
        return _faceResult(
          null,
          true,
          'two different faces during the photo: taking it again',
          faceConflict: true,
        );
      }
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
    final FaceVerdict verdict = _face.verdictFor(cosine);
    final SubjectLockState before = _state;
    String reason;
    if (verdict == FaceVerdict.user) {
      // The look kept failing (it would have called this someone else) but
      // the face says user: clothes or light changed. Learn the look again.
      final bool relearn = _strikes >= confirmFramesDrift && _relearnLook();
      _state = SubjectLockState.locked;
      _faceUserAtMs = frameMs;
      _notUserChecks = 0;
      _strikes = 0;
      _otherPersonBox = null;
      reason = relearn
          ? 'user (face); look re-learned'
          : before == SubjectLockState.locked
          ? 'user (face)'
          : 'user confirmed (face)';
    } else {
      _faceUserAtMs = null;
      _notUserChecks++;
      if (_state != SubjectLockState.otherPerson &&
          _notUserChecks >= faceOtherChecks) {
        _becomeOther(frameMs, _last?.box);
      } else if (_state == SubjectLockState.locked) {
        _state = SubjectLockState.verifying;
      }
      reason = _state == SubjectLockState.otherPerson
          ? 'other person (face)'
          : 'face does not match';
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
    _faceUserAtMs = null;
    _notUserChecks = 0;
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
    bool faceConflict = false,
  }) => FaceCheckResult(
    cosine: cosine,
    verdict: verdict,
    state: _state,
    changedState: changed,
    reason: reason,
    faceConflict: faceConflict,
  );

  /// False when there is nothing to prove anyone with.
  bool get _canVerify => _face.hasTemplate || hasSignature;

  SubjectDecision _awaitPhoto(SubjectObservation obs, String? breakReason) {
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
      if (!ready || breakReason != null || moved) {
        // Faces collected so far may be someone else's: start over.
        _state = SubjectLockState.waitingForUser;
        _face.reset();
      } else if (obs.tMs - _holdStillStartMs >= holdStillMs) {
        // This frame is the reference photo.
        _state = SubjectLockState.enrolling;
        _enrollTorso.clear();
        _enrollHead.clear();
        _enrolledFrames = 0;
        final SubjectDecision first = _enroll(obs, null);
        return SubjectDecision(
          state: first.state,
          isUser: first.isUser,
          similarity: null,
          breakReason: breakReason,
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
      breakReason: breakReason,
      holdStillRemainingMs: holding
          ? max(0, holdStillMs - (obs.tMs - _holdStillStartMs))
          : null,
      reason: holding
          ? 'hold still for the reference photo'
          : 'waiting for the user for the reference photo',
    );
  }

  SubjectDecision _enroll(SubjectObservation obs, String? breakReason) {
    // Learn ONE continuous person: a break means the next frames may be
    // someone else's, so take the photo again.
    if (breakReason != null) {
      relock();
      return _awaitPhoto(obs, breakReason);
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
        breakReason: breakReason,
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
    _framesSinceBreak = recentBreakFrames;
    return SubjectDecision(
      state: _state,
      isUser: true,
      similarity: null,
      breakReason: breakReason,
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

  SubjectDecision _check(SubjectObservation obs, String? breakReason) {
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

    final bool hasFace = _face.hasTemplate;
    String reason;
    if (_state == SubjectLockState.locked) {
      final int? faceAt = _faceUserAtMs;
      final bool faceVouches = faceAt != null && obs.tMs - faceAt <= faceTrustMs;
      if (_strikes >= confirmFramesDrift && !faceVouches) {
        // Slow drift onto someone else, or the user's clothes or light
        // changed. The face tells which; without one the look has to decide.
        if (hasFace) {
          _state = SubjectLockState.verifying;
          reason = 'look differs ($_strikes frames): checking the face';
        } else {
          _becomeOther(obs.tMs, obs.box);
          reason = 'other person (look differs, $_strikes frames)';
        }
      } else {
        reason = _strikes == 0 ? 'user' : 'user? ($_strikes/$confirmFramesDrift)';
      }
    } else if (!hasFace && _matches >= recoverFrames) {
      _state = SubjectLockState.locked;
      _strikes = 0;
      _otherPersonBox = null;
      reason = 'user is back (look)';
    } else if (_state == SubjectLockState.verifying &&
        // With a face, give it time to answer first: it can clear the user.
        _strikes >= (hasFace ? confirmFramesDrift : confirmFramesAfterBreak)) {
      _becomeOther(obs.tMs, obs.box);
      reason = 'other person (look differs, $_strikes frames)';
    } else if (_state == SubjectLockState.verifying) {
      reason = hasFace
          ? 'waiting for a clear face'
          : 'waiting for a matching look';
    } else {
      // Follow the wrong person, except while they are being hidden (a pose
      // seen then is only the part of them the mask did not cover).
      if (!_isSteering(obs.tMs)) _otherPersonBox = obs.box ?? _otherPersonBox;
      reason = 'other person';
    }

    final bool isUser = _state == SubjectLockState.locked;
    if (isUser && _framesSinceBreak >= recentBreakFrames && sim != null) {
      _stats.add(sim);
    }
    return SubjectDecision(
      state: _state,
      isUser: isUser,
      similarity: sim,
      breakReason: breakReason,
      reason: sim == null ? '$reason, no colour evidence' : reason,
    );
  }

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

  /// Why [obs] may be someone new, null when it continues the tracked person.
  String? _breakReasonFor(SubjectObservation obs) {
    final SubjectObservation? last = _last;
    if (last == null) return 'pose reappeared';
    final int dt = obs.tMs - last.tMs;
    if (dt < 0 || dt > gapMs) return 'gap ${dt}ms';
    if (obs.anchorIsShoulders != last.anchorIsShoulders) return null;
    final double jump = obs.anchor.distanceTo(last.anchor) /
        max(last.bodyScale, 1.0);
    return jump > jumpBase + jumpPer100Ms * dt / 100
        ? 'jump ${jump.toStringAsFixed(2)} body widths'
        : null;
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
