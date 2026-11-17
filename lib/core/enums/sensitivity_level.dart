import 'detection_enums.dart';

/// User-facing punch sensitivity. Maps onto the existing [EnvironmentPreset]
/// values; [normal] keeps the engine defaults untouched.
enum SensitivityLevel {
  high(
    id: 'high',
    label: 'High',
    description: 'Counts lighter punches. Best for a quiet room.',
    preset: EnvironmentPreset.highSensitivity,
  ),
  normal(
    id: 'normal',
    label: 'Normal',
    description: 'Recommended for most places.',
    preset: null,
  ),
  low(
    id: 'low',
    label: 'Low',
    description: 'Ignores more background noise. Best for a busy gym.',
    preset: EnvironmentPreset.strictGym,
  );

  final String id;
  final String label;
  final String description;
  final EnvironmentPreset? preset;

  const SensitivityLevel({
    required this.id,
    required this.label,
    required this.description,
    required this.preset,
  });

  static SensitivityLevel fromId(String? id) => SensitivityLevel.values
      .firstWhere((l) => l.id == id, orElse: () => SensitivityLevel.normal);
}
