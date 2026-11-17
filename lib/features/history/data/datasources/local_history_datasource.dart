import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/workout_record.dart';

/// Saved sessions, newest first, as one JSON list in SharedPreferences.
class LocalHistoryDatasource {
  static const String _key = 'workout_history_v1';

  /// Oldest sessions are dropped past this many.
  static const int maxRecords = 1000;

  Future<List<WorkoutRecord>> readAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      return _newestFirst(decodeList(prefs.getString(_key) ?? ''));
    } catch (_) {
      // Unreadable data must never block the app: start a fresh history.
      return [];
    }
  }

  Future<void> writeRecord(WorkoutRecord record) async {
    final list = await readAllRecords();
    list.removeWhere((r) => r.id == record.id);
    list.insert(0, record); // Newest records at top
    if (list.length > maxRecords) list.removeRange(maxRecords, list.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, encodeList(list));
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Newest first by date, whatever order they were saved in. Same date:
  /// keeps the saved order (List.sort alone is not stable).
  static List<WorkoutRecord> _newestFirst(List<WorkoutRecord> list) {
    final indexed = list.asMap().entries.toList()
      ..sort((a, b) {
        final byDate = b.value.date.compareTo(a.value.date);
        return byDate != 0 ? byDate : a.key.compareTo(b.key);
      });
    return [for (final e in indexed) e.value];
  }

  /// Helper methods for JSON string encoding / decoding
  String encodeList(List<WorkoutRecord> list) {
    final jsonList = list.map((r) => r.toJson()).toList();
    return jsonEncode(jsonList);
  }

  List<WorkoutRecord> decodeList(String rawJson) {
    if (rawJson.isEmpty) return [];
    final List<dynamic> parsed = jsonDecode(rawJson);
    return parsed
        .map((item) => WorkoutRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
