import 'dart:developer' as developer;
import 'dart:math';
import 'dart:ui';

import '../../../../core/utils/constants.dart';

/// Isolated Testing Service for Real-time Arm Angle Validation.
/// Measures the Shoulder-to-Elbow vector direction angle in degrees [0°, 360°).
/// Checks if the angle falls into either target range:
/// - Range 1: 150° to 210°
/// - Range 2: 330° to 30° (330°..360° or 0°..30°)
/// Logs YES or NO explicitly in console on every frame for test tracking.
class ArmAngleTester {
  /// Evaluates arm angles for both Left and Right arms.
  static void evaluateAndLogAngles({
    required Offset? leftShoulder,
    required Offset? leftElbow,
    required Offset? rightShoulder,
    required Offset? rightElbow,
  }) {
    _evaluateArm('LEFT', leftShoulder, leftElbow);
    _evaluateArm('RIGHT', rightShoulder, rightElbow);
  }

  static void _evaluateArm(String armSide, Offset? shoulder, Offset? elbow) {
    if (shoulder == null || elbow == null) {
      final String nullMsg =
          '[ARM-ANGLE-TEST] Arm: $armSide | Angle: N/A (Landmarks missing) | In Target Range: NO';
      if (AppConstants.testingAnglerLogs) {
        developer.log(nullMsg, name: 'ArmAngleTester');
      }
      return;
    }

    // Vector from Elbow -> Shoulder
    final double dx = shoulder.dx - elbow.dx;
    final double dy = shoulder.dy - elbow.dy;

    // Calculate 2D angle (Elbow -> Shoulder) in degrees [0°, 360°)
    double angleDeg = atan2(dy, dx) * 180.0 / pi;
    if (angleDeg < 0) angleDeg += 360.0;

    // Range 1: 150°..210°
    final bool isRange1 = angleDeg >= 150.0 && angleDeg <= 210.0;
    // Range 2: 330°..30° (330°..360° or 0°..30°)
    final bool isRange2 = angleDeg >= 330.0 || angleDeg <= 30.0;

    final bool isInTargetRange = isRange1 || isRange2;
    final String resultStr = isInTargetRange ? 'YES' : 'NO';

    String matchedRangeText = 'None (Out of range)';
    if (isRange1) {
      matchedRangeText = 'Matched 150°-210° Range';
    } else if (isRange2) {
      matchedRangeText = 'Matched 330°-30° Range';
    }

    // need change

    if (AppConstants.testingAnglerLogs) {
      final String logMessage =
          '[ARM-ANGLE-TEST] Arm: ${armSide.padRight(5)} | Angle (Elbow->Shoulder): ${angleDeg.toStringAsFixed(1).padLeft(5)}° | '
          'In Target Range (150°-210° / 330°-30°): $resultStr ($matchedRangeText)';

      if (AppConstants.testingAnglerLogs) {
        developer.log(logMessage, name: 'ArmAngleTester');
      }
    }
  }
}
