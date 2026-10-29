import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

/// One camera frame's luma plane (8-bit), with its orientation.
class LumaFrame {
  final Uint8List data;
  final int width;
  final int height;
  final int rowStride;

  /// Clockwise rotation (0, 90, 180, 270) that makes the image upright.
  final int rotationDegrees;
  final int tUs;

  const LumaFrame({
    required this.data,
    required this.width,
    required this.height,
    required this.rowStride,
    required this.tUs,
    this.rotationDegrees = 0,
  });

  /// Builds a luma frame from a BGRA8888 buffer (iOS camera frames).
  factory LumaFrame.fromBgra(
    Uint8List bgra, {
    required int width,
    required int height,
    required int rowStride,
    required int tUs,
    int rotationDegrees = 0,
  }) {
    final Uint8List y = Uint8List(width * height);
    for (int r = 0; r < height; r++) {
      for (int c = 0; c < width; c++) {
        final int i = r * rowStride + c * 4;
        y[r * width +
            c] = (0.114 * bgra[i] + 0.587 * bgra[i + 1] + 0.299 * bgra[i + 2])
            .round();
      }
    }
    return LumaFrame(
      data: y,
      width: width,
      height: height,
      rowStride: width,
      tUs: tUs,
      rotationDegrees: rotationDegrees,
    );
  }
}

/// Arm landmarks of one pose (upright image pixels), confidence 0-1.
class ArmPose {
  final int tUs;
  final List<double>? leftWrist; // [x, y, conf]
  final List<double>? rightWrist;
  final List<double>? leftShoulder;
  final List<double>? rightShoulder;

  const ArmPose({
    required this.tUs,
    this.leftWrist,
    this.rightWrist,
    this.leftShoulder,
    this.rightShoulder,
  });
}

/// Raw and combined values of one processed frame.
class ArmMotionResult {
  final int tUs;
  final String mode; // lk | diff
  final double computeMs;
  final int validPoints;
  final double meanFlowPxPerS;
  final double divergencePerS; // relative expansion rate (looming)
  final double leftFlowPxPerS;
  final double rightFlowPxPerS;
  final double leftDivergencePerS;
  final double rightDivergencePerS;
  final double poseScore;
  final double instantActivity;

  /// Max of the instant activity over the last 300 ms, in [0, 1].
  final double armActivity;

  /// left | right | unknown (the user's hand).
  final String hand;

  const ArmMotionResult({
    required this.tUs,
    required this.mode,
    required this.computeMs,
    required this.validPoints,
    required this.meanFlowPxPerS,
    required this.divergencePerS,
    required this.leftFlowPxPerS,
    required this.rightFlowPxPerS,
    required this.leftDivergencePerS,
    required this.rightDivergencePerS,
    required this.poseScore,
    required this.instantActivity,
    required this.armActivity,
    required this.hand,
  });

  Map<String, Object?> toMap() => <String, Object?>{
    'tUs': tUs,
    'mode': mode,
    'computeMs': computeMs,
    'validPoints': validPoints,
    'flow': meanFlowPxPerS,
    'div': divergencePerS,
    'flowL': leftFlowPxPerS,
    'flowR': rightFlowPxPerS,
    'divL': leftDivergencePerS,
    'divR': rightDivergencePerS,
    'pose': poseScore,
    'instant': instantActivity,
    'activity': armActivity,
    'hand': hand,
  };
}

/// Tunables of the vision motion prior.
class ArmMotionConfig {
  final int longSide; // 160
  final int shortSide; // 120
  final int gridCols; // 12
  final int gridRows; // 9
  final int windowHalf; // 3 -> 7x7
  final int iterations;
  final double maxLkMs; // above this (median) fall back to frame difference
  final double flowRefPxPerS; // flow that scores 1.0
  final double divergenceRefPerS; // expansion rate that scores 1.0
  final double wristSpeedRef; // shoulder widths per second that score 1.0
  final double reachRef; // change of wrist-shoulder distance (shoulder widths)
  final double minPoseConfidence;
  final int activityWindowMs;
  final bool userFacingCamera; // front camera: image left = user's right hand

  const ArmMotionConfig({
    this.longSide = 160,
    this.shortSide = 120,
    this.gridCols = 12,
    this.gridRows = 9,
    this.windowHalf = 3,
    this.iterations = 5,
    this.maxLkMs = 8,
    this.flowRefPxPerS = 200,
    this.divergenceRefPerS = 1.5,
    this.wristSpeedRef = 3.0,
    this.reachRef = 0.5,
    this.minPoseConfidence = 0.5,
    this.activityWindowMs = 300,
    this.userFacingCamera = true,
  });
}

/// Vision motion prior for fusionV2: sparse pyramidal Lucas-Kanade optical
/// flow (2 levels, 7x7 windows) on a fixed 12x9 grid over the lower two-thirds
/// of a 160x120 upright luma image, plus pose-based wrist motion.
///
/// A glove punching toward the front camera expands in the image, so positive
/// divergence (looming) is the punch signature; sway or someone walking past is
/// mostly translation. The output armActivity in [0, 1] is only ever used as a
/// bounded odds multiplier. Pure Dart; the app runs it on its own isolate.
class ArmMotionTracker {
  ArmMotionTracker({this.config = const ArmMotionConfig()});

  final ArmMotionConfig config;

  Float64List? _prev;
  int _prevW = 0, _prevH = 0;
  int? _prevTUs;
  bool _useDiff = false;
  final ListQueue<double> _computeMs = ListQueue<double>();
  final ListQueue<(int, double, String)> _instant =
      ListQueue<(int, double, String)>();
  final ListQueue<ArmPose> _poses = ListQueue<ArmPose>();

  /// true once LK was found too slow and frame differencing is used instead.
  bool get usesFrameDifference => _useDiff;

  void addPose(ArmPose pose) {
    _poses.addLast(pose);
    while (_poses.isNotEmpty && _poses.first.tUs < pose.tUs - 400000) {
      _poses.removeFirst();
    }
  }

  ArmMotionResult processFrame(LumaFrame frame) {
    final Stopwatch watch = Stopwatch()..start();
    final (Float64List img, int w, int h) = _upright(frame);
    final Float64List? prev = _prev;
    final int? prevT = _prevTUs;
    _FlowSummary flow = const _FlowSummary.empty();
    if (prev != null && prevT != null && _prevW == w && _prevH == h) {
      final double dtS = math.max(1e-3, (frame.tUs - prevT) / 1e6);
      flow = _useDiff
          ? _frameDifference(prev, img, w, h, dtS)
          : _lucasKanade(prev, img, w, h, dtS);
    }
    _prev = img;
    _prevW = w;
    _prevH = h;
    _prevTUs = frame.tUs;
    watch.stop();
    final double ms = watch.elapsedMicroseconds / 1000;
    if (!_useDiff) _noteCompute(ms);

    final (double pose, String poseHand) = _poseScore(frame.tUs);
    final double flowScore = (flow.meanFlow / config.flowRefPxPerS).clamp(
      0.0,
      1.0,
    );
    final double divScore = (flow.divergence / config.divergenceRefPerS).clamp(
      0.0,
      1.0,
    );
    final double vision = math.max(divScore, 0.5 * flowScore);
    final double instant = math.max(vision, pose);
    String hand = 'unknown';
    if (pose >= vision && pose > 0) {
      hand = poseHand;
    } else if (vision > 0) {
      final double left = flow.leftDivergence + flow.leftFlow / 100;
      final double right = flow.rightDivergence + flow.rightFlow / 100;
      final String imageSide = left >= right ? 'left' : 'right';
      hand = config.userFacingCamera
          ? (imageSide == 'left' ? 'right' : 'left')
          : imageSide;
    }
    _instant.addLast((frame.tUs, instant, hand));
    while (_instant.isNotEmpty &&
        _instant.first.$1 < frame.tUs - config.activityWindowMs * 1000) {
      _instant.removeFirst();
    }
    double activity = 0;
    String activityHand = 'unknown';
    for (final (int, double, String) a in _instant) {
      if (a.$2 >= activity) {
        activity = a.$2;
        activityHand = a.$3;
      }
    }
    return ArmMotionResult(
      tUs: frame.tUs,
      mode: _useDiff ? 'diff' : 'lk',
      computeMs: ms,
      validPoints: flow.validPoints,
      meanFlowPxPerS: flow.meanFlow,
      divergencePerS: flow.divergence,
      leftFlowPxPerS: flow.leftFlow,
      rightFlowPxPerS: flow.rightFlow,
      leftDivergencePerS: flow.leftDivergence,
      rightDivergencePerS: flow.rightDivergence,
      poseScore: pose,
      instantActivity: instant,
      armActivity: activity,
      hand: activityHand,
    );
  }

  void _noteCompute(double ms) {
    _computeMs.addLast(ms);
    if (_computeMs.length > 15) _computeMs.removeFirst();
    if (_computeMs.length == 15) {
      final List<double> sorted = _computeMs.toList()..sort();
      if (sorted[7] > config.maxLkMs) _useDiff = true;
    }
  }

  /// Downscales (area average) and rotates the luma plane upright to
  /// 160x120 (landscape) or 120x160 (portrait).
  (Float64List, int, int) _upright(LumaFrame f) {
    final bool swap = f.rotationDegrees == 90 || f.rotationDegrees == 270;
    final int upW = swap ? f.height : f.width;
    final int upH = swap ? f.width : f.height;
    final bool landscape = upW >= upH;
    final int w = landscape ? config.longSide : config.shortSide;
    final int h = landscape ? config.shortSide : config.longSide;
    final Float64List out = Float64List(w * h);
    final double sx = upW / w, sy = upH / h;
    for (int v = 0; v < h; v++) {
      for (int u = 0; u < w; u++) {
        // Average a 2x2 set of source points inside the output pixel.
        double sum = 0;
        for (int k = 0; k < 4; k++) {
          final double uu = (u + 0.25 + 0.5 * (k & 1)) * sx;
          final double vv = (v + 0.25 + 0.5 * (k >> 1)) * sy;
          final (int x, int y) = _sourceOf(uu.floor(), vv.floor(), f, upW, upH);
          sum += f.data[y * f.rowStride + x];
        }
        out[v * w + u] = sum / 4;
      }
    }
    return (out, w, h);
  }

  /// Source pixel of upright pixel (u, v) for the frame's rotation.
  (int, int) _sourceOf(int u, int v, LumaFrame f, int upW, int upH) {
    final int cu = u.clamp(0, upW - 1), cv = v.clamp(0, upH - 1);
    switch (f.rotationDegrees) {
      case 90:
        return (cv, f.height - 1 - cu);
      case 180:
        return (f.width - 1 - cu, f.height - 1 - cv);
      case 270:
        return (f.width - 1 - cv, cu);
      default:
        return (cu, cv);
    }
  }

  List<(double, double)> _gridPoints(int w, int h) {
    final List<(double, double)> pts = <(double, double)>[];
    final double x0 = w * 0.06, x1 = w * 0.94;
    final double y0 = h / 3 + h * 0.04, y1 = h * 0.94;
    for (int r = 0; r < config.gridRows; r++) {
      for (int c = 0; c < config.gridCols; c++) {
        pts.add((
          (x0 + (x1 - x0) * c / (config.gridCols - 1)).roundToDouble(),
          (y0 + (y1 - y0) * r / (config.gridRows - 1)).roundToDouble(),
        ));
      }
    }
    return pts;
  }

  _FlowSummary _lucasKanade(
    Float64List prev,
    Float64List curr,
    int w,
    int h,
    double dtS,
  ) {
    final _Pyramid p = _Pyramid(prev, w, h);
    final _Pyramid c = _Pyramid(curr, w, h);
    final List<(double, double, double, double)> flows =
        <(double, double, double, double)>[];
    for (final (double, double) pt in _gridPoints(w, h)) {
      double gx = 0, gy = 0;
      bool ok = true;
      for (int level = 1; level >= 0; level--) {
        final double scale = level == 1 ? 0.5 : 1.0;
        final _Level lp = p.level(level), lc = c.level(level);
        final double px = pt.$1 * scale, py = pt.$2 * scale;
        final (double vx, double vy, bool good) = _lkPoint(
          lp,
          lc,
          px,
          py,
          gx,
          gy,
        );
        if (level == 0) ok = good;
        gx = level == 1 ? 2 * (gx + vx) : gx + vx;
        gy = level == 1 ? 2 * (gy + vy) : gy + vy;
      }
      if (ok && gx.isFinite && gy.isFinite && gx.abs() < 20 && gy.abs() < 20) {
        flows.add((pt.$1, pt.$2, gx, gy));
      }
    }
    return _summarize(flows, w, dtS);
  }

  /// One LK refinement at one level. Returns the increment and whether the
  /// window had enough texture (smallest eigenvalue of G).
  (double, double, bool) _lkPoint(
    _Level prev,
    _Level curr,
    double px,
    double py,
    double gx,
    double gy,
  ) {
    final int r = config.windowHalf;
    double gxx = 0, gxy = 0, gyy = 0;
    final List<double> ix = <double>[], iy = <double>[], i0 = <double>[];
    for (int dy = -r; dy <= r; dy++) {
      for (int dx = -r; dx <= r; dx++) {
        final double x = px + dx, y = py + dy;
        final double gxv = prev.gradX(x, y), gyv = prev.gradY(x, y);
        ix.add(gxv);
        iy.add(gyv);
        i0.add(prev.sample(x, y));
        gxx += gxv * gxv;
        gxy += gxv * gyv;
        gyy += gyv * gyv;
      }
    }
    final double det = gxx * gyy - gxy * gxy;
    final double trace = gxx + gyy;
    final double minEig =
        (trace - math.sqrt(math.max(0, trace * trace - 4 * det))) / 2;
    final int n = ix.length;
    if (det.abs() < 1e-6 || minEig / n < 2.0) return (0, 0, false);
    double vx = 0, vy = 0;
    for (int it = 0; it < config.iterations; it++) {
      double bx = 0, by = 0;
      int k = 0;
      for (int dy = -r; dy <= r; dy++) {
        for (int dx = -r; dx <= r; dx++) {
          final double diff =
              i0[k] - curr.sample(px + dx + gx + vx, py + dy + gy + vy);
          bx += diff * ix[k];
          by += diff * iy[k];
          k++;
        }
      }
      final double ddx = (gyy * bx - gxy * by) / det;
      final double ddy = (gxx * by - gxy * bx) / det;
      vx += ddx;
      vy += ddy;
      if (ddx * ddx + ddy * ddy < 0.0009) break;
    }
    return (vx, vy, true);
  }

  _FlowSummary _summarize(
    List<(double, double, double, double)> flows,
    int w,
    double dtS,
  ) {
    if (flows.isEmpty) return const _FlowSummary.empty();
    double meanMag(Iterable<(double, double, double, double)> fs) {
      double s = 0;
      int n = 0;
      for (final (double, double, double, double) f in fs) {
        s += math.sqrt(f.$3 * f.$3 + f.$4 * f.$4);
        n++;
      }
      return n == 0 ? 0 : s / n / dtS;
    }

    double divergence(Iterable<(double, double, double, double)> fs) {
      final List<(double, double, double, double)> moving =
          <(double, double, double, double)>[
            for (final (double, double, double, double) f in fs)
              if (f.$3 * f.$3 + f.$4 * f.$4 > 0.09) f,
          ];
      if (moving.length < 4) return 0;
      double cx = 0, cy = 0, vx = 0, vy = 0;
      for (final (double, double, double, double) f in moving) {
        cx += f.$1;
        cy += f.$2;
        vx += f.$3;
        vy += f.$4;
      }
      final int n = moving.length;
      cx /= n;
      cy /= n;
      vx /= n;
      vy /= n;
      double num = 0, den = 0;
      for (final (double, double, double, double) f in moving) {
        final double rx = f.$1 - cx, ry = f.$2 - cy;
        num += (f.$3 - vx) * rx + (f.$4 - vy) * ry;
        den += rx * rx + ry * ry;
      }
      return den > 0 ? num / den / dtS : 0;
    }

    final double half = w / 2;
    final Iterable<(double, double, double, double)> left = flows.where(
      ((double, double, double, double) f) => f.$1 < half,
    );
    final Iterable<(double, double, double, double)> right = flows.where(
      ((double, double, double, double) f) => f.$1 >= half,
    );
    return _FlowSummary(
      validPoints: flows.length,
      meanFlow: meanMag(flows),
      divergence: divergence(flows),
      leftFlow: meanMag(left),
      rightFlow: meanMag(right),
      leftDivergence: divergence(left),
      rightDivergence: divergence(right),
    );
  }

  _FlowSummary _frameDifference(
    Float64List prev,
    Float64List curr,
    int w,
    int h,
    double dtS,
  ) {
    double left = 0, right = 0;
    int nl = 0, nr = 0;
    for (int y = h ~/ 3; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final double d = (curr[y * w + x] - prev[y * w + x]).abs();
        if (x < w / 2) {
          left += d;
          nl++;
        } else {
          right += d;
          nr++;
        }
      }
    }
    // Mean absolute luma change per second; scaled to resemble px/s of flow.
    final double l = nl == 0 ? 0 : left / nl / dtS * 2;
    final double r = nr == 0 ? 0 : right / nr / dtS * 2;
    return _FlowSummary(
      validPoints: 0,
      meanFlow: (l + r) / 2,
      divergence: 0,
      leftFlow: l,
      rightFlow: r,
      leftDivergence: 0,
      rightDivergence: 0,
    );
  }

  /// Wrist speed and change of wrist-to-shoulder distance over the last
  /// 300 ms, normalised by shoulder width, from landmarks >= 0.5 confidence.
  (double, String) _poseScore(int tUs) {
    if (_poses.length < 2) return (0, 'unknown');
    final List<ArmPose> recent = <ArmPose>[
      for (final ArmPose p in _poses)
        if (p.tUs >= tUs - config.activityWindowMs * 1000 && p.tUs <= tUs) p,
    ];
    if (recent.length < 2) return (0, 'unknown');
    final ArmPose a = recent.first, b = recent.last;
    final double dtS = (b.tUs - a.tUs) / 1e6;
    if (dtS <= 0) return (0, 'unknown');
    double? shoulderWidth;
    final List<double>? ls = b.leftShoulder, rs = b.rightShoulder;
    if (_ok(ls) && _ok(rs)) {
      shoulderWidth = math.sqrt(
        math.pow(ls![0] - rs![0], 2) + math.pow(ls[1] - rs[1], 2),
      );
    }
    if (shoulderWidth == null || shoulderWidth < 1) return (0, 'unknown');
    double best = 0;
    String hand = 'unknown';
    for (final bool left in <bool>[true, false]) {
      final List<double>? w0 = left ? a.leftWrist : a.rightWrist;
      final List<double>? w1 = left ? b.leftWrist : b.rightWrist;
      final List<double>? s0 = left ? a.leftShoulder : a.rightShoulder;
      final List<double>? s1 = left ? b.leftShoulder : b.rightShoulder;
      if (!_ok(w0) || !_ok(w1)) continue;
      final double speed =
          math.sqrt(math.pow(w1![0] - w0![0], 2) + math.pow(w1[1] - w0[1], 2)) /
          shoulderWidth /
          dtS;
      double reach = 0;
      if (_ok(s0) && _ok(s1)) {
        final double d0 = math.sqrt(
          math.pow(w0[0] - s0![0], 2) + math.pow(w0[1] - s0[1], 2),
        );
        final double d1 = math.sqrt(
          math.pow(w1[0] - s1![0], 2) + math.pow(w1[1] - s1[1], 2),
        );
        reach = (d1 - d0).abs() / shoulderWidth;
      }
      final double score = math.max(
        (speed / config.wristSpeedRef).clamp(0.0, 1.0),
        (reach / config.reachRef).clamp(0.0, 1.0),
      );
      if (score > best) {
        best = score;
        hand = left ? 'left' : 'right';
      }
    }
    return (best, hand);
  }

  bool _ok(List<double>? lm) =>
      lm != null && lm.length >= 3 && lm[2] >= config.minPoseConfidence;
}

class _FlowSummary {
  final int validPoints;
  final double meanFlow;
  final double divergence;
  final double leftFlow;
  final double rightFlow;
  final double leftDivergence;
  final double rightDivergence;

  const _FlowSummary({
    required this.validPoints,
    required this.meanFlow,
    required this.divergence,
    required this.leftFlow,
    required this.rightFlow,
    required this.leftDivergence,
    required this.rightDivergence,
  });

  const _FlowSummary.empty()
    : validPoints = 0,
      meanFlow = 0,
      divergence = 0,
      leftFlow = 0,
      rightFlow = 0,
      leftDivergence = 0,
      rightDivergence = 0;
}

class _Level {
  _Level(this.img, this.w, this.h);
  final Float64List img;
  final int w, h;

  double _px(int x, int y) => img[y.clamp(0, h - 1) * w + x.clamp(0, w - 1)];

  double sample(double x, double y) {
    final int x0 = x.floor(), y0 = y.floor();
    final double fx = x - x0, fy = y - y0;
    final double a = _px(x0, y0), b = _px(x0 + 1, y0);
    final double c = _px(x0, y0 + 1), d = _px(x0 + 1, y0 + 1);
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
  }

  double gradX(double x, double y) => (sample(x + 1, y) - sample(x - 1, y)) / 2;
  double gradY(double x, double y) => (sample(x, y + 1) - sample(x, y - 1)) / 2;
}

class _Pyramid {
  _Pyramid(Float64List img, int w, int h)
    : _levels = <_Level>[_Level(img, w, h)] {
    final int w1 = w ~/ 2, h1 = h ~/ 2;
    final Float64List half = Float64List(w1 * h1);
    for (int y = 0; y < h1; y++) {
      for (int x = 0; x < w1; x++) {
        half[y * w1 + x] =
            (img[(2 * y) * w + 2 * x] +
                img[(2 * y) * w + 2 * x + 1] +
                img[(2 * y + 1) * w + 2 * x] +
                img[(2 * y + 1) * w + 2 * x + 1]) /
            4;
      }
    }
    _levels.add(_Level(half, w1, h1));
  }

  final List<_Level> _levels;
  _Level level(int i) => _levels[i];
}
