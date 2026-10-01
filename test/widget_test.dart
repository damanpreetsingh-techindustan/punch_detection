import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/main.dart';

void main() {
  testWidgets('HyperHitterApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const HyperHitterApp());
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('HYPER HITTER'), findsWidgets);
  });
}
