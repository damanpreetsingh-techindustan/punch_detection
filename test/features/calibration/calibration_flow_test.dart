import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/services/config_service.dart';
import 'package:punch_detection_demo/core/services/monotonic_clock_service.dart';
import 'package:punch_detection_demo/features/calibration/data/datasources/audio_calibration_datasource.dart';
import 'package:punch_detection_demo/features/calibration/data/datasources/vision_calibration_datasource.dart';
import 'package:punch_detection_demo/features/calibration/data/repositories/calibration_repository_impl.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/entities/body_pose_data.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/entities/pose_landmark.dart';

void main() {
  late AudioCalibrationDatasource audioDatasource;
  late VisionCalibrationDatasource visionDatasource;
  late ConfigService configService;
  late MonotonicClockService clockService;
  late CalibrationRepositoryImpl repository;

  setUp(() {
    audioDatasource = AudioCalibrationDatasource();
    visionDatasource = VisionCalibrationDatasource();
    configService = ConfigService();
    clockService = MonotonicClockService();
    repository = CalibrationRepositoryImpl(
      audioDatasource: audioDatasource,
      visionDatasource: visionDatasource,
      configService: configService,
      clockService: clockService,
    );
  });

  group('Phase 6: Calibration Flow Unit Tests', () {
    test('1. AudioCalibrationDatasource computes 30th percentile RMS baseline & multiplier', () {
      final samples = List<double>.generate(100, (i) => (i + 1) * 0.001); // 0.001 to 0.100
      final baseline = audioDatasource.computeNoiseFloorBaseline(samples);

      expect(baseline, closeTo(0.031, 0.005));

      final multiplier = audioDatasource.calculateAdaptiveMultiplier(baseline);
      expect(multiplier, equals(3.5)); // Quiet gym multiplier
    });

    test('2. VisionCalibrationDatasource validates subject camera framing', () {
      const validPose = BodyPoseData(
        timestampMicroseconds: 1000000,
        leftShoulder: PoseLandmark(x: 0, y: 0, z: 0, likelihood: 0.9),
        rightShoulder: PoseLandmark(x: 0, y: 0, z: 0, likelihood: 0.9),
        leftElbow: PoseLandmark(x: 0, y: 0, z: 0, likelihood: 0.9),
        rightElbow: PoseLandmark(x: 0, y: 0, z: 0, likelihood: 0.9),
        leftWrist: PoseLandmark(x: 0, y: 0, z: 0, likelihood: 0.9),
        rightWrist: PoseLandmark(x: 0, y: 0, z: 0, likelihood: 0.9),
        leftHip: PoseLandmark(x: 0, y: 0, z: 0, likelihood: 0.8),
        rightHip: PoseLandmark(x: 0, y: 0, z: 0, likelihood: 0.8),
      );

      final isFramed = visionDatasource.validateSubjectFraming(validPose);
      expect(isFramed, isTrue);
    });

    test('3. CalibrationRepositoryImpl executes calibration and updates ConfigService', () async {
      final samples = [0.02, 0.03, 0.03, 0.04, 0.05, 0.06];

      final result = await repository.runCalibration(
        testSamples: samples,
        isCameraEnabled: true,
      );

      expect(result.isCalibrationSuccess, isTrue);
      expect(result.noiseFloorRmsBaseline, greaterThan(0.0));
      expect(configService.noiseFloorRms.value, equals(result.noiseFloorRmsBaseline));
    });
  });
}
