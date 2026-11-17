import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:punch_detection_demo/core/services/storage_service.dart';
import 'package:punch_detection_demo/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('KnockUpApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await Get.putAsync<StorageService>(() => StorageService().init());
    await tester.pumpWidget(const KnockUpApp());
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('KnockUp', findRichText: true), findsWidgets);
  });
}
