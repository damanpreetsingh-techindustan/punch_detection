import 'bag_targets.dart';

/// Rounds for a drill. [rounds] == 0 means open-ended (no timer, finish by
/// hand), which is how drills worked before rounds existed.
class RoundPlan {
  final int rounds;
  final int roundSeconds;
  final int restSeconds;

  const RoundPlan({
    this.rounds = 0,
    this.roundSeconds = 120,
    this.restSeconds = 45,
  });

  static const open = RoundPlan();

  bool get isOpen => rounds <= 0;

  int get totalSeconds =>
      isOpen ? 0 : rounds * roundSeconds + (rounds - 1) * restSeconds;

  RoundPlan copyWith({int? rounds, int? roundSeconds, int? restSeconds}) =>
      RoundPlan(
        rounds: rounds ?? this.rounds,
        roundSeconds: roundSeconds ?? this.roundSeconds,
        restSeconds: restSeconds ?? this.restSeconds,
      );

  Map<String, dynamic> toJson() => {
    'rounds': rounds,
    'roundSeconds': roundSeconds,
    'restSeconds': restSeconds,
  };

  factory RoundPlan.fromJson(Map<String, dynamic>? json) {
    if (json == null) return open;
    return RoundPlan(
      rounds: ((json['rounds'] as num?)?.toInt() ?? 0).clamp(0, 20),
      roundSeconds: ((json['roundSeconds'] as num?)?.toInt() ?? 120).clamp(
        15,
        600,
      ),
      restSeconds: ((json['restSeconds'] as num?)?.toInt() ?? 45).clamp(5, 300),
    );
  }

  String get label {
    if (isOpen) return 'Open · no timer';
    String t(int s) => s % 60 == 0
        ? '${s ~/ 60} min'
        : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    return '$rounds × ${t(roundSeconds)} · ${restSeconds}s rest';
  }
}

/// A Reaction Drill program: which combos are called, how fast, and the
/// rounds. Built-in programs come from `assets/drills/programs.json`; the
/// user's own drills use the same format (saved on the phone), so the session
/// treats every drill the same way.
///
/// JSON format (all keys except id, title and combos are optional):
/// ```json
/// {
///   "id": "jab_master", "title": "Jab Master",
///   "category": "style", "level": "beginner",
///   "subtitle": "Own the distance with the jab",
///   "description": "…", "tips": ["…"],
///   "combos": [[1], [1, 1, 2]], "callIntervalMs": 900,
///   "roundPlan": {"rounds": 3, "roundSeconds": 120, "restSeconds": 45},
///   "proOnly": false, "image": "assets/drills/images/jab_master.png"
/// }
/// ```
class DrillProgram {
  final String id;
  final String title;
  final String subtitle;
  final String description;

  /// 'basic', 'style' or 'custom'.
  final String category;

  /// 'beginner', 'intermediate' or 'advanced'.
  final String level;
  final List<List<int>> combos;
  final int callIntervalMs;
  final RoundPlan roundPlan;
  final bool proOnly;
  final List<String> tips;
  final String? image;

  const DrillProgram({
    required this.id,
    required this.title,
    required this.combos,
    this.subtitle = '',
    this.description = '',
    this.category = 'custom',
    this.level = 'beginner',
    this.callIntervalMs = 1200,
    this.roundPlan = RoundPlan.open,
    this.proOnly = false,
    this.tips = const [],
    this.image,
  });

  static const int minIntervalMs = 250;
  static const int maxIntervalMs = 3000;

  bool get isCustom => category == 'custom';

  /// Numbers used anywhere in the drill (for the bag preview).
  Set<int> get targetsUsed => {for (final c in combos) ...c};

  String get paceLabel =>
      '${(callIntervalMs / 1000).toStringAsFixed(callIntervalMs % 100 == 0 ? 1 : 2)} s per call';

  DrillProgram copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? description,
    String? category,
    String? level,
    List<List<int>>? combos,
    int? callIntervalMs,
    RoundPlan? roundPlan,
    bool? proOnly,
    List<String>? tips,
  }) => DrillProgram(
    id: id ?? this.id,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    description: description ?? this.description,
    category: category ?? this.category,
    level: level ?? this.level,
    combos: combos ?? this.combos,
    callIntervalMs: callIntervalMs ?? this.callIntervalMs,
    roundPlan: roundPlan ?? this.roundPlan,
    proOnly: proOnly ?? this.proOnly,
    tips: tips ?? this.tips,
    image: image,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'description': description,
    'category': category,
    'level': level,
    'combos': combos,
    'callIntervalMs': callIntervalMs,
    'roundPlan': roundPlan.toJson(),
    'proOnly': proOnly,
    'tips': tips,
    if (image != null) 'image': image,
  };

  /// Returns null for an entry the app can't use (missing id/title or no
  /// valid combo), so one bad entry never breaks the whole list. Numbers
  /// outside 1–6 are dropped and the pace is clamped to a safe range.
  static DrillProgram? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final id = (json['id'] as String?)?.trim() ?? '';
    final title = (json['title'] as String?)?.trim() ?? '';
    if (id.isEmpty || title.isEmpty) return null;
    final combos = <List<int>>[];
    for (final c in (json['combos'] as List?) ?? const []) {
      if (c is! List) continue;
      final combo = [
        for (final n in c)
          if (n is num && BagTargets.isValid(n.toInt())) n.toInt(),
      ];
      if (combo.isNotEmpty) combos.add(combo);
    }
    if (combos.isEmpty) return null;
    return DrillProgram(
      id: id,
      title: title,
      subtitle: json['subtitle'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'custom',
      level: json['level'] as String? ?? 'beginner',
      combos: combos,
      callIntervalMs: ((json['callIntervalMs'] as num?)?.toInt() ?? 1200).clamp(
        minIntervalMs,
        maxIntervalMs,
      ),
      roundPlan: RoundPlan.fromJson(
        json['roundPlan'] is Map
            ? Map<String, dynamic>.from(json['roundPlan'] as Map)
            : null,
      ),
      proOnly: json['proOnly'] as bool? ?? false,
      tips: [
        for (final t in (json['tips'] as List?) ?? const [])
          if (t is String) t,
      ],
      image: json['image'] as String?,
    );
  }
}
