import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/subject_lock/appearance_signature.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/subject_lock/subject_lock.dart';

/// Replay of a real device session (log files/testing-4-nov, 140 s): the user
/// took the photo and boxed, another person then took over from 13.4 s, and the
/// user came back at the end. The old logic registered all 16 punches below.
///
/// Real data: every face check that reached the raw log, every punch, and the
/// moment the pose vanished and came back as a smaller person (13.396-13.679 s,
/// shoulder ratio 0.43 → 0.27). Not in the log, so modelled: one frame every
/// 73 ms (the measured average) and how steering hides the other person.
///
/// Who threw each punch is not labelled in the log. It is read from the face
/// scores around each punch: user 0.72-0.94 vs other 0.05-0.36.

/// (ms the result arrived, ms the check took, cosine with the user's face)
const List<(int, int, double)> faceChecks = <(int, int, double)>[
  (2422, 495, 0.931), (2682, 198, 0.919), (3208, 390, 0.943),
  (3610, 290, 0.937), (4534, 312, 0.893), (4961, 252, 0.891),
  (5408, 304, 0.878), (5779, 277, 0.871), (6276, 393, 0.869),
  (6596, 285, 0.866), (6987, 335, 0.859), (7391, 259, 0.865),
  (7780, 281, 0.857), (8638, 286, 0.853), (8949, 247, 0.84),
  (9337, 313, 0.846), (9706, 304, 0.82), (10062, 320, 0.83),
  (10576, 311, 0.824), (10962, 346, 0.837), (11240, 266, 0.853),
  (11606, 248, 0.855), (12051, 275, 0.826), (12377, 198, 0.727),
  (12769, 267, 0.723), (13927, 248, 0.165), (14563, 312, 0.156),
  (15794, 231, 0.102), (15996, 195, 0.1), (17960, 237, 0.157),
  (19814, 223, 0.115), (20111, 266, 0.181), (21846, 299, 0.156),
  (22215, 337, 0.144), (23575, 232, 0.122), (23834, 234, 0.096),
  (25384, 263, 0.112), (25604, 216, 0.1), (27066, 206, 0.089),
  (29002, 250, 0.072), (30707, 195, 0.092), (32631, 243, 0.067),
  (34602, 300, 0.073), (36326, 253, 0.126), (38053, 208, 0.143),
  (40056, 312, 0.154), (41810, 301, 0.116), (43597, 226, 0.138),
  (45795, 308, 0.097), (46069, 266, 0.105), (47720, 274, 0.103),
  (49571, 303, 0.091), (51304, 306, 0.157), (53057, 213, 0.071),
  (54780, 202, 0.087), (56574, 219, 0.138), (56877, 292, 0.096),
  (58695, 336, 0.086), (58978, 236, 0.106), (60689, 329, 0.154),
  (64733, 334, 0.095), (66130, 254, 0.129), (68249, 353, 0.076),
  (69879, 320, 0.111), (71607, 243, 0.111), (74070, 328, 0.113),
  (74483, 393, 0.153), (78278, 406, 0.053), (80045, 338, 0.251),
  (83593, 236, 0.062), (85504, 330, 0.083), (87286, 294, 0.098),
  (89033, 237, 0.149), (91011, 254, 0.077), (91260, 235, 0.075),
  (92994, 346, 0.103), (96290, 235, 0.119), (96637, 245, 0.116),
  (96839, 194, 0.086), (97273, 232, 0.09), (98221, 295, 0.114),
  (98574, 298, 0.055), (99433, 307, 0.127), (101766, 330, 0.106),
  (102158, 317, 0.091), (103750, 299, 0.09), (105739, 214, 0.132),
  (107774, 232, 0.083), (109762, 297, 0.137), (111643, 303, 0.088),
  (114329, 340, 0.337), (116574, 349, 0.277), (118717, 270, 0.264),
  (120515, 315, 0.35), (122432, 279, 0.357), (129388, 259, 0.311),
  (130396, 278, 0.288), (132403, 315, 0.287), (133380, 320, 0.337),
  (136292, 293, 0.782), (138831, 243, 0.794), (139733, 304, 0.796),
  (140136, 253, 0.29),
];

/// (ms of the punch, thrown by the user?)
const List<(int, bool)> punches = <(int, bool)>[
  (1994, true), (2725, true), (9015, true), (9676, true),
  (10004, true), (10970, true), (11388, true), (13720, false),
  (14041, false), (75103, false), (101278, false), (101425, false),
  (113468, false), (126927, false), (132841, false), (140097, true),
];

const int firstFrameMs = 1927;
const int poseGoneMs = 13396;
const int otherPersonMs = 13679;
const int userBackMs = 135700;
const int lastFrameMs = 140300;
const int frameMs = 73;

/// Sessions start this long after the photo.
const int sessionOffsetMs = 100000;

const YuvColor userShirt = YuvColor(41, 240, 110);
const YuvColor differentShirt = YuvColor(82, 90, 240);

AppearanceHistogram solid(YuvColor colour, int samples) {
  final AppearanceHistogram h = AppearanceHistogram();
  for (int i = 0; i < samples; i++) {
    h.add(colour);
  }
  return h;
}

SubjectObservation frame(int tMs, {required double x, required YuvColor shirt}) =>
    SubjectObservation(
      tMs: tMs,
      anchor: Point<double>(x, 250),
      anchorIsShoulders: true,
      bodyScale: 200,
      torso: solid(shirt, 36),
      head: solid(const YuvColor(25, 128, 128), 12),
      box: Rectangle<double>(x - 150, 50, 300, 590),
    );

List<double> faceAt(double cosine) => <double>[
  cosine,
  sqrt(1 - cosine * cosine),
  0,
  0,
];

/// Result of a replay: was the frame in front of each punch counted, per phase.
class Replay {
  final Map<int, bool> countedAtPunch = <int, bool>{};
  int otherPersonFramesCounted = 0;
  int otherPersonFrames = 0;
  int stateChangesWhileOtherPerson = 0;
  int userFramesBlockedAfterProof = 0;
}

Replay replay({required YuvColor otherShirt}) {
  final SubjectLock lock = SubjectLock();
  // The reference photo, before the session.
  int enrollMs = 0;
  while (lock.state != SubjectLockState.locked && enrollMs < 20000) {
    enrollMs += 33;
    lock.observe(frame(enrollMs, x: 300, shirt: userShirt));
    if (lock.wantsFaceCheck(enrollMs)) lock.addFace(faceAt(1), enrollMs);
  }
  expect(lock.hasFaceTemplate, isTrue);

  final Replay result = Replay();
  int nextFace = 0;
  int nextPunch = 0;
  bool lastFrameCounted = false;
  bool proven = false;
  SubjectLockState? previous;
  for (int t = firstFrameMs; t <= lastFrameMs; t += frameMs) {
    while (nextPunch < punches.length && punches[nextPunch].$1 < t) {
      result.countedAtPunch[punches[nextPunch].$1] = lastFrameCounted;
      nextPunch++;
    }
    final int now = t + sessionOffsetMs;
    final bool isOther = t >= otherPersonMs && t < userBackMs;
    final bool poseVisible =
        (t < poseGoneMs || t >= otherPersonMs) &&
        // Steering hides the other person from ML Kit.
        !(isOther && lock.steerBox(now) != null);
    if (poseVisible) {
      final SubjectDecision d = lock.observe(
        isOther
            ? frame(now, x: 700, shirt: otherShirt)
            : frame(now, x: 300, shirt: userShirt),
      );
      lastFrameCounted = d.isUser;
      if (isOther) {
        result.otherPersonFrames++;
        if (d.isUser) result.otherPersonFramesCounted++;
      } else if (d.isUser) {
        proven = true;
      } else if (proven && t < poseGoneMs) {
        result.userFramesBlockedAfterProof++;
      }
    } else {
      lock.poseLost();
      lastFrameCounted = false;
    }
    while (nextFace < faceChecks.length && faceChecks[nextFace].$1 <= t) {
      final (int arrivedMs, int tookMs, double cosine) = faceChecks[nextFace];
      lock.addFace(faceAt(cosine), arrivedMs - tookMs + sessionOffsetMs);
      nextFace++;
    }
    if (isOther && previous != null && previous != lock.state) {
      result.stateChangesWhileOtherPerson++;
    }
    previous = lock.state;
  }
  return result;
}

void main() {
  // Same clothes: the look can tell nothing (it reached 0.94 in the session).
  // Different clothes: the look also disagrees.
  for (final (String name, YuvColor shirt) in const <(String, YuvColor)>[
    ('same clothes', userShirt),
    ('different clothes', differentShirt),
  ]) {
    group('session of 4 Nov replayed, other person in $name', () {
      late Replay r;
      setUp(() => r = replay(otherShirt: shirt));

      test('none of the 8 punches of the other person counts', () {
        final List<int> counted = <int>[
          for (final (int ms, bool byUser) in punches)
            if (!byUser && r.countedAtPunch[ms]!) ms,
        ];
        expect(counted, isEmpty);
      });

      test('no frame of the other person counts, in 122 s', () {
        expect(r.otherPersonFrames, greaterThan(100));
        expect(r.otherPersonFramesCounted, 0);
      });

      test('the user keeps their punches, except one before the first check',
          () {
        final List<int> lost = <int>[
          for (final (int ms, bool byUser) in punches)
            if (byUser && !r.countedAtPunch[ms]!) ms,
        ];
        // 67 ms after the camera's first frame; the first face check needs 495.
        expect(lost, <int>[1994]);
        expect(r.userFramesBlockedAfterProof, 0);
      });

      test('the state settles instead of flipping (was every 1.14 s)', () {
        expect(r.stateChangesWhileOtherPerson, lessThanOrEqualTo(2));
      });
    });
  }
}
