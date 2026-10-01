import 'package:equatable/equatable.dart';

class PromptCombo extends Equatable {
  final String id;
  final String calloutText; // e.g. "1", "1-2", "Jab Cross"
  final int audioStartTimestampUs;

  const PromptCombo({
    required this.id,
    required this.calloutText,
    required this.audioStartTimestampUs,
  });

  @override
  List<Object?> get props => [id, calloutText, audioStartTimestampUs];
}
