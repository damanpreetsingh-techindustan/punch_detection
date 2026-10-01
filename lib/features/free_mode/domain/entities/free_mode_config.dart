import 'package:equatable/equatable.dart';

class FreeModeConfig extends Equatable {
  final int targetDurationSeconds;
  final bool isAudioOnly;

  const FreeModeConfig({
    this.targetDurationSeconds = 0, // 0 = Unlimited
    this.isAudioOnly = false,
  });

  @override
  List<Object?> get props => [targetDurationSeconds, isAudioOnly];
}
