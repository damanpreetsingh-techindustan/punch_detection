import '../../drills/domain/drill_program.dart';

class LessonStep {
  final String title;
  final String body;

  const LessonStep(this.title, this.body);
}

class LessonMistake {
  final String wrong;
  final String fix;

  const LessonMistake(this.wrong, this.fix);
}

/// How a lesson is practised: a counted bag drill, or a timed follow-along
/// with spoken cues (stance, footwork, defense: nothing to count).
class LessonPractice {
  /// 'drill' or 'follow'.
  final String type;
  final String description;

  /// type 'drill': the drill run in the session (same format as drills).
  final DrillProgram? drill;

  /// type 'drill': punches needed in the session to complete the lesson.
  final int minPunches;

  /// type 'follow'
  final int followSeconds;
  final List<String> cues;
  final int cueIntervalMs;

  const LessonPractice({
    required this.type,
    this.description = '',
    this.drill,
    this.minPunches = 10,
    this.followSeconds = 45,
    this.cues = const [],
    this.cueIntervalMs = 3000,
  });

  bool get isDrill => type == 'drill' && drill != null;
}

/// One lesson of a course. Content lives in `assets/learn/*.json`.
class Lesson {
  final String id;
  final int number;
  final String title;
  final String subtitle;
  final int minutes;

  /// Animation for the figure (see `BoxerMoves`).
  final String move;
  final String keyPoint;
  final List<LessonStep> steps;
  final List<LessonMistake> mistakes;
  final LessonPractice practice;
  final bool proOnly;

  /// Optional coach video for later; the figure is used when null.
  final String? video;

  const Lesson({
    required this.id,
    required this.number,
    required this.title,
    required this.move,
    required this.practice,
    this.subtitle = '',
    this.minutes = 5,
    this.keyPoint = '',
    this.steps = const [],
    this.mistakes = const [],
    this.proOnly = false,
    this.video,
  });

  /// Id of the drill a lesson's practice runs as (links Results back to it).
  String get drillId => 'lesson_$id';

  static Lesson? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final j = Map<String, dynamic>.from(raw);
    final id = (j['id'] as String?)?.trim() ?? '';
    final title = (j['title'] as String?)?.trim() ?? '';
    if (id.isEmpty || title.isEmpty) return null;
    final number = (j['number'] as num?)?.toInt() ?? 0;

    final p = j['practice'] is Map
        ? Map<String, dynamic>.from(j['practice'] as Map)
        : const <String, dynamic>{};
    final type = p['type'] as String? ?? 'follow';
    DrillProgram? drill;
    if (type == 'drill') {
      drill = DrillProgram.tryParse({
        ...?(p['drill'] as Map?)?.cast<String, dynamic>(),
        'id': 'lesson_$id',
        'title': 'Lesson $number · $title',
        'category': 'lesson',
      });
      if (drill == null) return null;
    }

    return Lesson(
      id: id,
      number: number,
      title: title,
      subtitle: j['subtitle'] as String? ?? '',
      minutes: (j['minutes'] as num?)?.toInt() ?? 5,
      move: j['move'] as String? ?? 'stance',
      keyPoint: j['keyPoint'] as String? ?? '',
      steps: [
        for (final s in (j['steps'] as List?) ?? const [])
          if (s is Map)
            LessonStep(s['title'] as String? ?? '', s['body'] as String? ?? ''),
      ],
      mistakes: [
        for (final m in (j['mistakes'] as List?) ?? const [])
          if (m is Map)
            LessonMistake(
              m['wrong'] as String? ?? '',
              m['fix'] as String? ?? '',
            ),
      ],
      practice: LessonPractice(
        type: type,
        description: p['description'] as String? ?? '',
        drill: drill,
        minPunches: (p['minPunches'] as num?)?.toInt() ?? 10,
        followSeconds: ((p['followSeconds'] as num?)?.toInt() ?? 45).clamp(
          10,
          600,
        ),
        cues: [
          for (final c in (p['cues'] as List?) ?? const [])
            if (c is String) c,
        ],
        cueIntervalMs: ((p['cueIntervalMs'] as num?)?.toInt() ?? 3000).clamp(
          1000,
          20000,
        ),
      ),
      proOnly: j['proOnly'] as bool? ?? false,
      video: j['video'] as String?,
    );
  }
}

class Course {
  final String id;
  final String title;
  final String subtitle;
  final List<Lesson> lessons;

  const Course({
    required this.id,
    required this.title,
    required this.lessons,
    this.subtitle = '',
  });

  /// Skips bad lessons (one broken entry never breaks the course); lessons
  /// are shown in `number` order.
  static Course? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final lessons = [
      for (final l in (raw['lessons'] as List?) ?? const [])
        ?Lesson.tryParse(l),
    ]..sort((a, b) => a.number.compareTo(b.number));
    if (lessons.isEmpty) return null;
    return Course(
      id: raw['id'] as String? ?? 'course',
      title: raw['title'] as String? ?? 'Course',
      subtitle: raw['subtitle'] as String? ?? '',
      lessons: lessons,
    );
  }
}
