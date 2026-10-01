import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/services/monotonic_clock_service.dart';
import 'package:punch_detection_demo/features/vision_detection/data/datasources/mlkit_pose_datasource.dart';
import 'package:punch_detection_demo/features/vision_detection/data/datasources/test_video_pose_datasource.dart';
import 'package:punch_detection_demo/features/vision_detection/data/repositories/vision_analyzer_repository_impl.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/entities/vision_filter_config.dart';

void main() {
  late MonotonicClockService clockService;
  late TestVideoPoseDatasource testDatasource;
  late VisionAnalyzerRepositoryImpl repository;
  late VisionFilterConfig config;

  setUp(() {
    clockService = MonotonicClockService();
    testDatasource = TestVideoPoseDatasource(clockService: clockService);
    final mlKitDatasource = MLKitPoseDatasource(clockService: clockService);
    repository = VisionAnalyzerRepositoryImpl(mlKitDatasource: mlKitDatasource);
    config = const VisionFilterConfig(
      minElbowExtensionAngle: 140.0,
      minWristAdvanceDelta: 0.15,
      minShoulderDriveDelta: 0.08,
    );
  });

  group('Vision Detection 3 Geometric Rules Pipeline Tests', () {
    test('Synthetic extended punch pose passes geometric rules as punch motion candidate', () {
      final punchPose = testDatasource.generateExtendedPunchPose();
      final result = repository.analyzePose(punchPose, config);

      expect(result.score, greaterThanOrEqualTo(0.50));
      expect(result.isPunchMotionDetected, isTrue);
      expect(result.ruleResults['Elbow Joint Extension Check'], isTrue);
      expect(result.ruleResults['Wrist Advance Past Shoulder'], isTrue);
      expect(result.ruleResults['Shoulder Drive & Torso Rotation'], isTrue);
    });

    test('Synthetic idle guard stance fails elbow extension & wrist advance rules', () {
      final idlePose = testDatasource.generateIdleGuardPose();
      final result = repository.analyzePose(idlePose, config);

      expect(result.isPunchMotionDetected, isFalse);
      expect(result.ruleResults['Elbow Joint Extension Check'], isFalse);
    });
  });
}
