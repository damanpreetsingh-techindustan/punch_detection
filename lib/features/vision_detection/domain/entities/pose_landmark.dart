import 'package:equatable/equatable.dart';

class PoseLandmark extends Equatable {
  final double x;
  final double y;
  final double z;
  final double likelihood;

  const PoseLandmark({
    required this.x,
    required this.y,
    required this.z,
    this.likelihood = 1.0,
  });

  @override
  List<Object?> get props => [x, y, z, likelihood];
}
