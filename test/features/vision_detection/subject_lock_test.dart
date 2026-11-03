import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/subject_lock/appearance_signature.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/subject_lock/face_identity.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/subject_lock/subject_lock.dart';

const YuvColor blueShirt = YuvColor(41, 240, 110);
const YuvColor redShirt = YuvColor(82, 90, 240);
const YuvColor redGlove = YuvColor(70, 100, 220);
const YuvColor darkHair = YuvColor(25, 128, 128);
const double bodyWidth = 200;
const int frameMs = 33;

AppearanceHistogram colours(Map<YuvColor, int> counts) {
  final AppearanceHistogram h = AppearanceHistogram();
  counts.forEach((YuvColor c, int n) {
    for (int i = 0; i < n; i++) {
      h.add(c);
    }
  });
  return h;
}

SubjectObservation person(
  int tMs, {
  double x = 300,
  YuvColor? shirt = blueShirt,
  int gloveSamples = 0,
  bool eligible = true,
}) => SubjectObservation(
  tMs: tMs,
  anchor: Point<double>(x, 250),
  anchorIsShoulders: true,
  bodyScale: bodyWidth,
  torso: shirt == null
      ? null
      : colours(<YuvColor, int>{
          shirt: 36 - gloveSamples,
          if (gloveSamples > 0) redGlove: gloveSamples,
        }),
  head: shirt == null ? null : colours(<YuvColor, int>{darkHair: 12}),
  box: Rectangle<double>(x - 150, 50, 300, 590),
  enrollEligible: eligible,
);

void main() {
  late SubjectLock lock;
  late int t;

  SubjectDecision feed(SubjectObservation Function(int tMs) frame) {
    t += frameMs;
    return lock.observe(frame(t));
  }

  /// Frames for the "hold still" countdown (the last one is the photo).
  int holdStillFrames() => (lock.holdStillMs / frameMs).ceil() + 1;

  /// Stand still for the photo, then until the look is learned.
  void enroll({double x = 300, YuvColor shirt = blueShirt}) {
    for (int i = 0; i < 200 && lock.state != SubjectLockState.locked; i++) {
      feed((int ms) => person(ms, x: x, shirt: shirt));
    }
    expect(lock.state, SubjectLockState.locked);
  }

  setUp(() {
    lock = SubjectLock();
    t = 1000000;
  });

  test('takes the reference photo after the user holds still; nothing counts '
      'before the lock', () {
    final List<SubjectDecision> decisions = <SubjectDecision>[];
    while (lock.state != SubjectLockState.locked && decisions.length < 200) {
      decisions.add(feed((int ms) => person(ms)));
    }
    expect(decisions.first.state, SubjectLockState.holdStill);
    expect(decisions.first.holdStillRemainingMs, lock.holdStillMs);
    final int photo = decisions.indexWhere((SubjectDecision d) => d.isPhotoFrame);
    // The photo is taken when the countdown ends ...
    expect(photo, holdStillFrames() - 1);
    expect(decisions.where((SubjectDecision d) => d.isPhotoFrame).length, 1);
    // ... and learned from it plus the next frames.
    expect(decisions.length, photo + lock.enrollFrames);
    expect(
      decisions.take(decisions.length - 1).map((SubjectDecision d) => d.isUser),
      everyElement(isFalse),
    );
    expect(decisions.last.isUser, isTrue);
    expect(lock.hasSignature, isTrue);
  });

  test('far (not eligible) people are never photographed', () {
    for (int i = 0; i < 200; i++) {
      expect(feed((int ms) => person(ms, eligible: false)).isUser, isFalse);
    }
    expect(lock.state, SubjectLockState.waitingForUser);
  });

  test('no photo is taken while the colours cannot be read', () {
    for (int i = 0; i < 200; i++) {
      feed((int ms) => person(ms, shirt: null));
    }
    expect(lock.state, SubjectLockState.waitingForUser);
  });

  test('moving during the countdown restarts it', () {
    for (int i = 0; i < holdStillFrames() - 5; i++) {
      feed((int ms) => person(ms));
    }
    expect(lock.state, SubjectLockState.holdStill);
    // Steps half a body width (more than holdStillMaxMove).
    final SubjectDecision moved = feed((int ms) => person(ms, x: 400));
    expect(moved.state, SubjectLockState.holdStill);
    expect(moved.holdStillRemainingMs, lock.holdStillMs);
  });

  test('a break while learning takes the photo again', () {
    for (int i = 0; i < holdStillFrames() + 5; i++) {
      feed((int ms) => person(ms));
    }
    expect(lock.state, SubjectLockState.enrolling);
    t += 600; // gone for 0.6 s: the next person may be someone else
    expect(feed((int ms) => person(ms)).state, SubjectLockState.holdStill);
    enroll();
  });

  test('the user boxing (slips, gloves over the chest) is never blocked', () {
    enroll();
    final Random rng = Random(7);
    double x = 300;
    int gated = 0;
    for (int i = 0; i < 600; i++) {
      // Slips: up to 0.45 body widths per frame; gloves cover up to 1/3.
      x += (rng.nextDouble() - 0.5) * 0.9 * bodyWidth;
      x = x.clamp(150, 450);
      final SubjectDecision d = feed(
        (int ms) => person(ms, x: x, gloveSamples: rng.nextInt(13)),
      );
      if (!d.isUser) gated++;
    }
    expect(gated, 0);
    expect(lock.state, SubjectLockState.locked);
  });

  test('a different person tracked after a jump is blocked from the first '
      'frame and confirmed after 2', () {
    enroll();
    final SubjectDecision first = feed(
      (int ms) => person(ms, x: 300 + 2 * bodyWidth, shirt: redShirt),
    );
    expect(first.isBreak, isTrue);
    expect(first.isUser, isFalse);
    expect(first.state, SubjectLockState.locked);
    final SubjectDecision second = feed(
      (int ms) => person(ms, x: 300 + 2 * bodyWidth, shirt: redShirt),
    );
    expect(second.isUser, isFalse);
    expect(second.state, SubjectLockState.otherPerson);
    expect(lock.steerBox(t), isNotNull);
  });

  test('the user coming back (jump) counts at once', () {
    enroll();
    for (int i = 0; i < 5; i++) {
      feed((int ms) => person(ms, x: 700, shirt: redShirt));
    }
    expect(lock.state, SubjectLockState.otherPerson);
    final SubjectDecision back = feed((int ms) => person(ms, x: 300));
    expect(back.isUser, isTrue);
    expect(back.state, SubjectLockState.locked);
  });

  test('the user taking the same spot again counts once the window agrees',
      () {
    enroll();
    for (int i = 0; i < 5; i++) {
      feed((int ms) => person(ms, x: 700, shirt: redShirt));
    }
    // Same place as the other person, no jump: the live window still holds
    // their frames, so the look matches again only once the user's frames
    // fill most of it (then [recoverFrames] matches in a row).
    final List<bool> isUser = <bool>[
      for (int i = 0; i < lock.liveWindowFrames; i++)
        feed((int ms) => person(ms, x: 700)).isUser,
    ];
    expect(isUser.take(2), everyElement(isFalse));
    expect(isUser.last, isTrue);
    expect(lock.state, SubjectLockState.locked);
  });

  test('slow drift onto someone else (no jump) is caught on the 8th frame', () {
    enroll();
    final List<bool> isUser = <bool>[
      for (int i = 0; i < 10; i++)
        feed((int ms) => person(ms, shirt: redShirt)).isUser,
    ];
    // Without a jump the evidence is weaker, so 8 mismatching frames are
    // needed (vs 2 right after a jump); until then the frames still count.
    expect(isUser.take(7), everyElement(isTrue));
    expect(isUser.skip(7), everyElement(isFalse));
    expect(lock.state, SubjectLockState.otherPerson);
  });

  test('missing colour evidence never blocks (fail-open)', () {
    enroll();
    final SubjectDecision d = feed(
      (int ms) => person(ms, x: 300 + 2 * bodyWidth, shirt: null),
    );
    expect(d.isBreak, isTrue);
    expect(d.similarity, isNull);
    expect(d.isUser, isTrue);
  });

  test('retaking the photo locks on the person now in front of the camera',
      () {
    enroll();
    for (int i = 0; i < 3; i++) {
      feed((int ms) => person(ms, x: 700, shirt: redShirt));
    }
    expect(lock.state, SubjectLockState.otherPerson);
    lock.relock();
    expect(lock.state, SubjectLockState.waitingForUser);
    enroll(x: 700, shirt: redShirt);
    expect(
      feed((int ms) => person(ms, x: 700, shirt: redShirt)).isUser,
      isTrue,
    );
  });

  test('known limit: a person in the same clothes is accepted', () {
    enroll();
    final SubjectDecision d = feed(
      (int ms) => person(ms, x: 300 + 2 * bodyWidth),
    );
    expect(d.isBreak, isTrue);
    expect(d.isUser, isTrue);
  });

  test('steering hides the other person for a while, then pauses', () {
    enroll();
    for (int i = 0; i < 2; i++) {
      feed((int ms) => person(ms, x: 700, shirt: redShirt));
    }
    expect(lock.state, SubjectLockState.otherPerson);
    final int start = t;
    expect(lock.steerBox(start + lock.steerMaxMs), isNotNull);
    expect(lock.steerBox(start + lock.steerMaxMs + 100), isNull);
    expect(
      lock.steerBox(start + lock.steerMaxMs + lock.steerCooldownMs),
      isNotNull,
    );
  });

  test('no steering while the user is tracked', () {
    enroll();
    expect(lock.steerBox(t), isNull);
  });

  group('face check', () {
    // Stand-in embeddings: the cosine with the user's face is the number.
    List<double> faceAt(double cosine) => <double>[
      cosine,
      sqrt(1 - cosine * cosine),
      0,
      0,
    ];
    final List<double> userFace = faceAt(1);
    final List<double> otherFace = faceAt(0.1);
    final List<double> unsureFace = faceAt(0.38);

    /// One frame, then a face check of that frame when the lock wants one.
    SubjectDecision frameWithFace(
      SubjectObservation Function(int tMs) frame,
      List<double> face,
    ) {
      final SubjectDecision d = feed(frame);
      if (lock.wantsFaceCheck(t)) {
        lock.faceCheckStarted(t);
        lock.addFace(face, t);
      }
      return d;
    }

    /// Photo with the user's face visible, until locked.
    void enrollWithFace({YuvColor shirt = blueShirt}) {
      for (int i = 0; i < 200 && lock.state != SubjectLockState.locked; i++) {
        frameWithFace((int ms) => person(ms, shirt: shirt), userFace);
      }
      expect(lock.state, SubjectLockState.locked);
      expect(lock.hasFaceTemplate, isTrue);
    }

    test('faces seen while the photo is taken become the face template', () {
      expect(lock.wantsFaceCheck(t), isFalse); // nobody in front yet
      feed((int ms) => person(ms));
      expect(lock.state, SubjectLockState.holdStill);
      expect(lock.wantsFaceCheck(t), isTrue);
      enrollWithFace();
    });

    group('lock learned on the pre-check screen', () {
      // The session starts a while after the photo: its first frame is a
      // break (gap), so whoever stands there must match again.
      void startSession() => t += 60000;

      test('the user counts from the first session frame', () {
        enrollWithFace();
        startSession();
        final SubjectDecision first = frameWithFace(
          (int ms) => person(ms, x: 320),
          userFace,
        );
        expect(first.isBreak, isTrue);
        expect(first.isUser, isTrue);
        for (int i = 0; i < 10; i++) {
          expect(
            frameWithFace((int ms) => person(ms, x: 320), userFace).isUser,
            isTrue,
          );
        }
        expect(lock.state, SubjectLockState.locked);
      });

      test('someone else at the start of the session is blocked', () {
        enrollWithFace();
        startSession();
        final SubjectDecision first = feed(
          (int ms) => person(ms, shirt: redShirt),
        );
        expect(first.isUser, isFalse);
        feed((int ms) => person(ms, shirt: redShirt));
        expect(lock.state, SubjectLockState.otherPerson);
      });

      test('someone in the same clothes at the start is caught by the face',
          () {
        enrollWithFace();
        startSession();
        for (int i = 0; i < 6; i++) {
          frameWithFace((int ms) => person(ms), otherFace);
        }
        expect(lock.state, SubjectLockState.otherPerson);
      });
    });

    test('a person in the same clothes is caught by the face', () {
      enrollWithFace();
      // Same shirt and hair, two body widths away: the look matches.
      final List<SubjectDecision> d = <SubjectDecision>[
        for (int i = 0; i < 6; i++)
          frameWithFace((int ms) => person(ms, x: 700), otherFace),
      ];
      expect(d.first.isBreak, isTrue);
      expect(lock.state, SubjectLockState.otherPerson);
      expect(d.last.isUser, isFalse);
      expect(d.last.faceVerdict, FaceVerdict.other);
    });

    test('once someone else is tracked, a matching look alone cannot bring '
        'the lock back while their face is visible', () {
      enrollWithFace();
      for (int i = 0; i < 3; i++) {
        frameWithFace((int ms) => person(ms, x: 700, shirt: redShirt), unsureFace);
      }
      expect(lock.state, SubjectLockState.otherPerson);
      // They lean into a shadow: their shirt now looks like the user's,
      // but their face is not the user's (unsure).
      for (int i = 0; i < 20; i++) {
        final SubjectDecision d = frameWithFace(
          (int ms) => person(ms, x: 700),
          unsureFace,
        );
        expect(d.isUser, isFalse, reason: 'frame $i');
      }
      // The user's face (same track, no jump, so checks run at the normal
      // interval): back after three checks, within a second.
      int frames = 0;
      while (lock.state != SubjectLockState.locked && frames < 60) {
        frameWithFace((int ms) => person(ms, x: 700), userFace);
        frames++;
      }
      expect(lock.state, SubjectLockState.locked);
      expect(frames * frameMs, lessThanOrEqualTo(1000));
    });

    test('without a face in view, a matching look still brings the lock back',
        () {
      enrollWithFace();
      for (int i = 0; i < 3; i++) {
        feed((int ms) => person(ms, x: 700, shirt: redShirt));
      }
      expect(lock.state, SubjectLockState.otherPerson);
      for (int i = 0; i < lock.liveWindowFrames; i++) {
        feed((int ms) => person(ms, x: 700));
      }
      expect(lock.state, SubjectLockState.locked);
    });

    test('the face keeps the user when their clothes change, and the look is '
        're-learned', () {
      enrollWithFace();
      // Jacket off: from now on the shirt is red, same place, face visible.
      final List<SubjectDecision> d = <SubjectDecision>[
        for (int i = 0; i < 40; i++)
          frameWithFace((int ms) => person(ms, shirt: redShirt), userFace),
      ];
      expect(d.map((SubjectDecision x) => x.isUser), everyElement(isTrue));
      expect(lock.state, SubjectLockState.locked);
      // Face hidden later (guard): the new look alone keeps the user.
      for (int i = 0; i < 40; i++) {
        expect(feed((int ms) => person(ms, shirt: redShirt)).isUser, isTrue);
      }
    });

    test('a face check of a frame from before a change is ignored', () {
      enrollWithFace();
      final int before = t;
      feed((int ms) => person(ms, x: 700)); // jump: maybe someone else
      final FaceCheckResult late = lock.addFace(otherFace, before);
      expect(late.reason, contains('ignored'));
      expect(lock.state, SubjectLockState.locked);
    });

    test('checks run fast after a change, then every interval', () {
      enrollWithFace();
      // Steady tracking with a full window: only after the interval.
      for (int i = 0; i < 3; i++) {
        frameWithFace((int ms) => person(ms), userFace);
      }
      lock.faceCheckStarted(t);
      feed((int ms) => person(ms));
      expect(lock.wantsFaceCheck(t), isFalse);
      expect(lock.wantsFaceCheck(t + lock.faceCheckIntervalMs), isTrue);
      // After a jump the window is cleared: check right away.
      feed((int ms) => person(ms, x: 700));
      expect(lock.wantsFaceCheck(t), isTrue);
    });
  });
}
