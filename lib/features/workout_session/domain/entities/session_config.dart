import 'package:equatable/equatable.dart';

class SessionConfig extends Equatable {
  final int roundDurationSeconds;
  final int restDurationSeconds;
  final int totalRounds;
  final bool isAudioOnly;

  const SessionConfig({
    this.roundDurationSeconds = 180,
    this.restDurationSeconds = 30,
    this.totalRounds = 3,
    this.isAudioOnly = false,
  });

  @override
  List<Object?> get props => [
        roundDurationSeconds,
        restDurationSeconds,
        totalRounds,
        isAudioOnly,
      ];
}
