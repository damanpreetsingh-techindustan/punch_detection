import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../domain/services/person_focus/i_person_focus_strategy.dart';

/// Original behaviour: the pose detector always gets the full frame.
class NoPersonFocus implements IPersonFocusStrategy {
  const NoPersonFocus();

  @override
  Future<PersonFocusResult> prepare(InputImage original) async =>
      PersonFocusResult(image: original);

  @override
  void reset() {}

  @override
  Future<void> close() async {}
}
