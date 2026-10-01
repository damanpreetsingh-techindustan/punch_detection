import 'package:equatable/equatable.dart';

class SignalTelemetry extends Equatable {
  final double audioRms;
  final double peakAmplitude;
  final double spectralFlatness;
  final double elbowAngle;
  final double wristVelocity;
  final bool isAudioCandidate;
  final bool isVisionCandidate;
  final bool isFusedPunch;

  const SignalTelemetry({
    required this.audioRms,
    required this.peakAmplitude,
    required this.spectralFlatness,
    required this.elbowAngle,
    required this.wristVelocity,
    required this.isAudioCandidate,
    required this.isVisionCandidate,
    required this.isFusedPunch,
  });

  factory SignalTelemetry.initial() {
    return const SignalTelemetry(
      audioRms: 0.02,
      peakAmplitude: 0.05,
      spectralFlatness: 0.85,
      elbowAngle: 90.0,
      wristVelocity: 0.2,
      isAudioCandidate: false,
      isVisionCandidate: false,
      isFusedPunch: false,
    );
  }

  @override
  List<Object?> get props => [
        audioRms,
        peakAmplitude,
        spectralFlatness,
        elbowAngle,
        wristVelocity,
        isAudioCandidate,
        isVisionCandidate,
        isFusedPunch,
      ];
}
