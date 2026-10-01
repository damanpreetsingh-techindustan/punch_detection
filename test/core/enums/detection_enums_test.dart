import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/core/enums/detection_enums.dart';
import 'package:punch_detection_demo/core/navigation/models/session_arguments.dart';

void main() {
  group('MountType Enum Tests', () {
    test('MountType.wall properties', () {
      const mount = MountType.wall;
      expect(mount.id, 'wall');
      expect(mount.title, 'Wall Mount');
      expect(mount.isVibrationDisabled, isFalse);
    });

    test('MountType.pole properties', () {
      const mount = MountType.pole;
      expect(mount.id, 'pole');
      expect(mount.title, 'Pole Mount');
      expect(mount.isVibrationDisabled, isTrue);
    });

    test('MountType.fromString parsing & backward compatibility', () {
      expect(MountType.fromString('wall'), MountType.wall);
      expect(MountType.fromString('pole'), MountType.pole);
      expect(MountType.fromString('rack'), MountType.pole); // Backward compatibility
      expect(MountType.fromString(null), MountType.wall);
      expect(MountType.fromString('unknown'), MountType.wall);
    });
  });

  group('DetectionMode Enum Tests', () {
    test('DetectionMode requirements and properties', () {
      expect(DetectionMode.fusion.requiresMicrophone, isTrue);
      expect(DetectionMode.fusion.requiresCamera, isTrue);
      expect(DetectionMode.fusion.requiresVibration, isTrue);

      expect(DetectionMode.audio.requiresMicrophone, isTrue);
      expect(DetectionMode.audio.requiresCamera, isFalse);

      expect(DetectionMode.audioVibration.requiresMicrophone, isTrue);
      expect(DetectionMode.audioVibration.requiresVibration, isTrue);
      expect(DetectionMode.audioVibration.requiresCamera, isFalse);

      expect(DetectionMode.vibration.requiresVibration, isTrue);
      expect(DetectionMode.vibration.requiresMicrophone, isFalse);
      expect(DetectionMode.vibration.requiresCamera, isFalse);

      expect(DetectionMode.camera.requiresCamera, isTrue);
      expect(DetectionMode.camera.requiresMicrophone, isFalse);
    });

    test('DetectionMode.fromString parsing', () {
      expect(DetectionMode.fromString('fusion'), DetectionMode.fusion);
      expect(DetectionMode.fromString('audio'), DetectionMode.audio);
      expect(DetectionMode.fromString('audio_vibration'), DetectionMode.audioVibration);
      expect(DetectionMode.fromString('vibration'), DetectionMode.vibration);
      expect(DetectionMode.fromString('camera'), DetectionMode.camera);
      expect(DetectionMode.fromString(null), DetectionMode.fusion);
    });
  });

  group('EnvironmentPreset Enum Tests', () {
    test('EnvironmentPreset parameters', () {
      expect(EnvironmentPreset.highSensitivity.spikeDb, 6.0);
      expect(EnvironmentPreset.highSensitivity.vibrationMag, 0.04);

      expect(EnvironmentPreset.balanced.spikeDb, 8.0);
      expect(EnvironmentPreset.balanced.vibrationMag, 0.08);

      expect(EnvironmentPreset.strictGym.spikeDb, 15.0);
      expect(EnvironmentPreset.strictGym.vibrationMag, 0.20);
    });
  });

  group('SessionArguments Enum Resolvers', () {
    test('resolves enum types from string fields', () {
      const args = SessionArguments(
        sessionType: 'free',
        promptMode: 'audio_vibration',
        mountType: 'pole',
      );
      expect(args.resolvedDetectionMode, DetectionMode.audioVibration);
      expect(args.resolvedMountType, MountType.pole);
      expect(args.resolvedMountType.isVibrationDisabled, isTrue);
    });
  });
}
