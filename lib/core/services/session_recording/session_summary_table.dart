/// Small, human-readable table of a session: one row per punch decision and one
/// row per camera state change. Exported as CSV (opens in Excel / Google Sheets
/// and is short enough to paste into a chat), unlike the full raw JSONL file.
class SessionSummaryTable {
  SessionSummaryTable({this.maxRows = 3000});

  /// Rows beyond this are dropped (counted in [droppedRows]).
  final int maxRows;

  static const List<String> columns = <String>[
    'time',
    'kind',
    'code',
    'valid',
    'punch_no',
    'audio_db',
    'target_db',
    'frame_jump',
    'window_rise',
    'vibe_peak',
    'vibe_threshold',
    'vibe_offset_ms',
    'vibe_rose',
    'camera_state',
    'face_conf',
    'shoulder_conf',
    'distance_ratio',
    // Body-motion gate: score (fraction of body width), state ("moved",
    // "still", "unknown", or "off(moved|still|unknown)" when the gate is off)
    // and the body point that moved most.
    'motion_score',
    'motion_state',
    'motion_top_point',
    'decided_after_ms',
    'detail',
  ];

  final List<List<String>> _rows = <List<String>>[];
  int droppedRows = 0;

  int get rowCount => _rows.length;

  /// Adds a row. Keys must be names from [columns]; missing keys stay empty.
  void addRow(Map<String, Object?> values) {
    if (_rows.length >= maxRows) {
      droppedRows++;
      return;
    }
    _rows.add(columns.map((String c) => _cell(values[c])).toList());
  }

  String toCsv() {
    final StringBuffer buffer = StringBuffer()..writeln(columns.join(','));
    for (final List<String> row in _rows) {
      buffer.writeln(row.map(_escape).join(','));
    }
    if (droppedRows > 0) {
      buffer.writeln('# $droppedRows more rows not shown (table limit $maxRows)');
    }
    return buffer.toString();
  }

  static String _cell(Object? value) {
    if (value == null) return '';
    if (value is double) {
      if (value.isNaN || !value.isFinite) return '';
      return value.toStringAsFixed(2);
    }
    if (value is bool) return value ? 'yes' : 'no';
    return value.toString();
  }

  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
