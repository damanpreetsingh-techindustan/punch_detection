# Punch Detection Fix Tracker

Single place that records what is done and what is pending for the missed-punch / background-punch work.
Update this file after every step (status, date, files touched).

Status values: `DONE`, `CODED (needs phone test)`, `PENDING`, `LATER (user decision)`.

## Decisions from the user
| # | Decision |
|---|---|
| D1 | Instrumentation first, then audio fixes. |
| D2 | Camera is a **hard gate**: no shoulder/face visible means no punch, even a real bag hit. One visible shoulder or face is enough. |
| D3 | Priority: **never miss a punch**. Extra audio/camera gates against false punches come later. |
| D4 | Distance / background-person gating is **later**. |
| D5 | `prompt_session_controller.dart` gets the same changes **later**. Only the Free session is touched for now. |
| D6 | Phone is held on top of the bag with a holder (bag vibration reaches the phone). Phone model / OS not yet stated. |
| D7 | Rapid-punch cadence unknown. Stage 1 measures it (`interval.inter_punch_ms` in the export). 160 ms lockout unchanged for now. |
| D8 | A punch counts only when audio + vibration + camera all confirm. Camera disabled -> audio + vibration. |
| D9 | Camera valid = any one shoulder OR any face point visible, AND the user is within the allowed distance. Distance value lives in `AppConstants` and must be easy to change. |
| D10 | Only the distance rule is added now. Other audio / camera gates: list them, add later. |
| D11 | (Test 2026-10-22: a bottle was accepted as the user.) Camera valid = a face point AND a shoulder, each >= 50% confidence, face above shoulder. Face + one shoulder is valid. Replaces "shoulder OR face" from D2/D9. |
| D12 | Do NOT change the vibration threshold. Do NOT cap or change the audio target. |
| D13 | The raw `.jsonl` is too hard to share: export a short CSV table instead (also appended to the `.txt`). |

## Work items
| Item | Status | Date | Notes |
|---|---|---|---|
| Stage 1: instrumentation (no behaviour change) | CODED (needs phone test) | 2026-10-22 | Unit tests pass. Not yet run on a phone. |
| Stage 2: audio fixes | CODED (needs phone test) | 2026-10-22 | Behind `AppConstants.useSubBlockPcmLevels`. Not yet run on a phone. |
| One impact decision (single decision window) | CODED (needs phone test) | 2026-10-22 | D8. Fusion + Audio+Vibration modes. See "One impact decision" below. |
| Camera hard-gate rule (one shoulder or face, plus distance) | CODED (needs phone test) | 2026-10-22 | D2 + D9. Part of the impact decision. |
| Camera distance gate | CODED (needs phone test) | 2026-10-22 | D9. Default `cameraMinShoulderWidthRatio = 0.09` is a guess; calibrate from `cam.shoulder_ratio`. |
| Real-person camera rule (face AND shoulder >= 50%) | CODED (needs phone test) | 2026-10-22 | D11. Fixes the bottle case. Values in `AppConstants.cameraMin*Confidence`. |
| Short CSV decision/camera table in the export | CODED (needs phone test) | 2026-10-22 | D13. `hyper_hitter_summary_*.csv` + section at the end of the `.txt`. |
| Same changes in `prompt_session_controller.dart` | LATER (user decision) | | D5. Step-by-step checklist: `PROMPT_SESSION_PORT_GUIDE.md`. |
| Extra audio / camera gates against false punches | LATER (user decision) | | D10. Options listed under "Gate ideas" below. |
| Left/right split defaults to "right" when the camera finds no arm | PENDING (not requested) | | Caused the 25/205 split in the first log. Kept as-is in the new decision code. |
| Reaction time / accuracy / latency are placeholder values | PENDING (not requested) | | |
| Workout history is in memory only | PENDING (not requested) | | |
| `formattedSessionModeLabel` shows "FUSION (AUDIO + CAMERA)" for modes it does not list | PENDING (not requested) | | |

## Stage 1 breakdown (all coded, tests pass)
| Step | Status | Where |
|---|---|---|
| 1.1 Session event recorder (JSONL + totals) | DONE | `lib/core/services/session_recording/*` |
| 1.2 Elapsed time `[+mm:ss.mmm]` on every log line | DONE | `_insertSpikeLog` in `free_session_controller.dart` |
| 1.3 Punches never evicted; vibration text log only on rising edge | DONE | `_insertSpikeLog`, `_traceVibrationSample`, `confirmedPunchLog` |
| 1.4 Audio-vs-vibration lag logging | DONE | `lag.audio_minus_vibe_ms` stat, `decision` events |
| 1.5 Per-session totals | DONE | `buildSessionTotalsText`, `SessionTotals` |
| 1.6 Export raw event file with the text log | DONE | `results_page.dart`, `SessionResultModel` |
| 1.7 Tests | DONE | `test/core/services/session_recording/`, `test/features/session/session_instrumentation_test.dart` |

## Stage 2 breakdown (all coded, tests pass)
| Step | Status | Where |
|---|---|---|
| 2.1 PCM sub-block level extraction + buffer probe | DONE | `pcm_level_extractor.dart`, `record_audio_level_service.dart` |
| 2.2 Timestamped sample stream into the Free controller | DONE | `audio_level_sample.dart`, `IAudioLevelService.sampleStream`, `free_session_controller.dart` |
| 2.3 Clipping flag + default-off experiments | DONE | `AudioLevelSample.clipped`, `AppConstants.audioExperiment*` |
| 2.4 Lockout moved to `AppConstants.audioRefractoryMs` (still 160) | DONE | Free controller only |
| 2.5 Tests | DONE | `pcm_level_extractor_test.dart`, `audio_frame_timestamp_test.dart` |

## One impact decision (how it works now)
- Used in `DetectionMode.fusion` and `DetectionMode.audioVibration`. Audio-only, vibration-only and camera-only modes are unchanged.
- An audio spike that reaches the target opens a window. Vibration is looked up by timestamp from 100 ms before to 150 ms after the spike (`impactVibrationBeforeMs` / `impactVibrationAfterMs`), so it no longer matters whether audio or vibration reports first.
- Gates in use must all pass: vibration (unless pole mount / gate off), camera (unless the mode has no camera, vision confirmation is off, or the camera failed to start).
- Decided as soon as all pass; otherwise rejected when the window closes, with a code saying which gate failed (`IMPACT_REJECTED_NO_VIBRATION`, `..._CAMERA_TOO_FAR`, `..._CAMERA_NO_PERSON`, `..._CAMERA_NOT_READY`).
- Rejected or below-target sounds release the 160 ms lockout, so they no longer block the next real punch.
- Registering a punch no longer erases the next punch's vibration for this decision (the window reads its own history).
- Removed from the Free controller: the vibration-triggered "sync" path and the `TriSensorMatrixEvaluator` use. The matrix file is unchanged and still used by the Prompt session.
- Known trade-off: the camera is a hard gate, so a punch thrown while the camera is still starting up is rejected (`IMPACT_REJECTED_CAMERA_NOT_READY`). This is the most likely cause of the old "first punch missed".

## Camera rules (Free session)
- Valid user (since D11): at least one face point (nose, eye, inner eye, ear, mouth) AND at least one shoulder, each with confidence >= `cameraMinFaceConfidence` / `cameraMinShoulderConfidence` (0.5), and the face above the shoulder (`cameraRequireFaceAboveShoulder`). `cameraPersonGateEnabled = false` restores the old "any point >= 0.20" rule.
- Tuning: SESSION TOTALS shows `cam.best_face_conf` / `cam.best_shoulder_conf`; the CSV table shows both on every camera change. Compare "you in frame" with "only the object in frame".
- Distance. Shoulder width / image diagonal must be >= `cameraMinShoulderWidthRatio` (eyes used if shoulders are not both visible). Not measurable -> valid (`cameraDistanceUnknownIsValid`).
- How to tune: stand at the farthest place that should still count, finish a session, read `cam.shoulder_ratio` min/avg/max in SESSION TOTALS, set the constant a little below the average.

## Gate ideas for later (D10, not implemented)
Audio: rise measured against the live room level (not the calibration value), impulse width (a punch thud is short), frequency content (thud vs clap/voice) from the PCM blocks, ignore audio while the app's own TTS is speaking (Prompt), clipping-aware peak.
Vibration: rise above the level just before the impact (rejects bag sway), require a fresh rising edge, axis direction of the shock.
Camera: lock onto the calibrated user's body size (± band) so only that person counts, require a punch-like arm/shoulder movement within ±400 ms of the impact, user centred in frame, too-close limit.
Cross-sensor: audio-vibration lag must fall in a learned band, maximum human punch rate sanity check.

## Differences from the approved plan
- Timeline uses wall-clock epoch milliseconds minus session start (not a separate `Stopwatch`), so it is in the same time base as the sensor timestamps.
- The elapsed prefix is added in one place, `_insertSpikeLog`, not inside `PunchTelemetryEvent.toLogString`.
- Refractory blocks are counted (`audio.refractory_blocks`) and visible as `refractory: true` on `decision` events, not a separate event kind.
- Buffer candidates are defined as chunk lengths in milliseconds (`audioStreamChunkCandidatesMs`) and converted to bytes from the real sample rate.
- `RecordAudioLevelService` only uses the new PCM path when constructed with `enableSubBlockPcm: true` (the Free controller does this). Prompt and the pre-check screens still get the old behaviour, so D5 holds.

## Found while working (not caused by this work)
- `record_audio_level_service.dart` had an uncommitted Android-only block (16 kHz, mono, PCM16) that is not in git history and not in the build the original test log came from. It is kept exactly as the legacy path. The new PCM path records at the same rate so an A/B comparison only differs in chunking.
- A "version upgrade" commit and a branch switch (`changes_on_client_feedback_points_22_oct`) happened during the session. All edits were applied on top of the current files.

## Baseline vs now
- Before any change: `flutter analyze` 5 issues (pre-existing), `flutter test` 84 passing.
- Now: `flutter analyze` the same 5 issues, `flutter test` 180 passing.

## Next field test (what to do and send back)
1. Phone test with `useSubBlockPcmLevels = true` (default). Do a screen recording and a manual punch count.
2. Run once with `useSubBlockPcmLevels = false` for the A/B baseline (same bag, same exercises: singles after a pause, 10x10 rapid).
3. Note the phone model and Android version (the recording cannot read them).
4. Send both exported files per run: the `.txt` log and the `hyper_hitter_raw_events_*.jsonl`.
5. Things to read first: `audio_service` event (chosen buffer, `chunkIntervalMs`), `lag.audio_minus_vibe_ms`, `audio.saturated_frames`, `sync.*` counters, `interval.inter_punch_ms`.

## Change log
- 2026-10-22: Tracker created. Plan approved.
- 2026-10-22: Stage 1 and Stage 2 coded; 120 tests pass; analyzer unchanged (5 pre-existing issues).
- 2026-10-22: One impact decision + camera distance gate coded (Free session). `PROMPT_SESSION_PORT_GUIDE.md` created. 160 tests pass; analyzer unchanged (5 pre-existing issues).
- 2026-10-22: Phone test 2: audio path confirmed working (20 ms chunks, 10 ms blocks, punches 172 ms apart counted). A bottle was accepted as the user -> real-person rule (D11) + CSV table (D13) coded. 180 tests pass; analyzer unchanged.
