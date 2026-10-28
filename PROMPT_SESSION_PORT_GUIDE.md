# Prompt Session Port Guide

Everything changed in the **Free session** for the missed-punch work, written so the same changes can be
applied to `lib/features/session/presentation/controllers/prompt_session_controller.dart` later.

- Source of truth for the code: `lib/features/session/presentation/controllers/free_session_controller.dart`.
  Every method named below exists there; copy it and adapt names.
- Status of each item: `PUNCH_FIX_TRACKER.md`.
- Search for the anchor text given for each step; line numbers drift.

---

## Part A — Already shared. Nothing to port, just use it

These files are generic and are already used by the Free session. The Prompt session only needs to call them.

| File | What it gives you |
|---|---|
| `lib/core/services/session_recording/session_event_recorder.dart` | Raw event file (JSONL) + session totals. `begin`, `record`, `count`, `stat`, `finish`, `formatElapsed`. |
| `lib/core/services/session_recording/session_totals.dart`, `raw_session_event.dart` | Used by the recorder. |
| `lib/core/services/audio_level/audio_level_sample.dart` | A mic reading with the time it really happened. |
| `lib/core/services/audio_level/pcm_level_extractor.dart` | 10 ms blocks from raw PCM. |
| `lib/core/services/audio_level/record_audio_level_service.dart` | Construct with `RecordAudioLevelService(enableSubBlockPcm: AppConstants.useSubBlockPcmLevels)` to get the new audio path. The default constructor keeps the old behaviour. |
| `lib/core/services/audio_level/i_audio_level_service.dart` | `sampleStream` and `diagnostics` (already implemented by every service and test mock). |
| `lib/core/services/audio_level/adaptive_audio_baseline.dart` | `releaseRefractory()` — call when a spike is not counted. |
| `lib/features/fusion/domain/services/impact_gate_evaluator.dart` | The "all gates in use must confirm" decision. |
| `lib/features/vision_detection/domain/services/camera_distance_gate.dart` | The distance rule. `CameraDistanceGate.fromConstants()`. |
| `lib/features/vision_detection/domain/services/camera_person_gate.dart` | The real-person rule (face AND shoulder). `CameraPersonGate.fromConstants()`. |
| `lib/core/services/session_recording/session_summary_table.dart` | Short CSV table for the export. |
| `lib/core/navigation/models/session_result_model.dart` | Fields `confirmedPunchLog`, `sessionTotalsText`, `rawEventFilePath`. |
| `lib/features/results/presentation/pages/results_page.dart` | Already exports the totals and shares the raw file for any session type. |
| `lib/core/utils/constants.dart` | All tunable values (see Part D). |

---

## Part B — Port into `prompt_session_controller.dart` (in this order)

### B1. Constructor
- [ ] Add parameters `SessionEventRecorder? recorder` and `CameraDistanceGate? distanceGate`, fields `_recorder` and `_distanceGate`
      (defaults `SessionEventRecorder()` and `CameraDistanceGate.fromConstants()`).
- [ ] Default audio service: `RecordAudioLevelService(enableSubBlockPcm: AppConstants.useSubBlockPcmLevels)`.
- [ ] Remove the import of `tri_sensor_matrix_evaluator.dart` once B5 is done (add `impact_gate_evaluator.dart`, `camera_distance_gate.dart`, `audio_level_sample.dart`, `session_event_recorder.dart`).

### B2. Instrumentation (Stage 1)
Copy these from the Free controller (anchor: `// ─── Session instrumentation`):
- [ ] Fields: `confirmedPunchLog`, `_wasVibeAboveThreshold`, `_lastVibeRiseMs`, `_lastVibeSampleMs`, `_lastAudioStreamMs`,
      `_lastAudioChunkIndex`, `_lastAudioChunkArrivalMs`, `_lastAudioValueChangeMs`, `_lastAudioStreamDb`, `_lastCameraTrackMs`,
      `_prevRegisteredPunchMs`, `_punchLogMarker`, getter `recorder`.
- [ ] Replace `_insertSpikeLog` with the new version (elapsed prefix, punch lines never evicted, `atEpochMs`).
- [ ] Copy `_configSnapshot`, `_recordConfigChange`, `_traceVibrationSample`, `_traceAudioSample`, `_trackCameraAvailability`,
      `buildSessionTotalsText`. Add prompt-specific fields to `_configSnapshot` (difficulty, prompt cadence).
- [ ] `_recordTelemetryEvent`: pass `atEpochMs: event.timestampMs` to `_insertSpikeLog`.
- [ ] `onInit`: after `_readRouteArguments()` call `_recorder.begin(startEpochMs: _sessionStartTimeMs, config: _configSnapshot())`.
- [ ] Vibration handler: call `_traceVibrationSample` and log the vibration text lines only on the rising edge.
- [ ] Mic listener: call `_traceAudioSample(sample)`; after `startMonitoring` record `audio_service` diagnostics.
- [ ] `_checkPunchDetection`: call `_trackCameraAvailability(nowMs)` after the warm-up check.
- [ ] `_registerPunch`: record the `punch` event and stats **before** the vibration peak is consumed (copy the block that
      starts with `// Instrumentation only: read the sensor peak`). Count `punch.blocked_by_settings_gate`.
- [ ] Camera: record `cam` after `liveEvaluationResult.value = tempResult;`, count `cam.face_motion_confirmed` /
      `cam.arm_punch_confirmed`, and in `_setInvalidEvaluationResult` count `cam.invalid_frames` + record `cam_invalid`.
- [ ] Settings open/close, `resetPunchCount`, `toggleVibrationGate`, `updateVibrationThreshold`, `applyEnvironmentPreset`,
      `applyAutoConfig`, spike slider, `setSessionMode`: add the same `_recorder.record` / `_recordConfigChange` calls.
- [ ] `finishSession`: build `buildSessionTotalsText`, `unawaited(_recorder.finish(extra: {...}))`, pass
      `confirmedPunchLog`, `sessionTotalsText`, `rawEventFilePath` into `SessionResultModel`.
- [ ] `onClose`: `unawaited(_recorder.dispose())`.

### B3. Timestamped audio (Stage 2)
- [ ] Mic listener: listen to `_audioLevelService.sampleStream` (type `StreamSubscription<AudioLevelSample>`), use `sample.db`,
      call `_checkPunchDetection(frameTimestampMs: sample.timestampMs)`.
- [ ] `_checkPunchDetection({int? frameTimestampMs})` passes it to `_isAudioTransient({int? frameTimestampMs})`;
      inside, `nowMs = frameTimestampMs ?? DateTime.now()...` (anchor: `bool _isAudioTransient`).
- [ ] Replace both literal `160` lockouts with `AppConstants.audioRefractoryMs` (`final int audioRefractoryMs = 160;` and
      `_adaptiveBaseline.refractoryMs = 160;`).
- [ ] `checkPunchDetectionForTesting({int? frameTimestampMs})`.

### B4. Rejected sounds must not lock out the next punch
- [ ] In `_isAudioTransient`, when the spike is below target call `_adaptiveBaseline.releaseRefractory()`.

### B5. One impact decision (audio + vibration + camera decided once)
- [ ] Copy the whole block that starts with `// ─── Impact window: audio + vibration + camera decided once` :
      `_impactGates`, `_pendingImpact`, `_eventClockMs`, `_vibeHistory`, `_cameraObservation`, `_usesImpactWindow`,
      `_impactAfterMs`, `_noteEventClock`, `_appendVibrationHistory`, `_vibrationWindowPeak`, `_isCameraGateRequired`,
      `_noteCameraObservation`, `_cameraGateState`, `_handleSpikeForImpactWindow`, `_evaluatePendingImpact`,
      `_recordImpactDecision`, and the test hooks `ingestVibrationSampleForTesting`, `setCameraObservationForTesting`.
- [ ] Copy the private classes at the end of the file: `_PendingImpact`, `_VibeSample`, `_CameraObservation`.
- [ ] In `_isAudioTransient`, right after the counters, add the early branch `if (_usesImpactWindow) { _handleSpikeForImpactWindow(...); return false; }`.
- [ ] Delete the old fusion / audio+vibration decision in `_isAudioTransient` (matrix evaluator, `vibeDetail`, `visionDetail`,
      the `audioVibration` and `fusion` classification branches, and the "MODE 2" / "MODE 3" registration blocks).
- [ ] Vibration listener: turn the closure into `_handleVibrationSample(double mag, {int? atEpochMs})`; at the top call
      `_noteEventClock`, `_appendVibrationHistory`, and `if (_usesImpactWindow) _evaluatePendingImpact();`.
      **Delete the whole `// BIDIRECTIONAL SYNC` block** (prompt controller: search that text).
- [ ] `_checkPunchDetection`: first line `_noteEventClock(frameTimestampMs ?? nowMs)`; after `_trackCameraAvailability`
      add `if (_usesImpactWindow) _evaluatePendingImpact();`.
- [ ] Remove the now-unused `_lastPendingAudioSpikeMs` field and its assignments.
- [ ] Prompt-only: `_registerPunch` there also calls `_vibrationService.resetMagnitude()`. Harmless for the window (it reads
      its own history), keep or remove consistently.

### B6. Camera distance gate
- [ ] In `_analyzeLivePose`, copy the block `// ─── DISTANCE GATE` (between the shoulder/face validation and
      `// ─── STABILITY CHECK`). It records `cam.shoulder_ratio`, rejects too-far users and calls `_noteCameraObservation`.
- [ ] Add `'distRatio'` / `'distSrc'` to the `cam` record.
- [ ] In the image stream "no pose" branch (prompt controller: search `poses.isNotEmpty`) call
      `_noteCameraObservation(CameraGateState.noPerson, detail: 'no pose detected')`.
- [ ] In `_setInvalidEvaluationResult` call `_noteCameraObservation(CameraGateState.noPerson, detail: reason)`.

### B6b. Real-person camera rule (bottle fix)
- [ ] Add constructor parameter `CameraPersonGate? personGate` (default `CameraPersonGate.fromConstants()`), field `_personGate`,
      and the static helper `_toDistanceLandmark`.
- [ ] At the top of `_analyzeLivePose` copy the block starting `// How confident ML Kit is about a face point and a shoulder`
      (computes `person`, records `cam.best_face_conf` / `cam.best_shoulder_conf`).
- [ ] Replace the relaxed branch (`// Relaxed Single-Point Validation`) with the `// Real-person check` block.
- [ ] `_setInvalidEvaluationResult(String reason, {bool noteCamera = true})` and pass `noteCamera: false` where a more
      specific observation follows (not a person, too far). Pass `faceConf` / `shoulderConf` to `_noteCameraObservation`.
- [ ] `_CameraObservation` gets `faceConf` and `shoulderConf`.

### B6c. CSV summary table
- [ ] Field `summaryTable = SessionSummaryTable()`; camera-change rows in `_noteCameraObservation`; impact rows via
      `addSummaryRow` in `_recordImpactDecision`; `summaryCsv: summaryTable.toCsv()` in `finishSession`.
- [ ] Prompt-only: consider extra columns (prompt number, reaction time) when porting.

### B7. Tests to copy and point at `PromptSessionController`
- [ ] `test/features/session/session_instrumentation_test.dart`
- [ ] `test/features/session/audio_frame_timestamp_test.dart`
- [ ] `test/features/session/impact_window_test.dart`
- [ ] `test/features/session/camera_person_check_test.dart`

---

## Part C — Prompt-only items to decide when porting

These do not exist in the Free session and are not covered above.

| Item | Why it matters |
|---|---|
| Reaction time is random (`reactionMs = 280 + Random()`) | Should be punch time minus the prompt's TTS start time (`_lastTtsSpeechStartTimeMs`). |
| TTS speaks next to the microphone | Spoken numbers can create audio spikes. Consider ignoring audio while `_isTtsSpeaking` (+ a short tail). Vibration and camera gates already make this less likely to count. |
| Advanced cadence (300 ms per number) | Shorter than a human reaction; impossible to match a punch to one prompt. |
| Prompt page has no `PopScope` | System back skips the Results page. |
| `finishSession` uses 310 ms reaction default and clamped accuracy / latency | Placeholder numbers shown as real. |

---

## Part D — Tunable values (all in `lib/core/utils/constants.dart`)

| Constant | Default | Meaning |
|---|---|---|
| `audioRefractoryMs` | 160 | Minimum gap between two counted punches. |
| `useSubBlockPcmLevels` | true | New 10 ms audio path on/off (A/B test). |
| `audioStreamChunkCandidatesMs` | [20, 40, 80] | Mic chunk sizes tried, smallest first. |
| `audioExperimentDisableMicProcessing` | false | Experiment: noise suppression / echo cancel off. |
| `audioExperimentUnprocessedSource` | false | Experiment: Android unprocessed mic source. |
| `impactVibrationBeforeMs` | 100 | Vibration may come this long before the audio spike. |
| `impactVibrationAfterMs` | 150 | ...or this long after; also the max decision wait. |
| `cameraPersonGateEnabled` | true | Real-person rule on/off (off = old "any point >= 0.20"). |
| `cameraMinFaceConfidence` | 0.5 | Best face point must reach this confidence. |
| `cameraMinShoulderConfidence` | 0.5 | Best shoulder must reach this confidence. |
| `cameraRequireFaceAboveShoulder` | true | Face must be above the shoulder in the image. |
| `cameraDistanceGateEnabled` | true | Distance rule on/off. |
| `cameraMinShoulderWidthRatio` | 0.09 | Farther than this (smaller ratio) = not a valid user. |
| `cameraMinEyeSpanRatio` | 0.014 | Same rule when only the eyes are measurable. |
| `cameraDistanceUnknownIsValid` | true | Distance not measurable -> treat as valid. |
| `cameraObservationStaleMs` | 700 | Camera result older than this no longer counts. |

---

## Change log
- 2026-10-22: Guide created (covers Stage 1, Stage 2, one impact decision, camera distance gate).
- 2026-10-22: Added B6b (real-person rule) and B6c (CSV summary table).
