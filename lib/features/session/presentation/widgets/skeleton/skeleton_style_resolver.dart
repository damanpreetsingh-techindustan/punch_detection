import '../../../../fusion/domain/services/impact_gate_evaluator.dart';
import 'skeleton_style.dart';

/// Chooses how the pose skeleton is drawn from the live camera gate state.
abstract class ISkeletonStyleResolver {
  SkeletonStyle resolve(CameraGateState state);
}

/// Active look while the user would pass the camera gate, inactive (grey)
/// when the user is too far or not seen as a person.
///
/// A user held near by the hook / side-stance latch is reported as
/// [CameraGateState.valid], so the skeleton stays active during hooks, exactly
/// like punch counting. Start-up states stay active so the overlay does not
/// flash grey while the camera starts.
class CameraGateSkeletonStyleResolver implements ISkeletonStyleResolver {
  const CameraGateSkeletonStyleResolver();

  @override
  SkeletonStyle resolve(CameraGateState state) => switch (state) {
    CameraGateState.tooFar ||
    CameraGateState.noPerson => SkeletonStyle.inactive,
    CameraGateState.valid ||
    CameraGateState.notReady ||
    CameraGateState.notRequired => SkeletonStyle.active,
  };
}
