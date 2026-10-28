import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/services/session_recording/session_summary_table.dart';

void main() {
  test('starts with the header row', () {
    final SessionSummaryTable table = SessionSummaryTable();
    final List<String> lines = table.toCsv().trim().split('\n');
    expect(lines.single, SessionSummaryTable.columns.join(','));
  });

  test('rows follow the column order and format values', () {
    final SessionSummaryTable table = SessionSummaryTable();
    table.addRow(<String, Object?>{
      'time': '+00:17.528',
      'kind': 'IMPACT',
      'code': 'IMPACT_VALID_AUDIO_VIBE_CAM',
      'valid': true,
      'punch_no': 1,
      'audio_db': 100.234,
      'face_conf': 0.876,
    });
    final List<String> cells = table.toCsv().trim().split('\n')[1].split(',');
    Map<String, String> byName = <String, String>{
      for (int i = 0; i < SessionSummaryTable.columns.length; i++)
        SessionSummaryTable.columns[i]: cells[i],
    };
    expect(byName['time'], '+00:17.528');
    expect(byName['valid'], 'yes');
    expect(byName['punch_no'], '1');
    expect(byName['audio_db'], '100.23');
    expect(byName['face_conf'], '0.88');
    expect(byName['vibe_peak'], '');
  });

  test('cells with commas or quotes are quoted', () {
    final SessionSummaryTable table = SessionSummaryTable();
    table.addRow(<String, Object?>{'detail': 'a, b "c"'});
    expect(table.toCsv(), contains('"a, b ""c"""'));
  });

  test('stops at the row limit and says how many were dropped', () {
    final SessionSummaryTable table = SessionSummaryTable(maxRows: 2);
    for (int i = 0; i < 5; i++) {
      table.addRow(<String, Object?>{'kind': 'CAMERA'});
    }
    expect(table.rowCount, 2);
    expect(table.droppedRows, 3);
    expect(table.toCsv(), contains('# 3 more rows not shown'));
  });
}
