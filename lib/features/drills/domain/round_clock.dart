import 'drill_program.dart';

enum RoundPhase { work, rest, done }

/// What changed on a [RoundClock.tick].
enum RoundEvent { none, restStarted, roundStarted, finished, restEndingSoon }

/// Counts rounds and rest, one second per [tick]. Pure (no timers), so it is
/// easy to test; the drill controller drives it with a 1 s timer.
class RoundClock {
  final RoundPlan plan;

  RoundClock(this.plan)
    : round = 1,
      phase = RoundPhase.work,
      secondsLeft = plan.isOpen ? 0 : plan.roundSeconds;

  int round;
  RoundPhase phase;
  int secondsLeft;

  bool get isOpen => plan.isOpen;
  bool get isLastRound => round >= plan.rounds;

  /// Seconds before the end of a rest when the user is warned.
  static const int warnSeconds = 3;

  RoundEvent tick() {
    if (isOpen || phase == RoundPhase.done) return RoundEvent.none;
    secondsLeft--;
    if (secondsLeft > 0) {
      if (phase == RoundPhase.rest && secondsLeft == warnSeconds) {
        return RoundEvent.restEndingSoon;
      }
      return RoundEvent.none;
    }
    if (phase == RoundPhase.work) {
      if (isLastRound) {
        phase = RoundPhase.done;
        secondsLeft = 0;
        return RoundEvent.finished;
      }
      phase = RoundPhase.rest;
      secondsLeft = plan.restSeconds;
      return RoundEvent.restStarted;
    }
    // Rest over.
    round++;
    phase = RoundPhase.work;
    secondsLeft = plan.roundSeconds;
    return RoundEvent.roundStarted;
  }
}
