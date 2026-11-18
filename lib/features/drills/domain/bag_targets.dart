import 'dart:ui';

/// One numbered spot on the KnockUp bag (`assets/images/punching_bag.png`).
class BagTarget {
  final int number;
  final String name;

  /// 'lead' or 'rear' hand.
  final String hand;

  /// Centre of the spot as a fraction of the image (0–1), orthodox stance.
  final Offset position;

  const BagTarget(this.number, this.name, this.hand, this.position);

  String get handLabel => hand == 'lead' ? 'Lead hand' : 'Rear hand';
}

/// The 1–6 boxing number system on the bag. Measured on the 500×500 artwork;
/// if the artwork changes, only these positions change.
class BagTargets {
  static const String asset = 'assets/images/punching_bag.png';

  /// Badge size as a fraction of the bag width (covers the printed numbers).
  static const double badgeFraction = 0.14;

  static const List<BagTarget> all = [
    BagTarget(1, 'Jab', 'lead', Offset(0.575, 0.49)),
    BagTarget(2, 'Cross', 'rear', Offset(0.42, 0.49)),
    BagTarget(3, 'Lead hook', 'lead', Offset(0.152, 0.478)),
    BagTarget(4, 'Rear hook', 'rear', Offset(0.846, 0.478)),
    BagTarget(5, 'Lead uppercut', 'lead', Offset(0.42, 0.822)),
    BagTarget(6, 'Rear uppercut', 'rear', Offset(0.58, 0.822)),
  ];

  static BagTarget byNumber(int n) => all.firstWhere((t) => t.number == n);

  /// Where target [n] sits for the user's stance. Southpaw (left-handed)
  /// leads with the right hand, so every spot mirrors left↔right.
  static Offset positionFor(int n, {required bool southpaw}) {
    final p = byNumber(n).position;
    return southpaw ? Offset(1 - p.dx, p.dy) : p;
  }

  static bool isValid(int n) => n >= 1 && n <= 6;
}
