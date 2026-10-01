import 'dart:math';
import 'package:flutter/material.dart';
import 'package:punch_detection_demo/core/utils/constants.dart';

/// Crisp Thin Blue Line Audio Decibel Graph Painter with Soft Light Gradient Fill.
///
/// Draws a real-time curved audio waveform with glowing electric blue line,
/// gradient fill underneath, and subtle horizontal threshold gate reference line.
class AudioSpikeWaveformPainter extends CustomPainter {
  final List<double> decibelSamples;
  final double thresholdDb;
  final double? calibrationDb;
  final double? minGraphDb;
  final double? maxGraphDb;
  final Color lineColor;
  final Color thresholdLineColor;
  final Color calibrationLineColor;
  final bool showThresholdLine;
  final bool showCalibrationLine;

  AudioSpikeWaveformPainter({
    required this.decibelSamples,
    required this.thresholdDb,
    this.calibrationDb,
    this.minGraphDb,
    this.maxGraphDb,
    this.lineColor = const Color(0xFF38BDF8), // Electric Sky Blue
    this.thresholdLineColor = const Color.fromARGB(
      255,
      26,
      255,
      0,
    ), // Vibrant Punch Threshold Line (Green/Lime)
    this.calibrationLineColor = const Color(0xFF00E5FF), // Static Calibration Line (Cyan)
    this.showThresholdLine = true,
    this.showCalibrationLine = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double width = size.width;
    final double height = size.height;

    // Decibel display boundaries dynamically managed from AppConstants
    final double effectiveMinDb = minGraphDb ?? AppConstants.minAudioGraphDb;
    final double effectiveMaxDb = maxGraphDb ?? AppConstants.maxAudioGraphDb;
    final double dbRange = max(1.0, effectiveMaxDb - effectiveMinDb);

    // 1. Static Calibration Reference Line (Cyan)
    if (showCalibrationLine && calibrationDb != null && calibrationDb! > 0) {
      final double normalizedCalib =
          ((calibrationDb! - effectiveMinDb).clamp(0.0, dbRange)) / dbRange;
      final double calibY = height - (normalizedCalib * height);
      final calibPaint = Paint()
        ..color = calibrationLineColor
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(0, calibY),
        Offset(width, calibY),
        calibPaint,
      );
    }

    // 2. Audio Punch Target Reference Line (Green/Lime)
    if (showThresholdLine) {
      final double normalizedThreshold =
          ((thresholdDb - effectiveMinDb).clamp(0.0, dbRange)) / dbRange;
      final double thresholdY = height - (normalizedThreshold * height);
      final thresholdPaint = Paint()
        ..color = thresholdLineColor
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(0, thresholdY),
        Offset(width, thresholdY),
        thresholdPaint,
      );
    }

    if (decibelSamples.isEmpty) return;

    final int sampleCount = decibelSamples.length;
    final double stepX = width / max(1, sampleCount - 1);

    final List<Offset> points = [];
    for (int i = 0; i < sampleCount; i++) {
      final double db = decibelSamples[i];
      final double x = i * stepX;
      final double normalizedDb =
          ((db - effectiveMinDb).clamp(0.0, dbRange)) / dbRange;
      final double y = height - (normalizedDb * height);
      points.add(Offset(x, y));
    }

    if (points.isNotEmpty) {
      final Path linePath = Path();
      final Path areaPath = Path();

      linePath.moveTo(points.first.dx, points.first.dy);
      areaPath.moveTo(points.first.dx, height);
      areaPath.lineTo(points.first.dx, points.first.dy);

      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final controlX = (p0.dx + p1.dx) / 2;
        linePath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
        areaPath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      }

      areaPath.lineTo(points.last.dx, height);
      areaPath.close();

      // 2. Below Bar Data Gradient Area Fill
      final areaGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.25),
          lineColor.withValues(alpha: 0.0),
        ],
      );

      final areaPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = areaGradient.createShader(
          Rect.fromLTRB(0, 0, width, height),
        );
      canvas.drawPath(areaPath, areaPaint);

      // 3. Line Glow Aura Layer
      final glowPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.40)
        ..strokeWidth = 2.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(linePath, glowPaint);

      // 4. Primary Line Path
      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(linePath, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant AudioSpikeWaveformPainter oldDelegate) {
    return true;
  }
}
