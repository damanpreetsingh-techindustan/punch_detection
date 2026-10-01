import 'dart:math';

class AudioCalibrationDatasource {
  /// Computes the 30th percentile noise floor baseline from recorded RMS samples
  double computeNoiseFloorBaseline(List<double> rmsSamples) {
    if (rmsSamples.isEmpty) return 0.05; // Fallback baseline

    final sorted = List<double>.from(rmsSamples)..sort();
    final int index30 = (sorted.length * 0.30).floor();
    final double baseline = sorted[index30.clamp(0, sorted.length - 1)];

    return max(0.01, baseline);
  }

  /// Calculates dynamic energy multiplier threshold based on baseline level
  double calculateAdaptiveMultiplier(double baselineRms) {
    // Quiet gym baseline (<0.05) -> higher sensitivity multiplier (3.5x)
    // Loud gym baseline (>=0.15) -> lower sensitivity multiplier (2.2x)
    if (baselineRms < 0.05) {
      return 3.5;
    } else if (baselineRms >= 0.15) {
      return 2.2;
    } else {
      // Linear interpolation between 3.5x and 2.2x
      final double ratio = (baselineRms - 0.05) / (0.15 - 0.05);
      return 3.5 - (ratio * (3.5 - 2.2));
    }
  }
}
