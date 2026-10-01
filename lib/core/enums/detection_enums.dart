/// Strongly-typed enums for Punch Detection, Mounting Types, and Environment Presets.
library;

/// Phone Mount Types supported by HyperHitter
enum MountType {
  wall,
  pole;

  String get id => name;
  String get title => this == MountType.wall ? 'Wall Mount' : 'Pole Mount';
  String get subtitle => this == MountType.wall
      ? 'Vibration + Audio + Vision'
      : 'Audio + Vision (No Vibe)';
  String get icon => this == MountType.wall ? '🧱' : '🥊';
  bool get isVibrationDisabled => this == MountType.pole;

  static MountType fromString(String? value) {
    if (value == null) return MountType.wall;
    switch (value.toLowerCase().trim()) {
      case 'pole':
      case 'rack':
        return MountType.pole;
      case 'wall':
      default:
        return MountType.wall;
    }
  }
}

/// Punch Detection Modes
enum DetectionMode {
  fusion,
  audio,
  audioVibration,
  vibration,
  camera;

  String get id {
    switch (this) {
      case DetectionMode.fusion:
        return 'fusion';
      case DetectionMode.audio:
        return 'audio';
      case DetectionMode.audioVibration:
        return 'audio_vibration';
      case DetectionMode.vibration:
        return 'vibration';
      case DetectionMode.camera:
        return 'camera';
    }
  }

  String get title {
    switch (this) {
      case DetectionMode.fusion:
        return 'Tri-Sensor Fusion Mode';
      case DetectionMode.audio:
        return 'Audio Only Mode';
      case DetectionMode.audioVibration:
        return 'Audio + Vibration Dual';
      case DetectionMode.vibration:
        return 'Vibration Only Mode';
      case DetectionMode.camera:
        return 'Camera Only Mode';
    }
  }

  String get subtitle {
    switch (this) {
      case DetectionMode.fusion:
        return 'Tri-sensor fusion (Mic + Accelerometer + Camera Vision)';
      case DetectionMode.audio:
        return 'Acoustic punch impact detection using microphone (Pure Sound)';
      case DetectionMode.audioVibration:
        return 'Dual acoustic sound and physical shockwave vibration';
      case DetectionMode.vibration:
        return 'Physical impact vibration detection using device accelerometer';
      case DetectionMode.camera:
        return 'Computer vision tracking using ML Kit pose estimation';
    }
  }

  String get icon {
    switch (this) {
      case DetectionMode.fusion:
        return '⚡';
      case DetectionMode.audio:
        return '🎙';
      case DetectionMode.audioVibration:
        return '⚡';
      case DetectionMode.vibration:
        return '📳';
      case DetectionMode.camera:
        return '📷';
    }
  }

  bool get requiresMicrophone =>
      this == DetectionMode.fusion ||
      this == DetectionMode.audio ||
      this == DetectionMode.audioVibration;

  bool get requiresCamera =>
      this == DetectionMode.fusion || this == DetectionMode.camera;

  bool get requiresVibration =>
      this == DetectionMode.fusion ||
      this == DetectionMode.audioVibration ||
      this == DetectionMode.vibration;

  static DetectionMode fromString(String? value) {
    if (value == null) return DetectionMode.fusion;
    switch (value.toLowerCase().trim()) {
      case 'audio':
        return DetectionMode.audio;
      case 'audio_vibration':
      case 'audiovibration':
        return DetectionMode.audioVibration;
      case 'vibration':
        return DetectionMode.vibration;
      case 'camera':
        return DetectionMode.camera;
      case 'fusion':
      default:
        return DetectionMode.fusion;
    }
  }
}

/// Pre-configured Environment Sensitivity Presets
enum EnvironmentPreset {
  highSensitivity(
    spikeDb: 6.0,
    vibrationMag: 0.04,
    label: 'High Sensitivity (Home)',
  ),
  balanced(spikeDb: 8.0, vibrationMag: 0.08, label: 'Balanced (Standard Gym)'),
  strictGym(
    spikeDb: 15.0,
    vibrationMag: 0.20,
    label: 'Strict (Noisy Boxing Gym)',
  );

  final double spikeDb;
  final double vibrationMag;
  final String label;

  const EnvironmentPreset({
    required this.spikeDb,
    required this.vibrationMag,
    required this.label,
  });
}
