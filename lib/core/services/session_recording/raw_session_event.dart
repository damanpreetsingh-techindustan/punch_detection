import 'dart:convert';

/// One timestamped record in the raw session event file (JSONL, one object per line).
///
/// `t` is milliseconds since session start, `e` the wall-clock epoch milliseconds,
/// `k` the event kind. The remaining keys come from [data].
class RawSessionEvent {
  final int tMs;
  final int epochMs;
  final String kind;
  final Map<String, Object?> data;

  const RawSessionEvent({
    required this.tMs,
    required this.epochMs,
    required this.kind,
    this.data = const <String, Object?>{},
  });

  Map<String, Object?> toJson() => <String, Object?>{
    't': tMs,
    'e': epochMs,
    'k': kind,
    ...data.map((String key, Object? value) => MapEntry(key, _sanitize(value))),
  };

  String toJsonLine() => jsonEncode(toJson());

  /// Keeps the file small and valid JSON: rounds doubles to 3 decimals and
  /// replaces NaN / Infinity (which `jsonEncode` rejects) with null.
  static Object? _sanitize(Object? value) {
    if (value is double) {
      if (value.isNaN || !value.isFinite) return null;
      return (value * 1000).roundToDouble() / 1000;
    }
    if (value is Map) {
      return value.map(
        (Object? key, Object? v) => MapEntry(key.toString(), _sanitize(v)),
      );
    }
    if (value is Iterable) {
      return value.map(_sanitize).toList();
    }
    return value;
  }
}
