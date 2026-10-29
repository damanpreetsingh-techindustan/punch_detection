import 'dart:math' as math;
import 'dart:typed_data';

import '../accel/shock_tracker.dart';
import '../engine/fusion_v2_engine.dart';

/// A context event for the engine at a time (detection clock µs).
class ContextEvent {
  final int tUs;

  /// touch | settings_open | settings_close | camera_on | camera_off |
  /// person_valid | arm_activity
  final String kind;
  final double value; // arm activity score
  final String hand; // arm activity hand

  const ContextEvent(
    this.tUs,
    this.kind, {
    this.value = 0,
    this.hand = 'unknown',
  });
}

/// Everything one session feeds into the engine.
class ReplayInput {
  /// 16-bit mono audio at the engine's sample rate.
  final Int16List audio;

  /// Time of audio[0] and µs per sample on the detection clock.
  final int audioStartUs;
  final double audioUsPerSample;
  final List<AccelSampleIn> accel;
  final List<ContextEvent> events;

  const ReplayInput({
    required this.audio,
    required this.audioStartUs,
    required this.audioUsPerSample,
    required this.accel,
    required this.events,
  });

  int get endUs => math.max(
    (audioStartUs + audio.length * audioUsPerSample).round(),
    accel.isEmpty ? 0 : accel.last.tUs,
  );
}

/// Feeds [input] into [engine] in time order exactly as the app does: audio in
/// [audioChunkSamples] pieces, every accelerometer sample, every context event.
/// Returns every decision (including the final flush).
List<ImpactDecision> runReplay(
  FusionV2Engine engine,
  ReplayInput input, {
  int audioChunkSamples = 80,
  void Function(ImpactDecision)? onDecision,
}) {
  final List<ImpactDecision> decisions = <ImpactDecision>[];
  void take(List<ImpactDecision> ds) {
    for (final ImpactDecision d in ds) {
      decisions.add(d);
      onDecision?.call(d);
    }
  }

  final List<ContextEvent> events = List<ContextEvent>.of(input.events)
    ..sort((ContextEvent a, ContextEvent b) => a.tUs.compareTo(b.tUs));
  int ai = 0, ci = 0, ei = 0;
  final int n = input.audio.length;
  while (ai < n || ci < input.accel.length || ei < events.length) {
    final int audioEnd = math.min(n, ai + audioChunkSamples);
    final double audioT = ai < n
        ? input.audioStartUs + (audioEnd - 1) * input.audioUsPerSample
        : double.infinity;
    final double accelT = ci < input.accel.length
        ? input.accel[ci].tUs.toDouble()
        : double.infinity;
    final double eventT = ei < events.length
        ? events[ei].tUs.toDouble()
        : double.infinity;
    if (eventT <= audioT && eventT <= accelT) {
      _applyEvent(engine, events[ei++]);
    } else if (accelT <= audioT) {
      take(engine.addAccel(input.accel[ci++]));
    } else {
      take(
        engine.addAudio(
          Int16List.sublistView(input.audio, ai, audioEnd),
          (input.audioStartUs + ai * input.audioUsPerSample).round(),
        ),
      );
      ai = audioEnd;
    }
  }
  take(engine.advance(input.endUs + 200000));
  take(engine.flush());
  return decisions;
}

void _applyEvent(FusionV2Engine engine, ContextEvent e) {
  switch (e.kind) {
    case 'touch':
      engine.addTouch(e.tUs);
    case 'settings_open':
      engine.setSettingsOpen(true, e.tUs);
    case 'settings_close':
      engine.setSettingsOpen(false, e.tUs);
    case 'camera_on':
      engine.setCameraAvailable(true, e.tUs);
    case 'camera_off':
      engine.setCameraAvailable(false, e.tUs);
    case 'person_valid':
      engine.notePersonValid(e.tUs);
    case 'arm_activity':
      engine.setArmActivity(e.value, e.hand, e.tUs);
  }
}
