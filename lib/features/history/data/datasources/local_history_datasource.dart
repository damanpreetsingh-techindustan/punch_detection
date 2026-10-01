import 'dart:convert';
import '../../domain/entities/workout_record.dart';

class LocalHistoryDatasource {
  final List<WorkoutRecord> _inMemoryStore = [];

  Future<List<WorkoutRecord>> readAllRecords() async {
    return List<WorkoutRecord>.from(_inMemoryStore);
  }

  Future<void> writeRecord(WorkoutRecord record) async {
    _inMemoryStore.insert(0, record); // Newest records at top
  }

  Future<void> clearAll() async {
    _inMemoryStore.clear();
  }

  /// Helper methods for JSON string encoding / decoding
  String encodeList(List<WorkoutRecord> list) {
    final jsonList = list.map((r) => r.toJson()).toList();
    return jsonEncode(jsonList);
  }

  List<WorkoutRecord> decodeList(String rawJson) {
    if (rawJson.isEmpty) return [];
    final List<dynamic> parsed = jsonDecode(rawJson);
    return parsed.map((item) => WorkoutRecord.fromJson(item as Map<String, dynamic>)).toList();
  }
}
