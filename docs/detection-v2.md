# Detection v2 (fusionV2): adaptive impact fusion

fusionV2 is the new punch detector. The old one is the `legacy` engine. Both
can be selected; see [Selecting the engine](#selecting-the-engine-in-the-app).

The detector core is pure Dart and lives in `lib/detection_core/`. It has no
Flutter imports (a unit test enforces this), so the same code runs in three
places:

- in the app,
- in unit tests,
- in the command-line replay harness (`dart run tool/replay.dart`).

## Why it exists

Field tests (a rig in a busy gym, a wall mount in a garage) showed four
problems with the legacy detector:

- **Calibration did not hear the room.** The legacy audio target sat at its
  66 dB minimum, below the gym's ambient level.
- **Gym noise and screen taps were counted.** About 34 false counts in 236 s.
- **The per-frame camera gate missed early punches.** It also missed punches
  thrown while a glove hid the face.
- **Fast combos and soft low hooks were missed** on the wall mount (15–25 %
  of hits).

What the field data says about the signals:

| Event | Rise over the live floor | Attack |
|---|---|---|
| Real hit | 15–30 dB | < 5 ms |
| Gym noise | ~5 dB | 15 ms or more |

- Low hooks (pads 5/6) are about 10 dB quieter and attack more slowly.
- Claps are sharp but bright.
- Audio alone tops out at about 85–90 % accuracy, so the accelerometer has to
  carry low hits and claps.

## Pipeline

```
capture ──► candidates ──► features ──► score ──► soft context ──► decide
            audio onset    ≤ 40 ms      logistic   odds ×             fast / wait / reject
            OR accel shock after onset  per mount  presence, arm,
                                                   rate; hard: touch,
                                                   settings, person gone
```

| Stage | Code |
|---|---|
| Audio front end | `audio/audio_onset_tracker.dart` |
| Accelerometer front end | `accel/shock_tracker.dart` |
| Merger, decider, online learning | `engine/fusion_v2_engine.dart` |
| Features | `features/impact_features.dart` |
| Scorer (and its JSON) | `scoring/logistic_scorer.dart` |
| Trainer | `scoring/trainer.dart` |
| Soft context | `context/soft_context.dart`, `touch_lockout.dart`, `presence_window.dart` |
| Vision motion prior | `vision/arm_motion_tracker.dart` |
| Tunables | `config/detector_config.dart` |
| Replay | `replay/` (runner, folder reader, metrics) |
| Synthetic sessions | `testing/synthetic_session.dart` |
| Timing / DSP helpers | `timing/`, `dsp/`, `audio/resampler.dart` |

### Time base

Every timestamp is **detection-clock microseconds**: `MonotonicClock.epochUs()`.
That is the wall clock read once at app start plus a monotonic stopwatch.

The core itself never reads a clock; times are always passed in. Latency
measured inside the core is "data time when the decision could be made" minus
the onset.

### 1. Audio front end (`AudioOnsetTracker`)

- **Input:** 16 kHz mono PCM16.
- **Hop:** 5 ms (80 samples).
- **Filter bank:** cascaded biquads into 4 bands: 60–300 Hz, 300–1500 Hz,
  1.5–4 kHz and 4–8 kHz. A filter bank was chosen over an FFT window so that
  windowing does not delay the onset. An FFT is used only for the spectral
  features.

**Live floor**, per band:

- The 20th percentile of the hop energy over the last 3 s. It uses a
  histogram with 0.5 dB bins, so each update is O(1).
- Hops join the floor 150 ms late. By then each hop's decision is known, so
  hops within 300 ms after an **accepted** impact can be left out.
- No audio candidate is raised until the floor holds 200 ms of history (about
  0.35 s after start).

**Decay prediction:**

- After each onset, the reference follows the rising peak for 30 ms.
- It then decays at `decayDbPerS`. The start value depends on the mount (wall
  60 dB/s, rig 120 dB/s) and is learned from isolated accepted hits, using a
  least-squares slope from the peak down to floor + 3 dB.
- An accepted impact with no audio candidate (found by the accelerometer
  alone) re-anchors the prediction at its own peak.

**Novelty** (the SuperFlux idea):

- For each band: `rise_b = max(0, level_b − max(floor_b, predictedDecay_b))`.
- `novelty = max(weighted mean of rise_b, max_b rise_b − singleBandExtraDb)`.
- Because the reference includes the predicted decay, a second punch can
  register inside the first punch's ringing tail.
- The single-band term catches low hooks that rise in one band only.

**Candidate:** `novelty ≥ audioNoveltyMarginDb`, rising by at least half the
margin over the last 20 ms, and at least 30 ms after the previous candidate.

**Onset refinement:** the first 1 ms sub-block in the last 15 ms whose peak
reaches 25 % of the loudest sub-block and exceeds the background
(max(floor, predicted decay) + 10 dB).

### 2. Accelerometer front end (`ShockTracker`)

- **Input:** raw 3-axis acceleration (gravity included), stamped with sensor
  event times.
- **High-pass:** first-order, ~2 Hz, using each sample's real dt. This removes
  gravity, tilt and slow sway.
- **Jerk:** per axis and as a magnitude, in m/s³.
- **Envelope:** `env = max(jerk, env·exp(−dt/τ))`. τ is the mount's ring time
  constant: 150 ms to start, learned from isolated hits by fitting the decay of
  the running-max jerk envelope.
- **Floor:** the rolling 50th percentile of jerk over 3 s (log domain), × 3,
  never below 20 m/s³. Frames after accepted impacts are left out, as for
  audio.
- **Candidate:** `jerk > k · env_before + floor` (k = 1.5), at least 30 ms
  after the previous one. The ringing of a hit stays under the envelope; a new
  hit inside the ring rises above it.
- **Unavailable** when no sample has arrived for 500 ms.

### 3. Candidate merger (inside the engine)

- Either sensor can open an impact.
- A candidate within 80 ms of a **pending** impact merges into it. For each
  sensor the stronger candidate is kept, so a noise blip just before a hit
  cannot hide the hit's onset.
- The audio onset is the reference. A shock is placed at
  `shock onset − learned lag`.
- A candidate near an impact that was already **accepted** is the same hit
  and is dropped. Near an impact that was **rejected**, it is new evidence
  and opens a new impact.
- There is **no fixed refractory** in this engine.
- **Learned lag** (accel onset − audio onset): an exponential moving average
  (rate 0.1) over accepted impacts that had both candidates, clamped to ±60 ms.

### 4. Features (`ImpactFeatures`, at most 40 ms after onset; default 30 ms)

| name | meaning |
|---|---|
| `audio_rise_max_db`, `audio_rise_b0..b3_db` | loudest hop level minus the live floor, overall and per band (room-normalised) |
| `audio_novelty_db` | max novelty in the window |
| `audio_attack_ms` | onset → first 1 ms block ≥ 70 % of the window peak |
| `audio_peak_dbfs`, `audio_clipped_ms` | peak, with clipping compensated: +3 dB per clipped ms, at most +12 dB |
| `audio_centroid_khz`, `audio_low_ratio` | spectral centroid, and 60–300 Hz share, over the first 20 ms (512-point FFT, Hann) |
| `audio_crest_db` | peak / RMS over the window |
| `accel_env_ratio_log2` | log2 max of jerk / (decayed envelope + floor) |
| `accel_peak_jerk`, `accel_peak_acc`, `accel_energy_log10`, `accel_axis` | peak jerk, peak high-passed acceleration, energy in the window, dominant axis |
| `audio_strength_rel_log2`, `accel_strength_rel_log2` | log2 of strength / **this user's** running median over the last 30 accepted hits (seeded per mount) |
| `cross_lag_dev_ms` | \|accel − audio onset − learned lag\|; 40 when one candidate is missing |
| `cross_strength_log_ratio` | log2(accel rel / audio rel): claps are loud but barely shake the phone |

Accelerometer features are computed over the window even when no shock
candidate was found. A clap therefore shows "no shock" in its features.

### 5. Scorer (`ScorerSet`, `assets/detector/rig.json`, `wall.json`)

Logistic regression:

```
p = σ(bias + Σ weight · clip((x − center) / scale, ±4))
```

- Each mount has three models: `full`, `audioOnly` and `accelOnly`. The
  missing-sensor models are used when a sensor is **unavailable**, not merely
  when it produced no candidate.
- The shipped weights are hand-set to encode the field findings above. They
  are identical to `ScorerSet.defaults`, which a test checks. The rig weighs
  the accelerometer more than the wall does.
- Thresholds live in the JSON: `pHigh` = 0.85, `pLow` = 0.30,
  `pDecide` = 0.50.

### 6. Soft context (`SoftContext`): odds multipliers, never per-frame gates

| prior | effect |
|---|---|
| presence | no valid person in the last 1.5 s → odds × 0.15; camera off/unavailable → × 1.0 |
| person gone | no valid person for more than 5 s → **hard reject** `PERSON_GONE` |
| arm activity | `armActivity` ∈ [0, 1] → odds × (0.5 … 1.5); unknown or stale (> 500 ms) → × 1.0 |
| rate | ≥ 10 accepted in the previous second → × 0.3 |
| touch | −100 ms … +400 ms around a pointer-down → **hard reject** `TOUCH` |
| settings | sheet open, or within 1 s of closing → **hard reject** `SETTINGS_OPEN` |

### 7. Vision motion prior (`ArmMotionTracker`)

**Input:** the luma (Y) plane, area-downscaled to 160×120 or 120×160 and
rotated upright. iOS BGRA frames are converted to luma.

**Optical flow:** sparse pyramidal Lucas–Kanade:

- a fixed 12×9 grid over the lower two-thirds of the image (arms and gloves),
- 2 levels, 7×7 windows, previous frame → current frame,
- a grid point counts only if its window has enough texture (smallest
  eigenvalue).

**Per frame:**

- Mean flow in px/s.
- **Divergence** (looming): the least-squares relative expansion rate of the
  moving points around their centroid, after removing their mean flow. A
  glove punching toward the camera expands (positive). Sway or someone walking
  past is mostly translation (≈ 0).
- Both of the above for the left and right image halves, to label the hand.
  The front camera is not mirrored, so image-left is the user's right.

**Pose part:** wrist speed and the change of wrist-to-shoulder distance over
300 ms, normalised by shoulder width, from landmarks at ≥ 0.5 confidence.

**Output:** `armActivity` = the max over 300 ms of
max(divergence score, ½ flow score, pose score), plus the hand. It is only
ever an odds multiplier.

**Cost:** about 2.3 ms per frame in JIT on a laptop. If the median of 15
frames goes above 8 ms, it switches to frame-difference energy for good.

### 8. Decider

| path | when |
|---|---|
| `fast` | p ≥ pHigh when features are ready (≈ onset + 30–35 ms) → accept |
| `low` | p < pLow → reject |
| `direct` | pLow ≤ p < pHigh and both sensors have a candidate → accept if p ≥ pDecide |
| `waited` | pLow ≤ p < pHigh and one sensor that **is running** has no candidate → wait up to 80 ms for its evidence (a merge re-scores), then accept if p ≥ pDecide |
| `hard` | touch / settings open / person gone |

Every decision carries its features, p (raw and after context), path, reason,
mode and latency.

## Tunables

All tunables are in `DetectorConfig` (defaults below), the scorer JSON
(weights and thresholds) and `ArmMotionConfig`.

| field | default | meaning |
|---|---|---|
| `audioSampleRate`, `audioUsPerSample` | 16000, 62.5 | core input rate; replay passes the measured µs/sample |
| `hopSamples` | 80 | 5 ms hop |
| `bandEdgesHz`, `bandWeights` | 60/300/1500/4000/8000, 1/1/0.8/0.6 | bands and their novelty weights |
| `floorPercentile`, `floorWindowMs` | 20, 3000 | live floor |
| `floorExclusionAfterImpactMs` | 300 | accepted-impact frames kept out of the floors |
| `floorIngestDelayMs` | 150 | frames join the floor this late |
| `minFloorHistoryMs` | 200 | no audio candidates before |
| `audioNoveltyMarginDb` | 6 | audio candidate margin |
| `singleBandExtraDb` | 6 | single-band rise must exceed margin + this |
| `audioRetriggerMs`, `peakSearchMs` | 30, 30 | |
| `decayLearnRate`, `min/maxDecayDbPerS` | 0.2, 20/400 | decay learning |
| `accelHighPassHz` | 2 | |
| `shockK`, `shockFloorPercentile`, `shockFloorScale`, `shockMinJerk` | 1.5, 50, 3, 20 m/s³ | shock candidate |
| `shockFloorWindowMs`, `shockRetriggerMs` | 3000, 30 | |
| `ringTauLearnRate`, `min/maxRingTauMs` | 0.2, 30/600 | ring learning |
| `accelStaleMs` | 500 | accelerometer counts as unavailable after this |
| `mergeWindowMs`, `impactMergeMs` | 40, 80 | merging |
| `lagLearnRate`, `maxAbsLagMs` | 0.1, 60 | |
| `featureWindowMs`, `spectralWindowMs` | 30 (≤ 40), 20 | |
| `strengthHistory` | 30 | user median length |
| `waitForOtherSensorMs` | 80 | borderline wait |
| `presenceWindowMs`, `presenceMissingFactor`, `personGoneHardRejectMs` | 1500, 0.15, 5000 | |
| `armActivityMin/MaxFactor`, `armActivityMaxAgeMs` | 0.5/1.5, 500 | |
| `maxImpactsPerSecond`, `rateFactor` | 10, 0.3 | |
| `touchLockoutBeforeMs/AfterMs`, `settingsCooldownMs` | 100/400, 1000 | |

Mount seeds (`MountDefaults`):

| mount | decay | ring τ | user audio-strength seed | user jerk seed |
|---|---|---|---|---|
| wall | 60 dB/s | 150 ms | 20 dB | 150 m/s³ |
| rig | 120 dB/s | 150 ms | 20 dB | 300 m/s³ |

`ArmMotionConfig` defaults:

- 160×120 frame, 12×9 grid, 7×7 window, 5 iterations.
- `maxLkMs` 8.
- Reference values (score 1.0): flow 200 px/s, divergence 1.5 /s, wrist
  speed 3 shoulder-widths/s, reach change 0.5.
- 300 ms activity window.

## File formats

**Recorded sessions.** These are the Phase 2 raw session folder. See
[raw-logging.md](raw-logging.md) for `audio.wav`, `audio_sync.csv`,
`accel.csv`, `events.jsonl` and `session_meta.json`. The replay reads:

- the WAV, mapped to time with `session_meta.audio.mappingWav`,
- `accel.csv`, using `t_us`,
- these `events.jsonl` kinds: `touch`, `settings` (open/close), `ui`
  (camera initialized/unavailable), `cam` (frames with a valid person →
  presence) and `arm_motion` (in-app `ArmMotionTracker` output).

**labels.csv.** One true punch per line, in **seconds since the session
start** (the same clock as the `[+mm:ss.mmm]` prefixes in the exported log).
`#` comments, a header line and extra columns are ignored:

```
# hits, seconds since session start
1.532
1.811,left
2.090
```

**Scorer JSON:**

```
{mount, version, source, pHigh, pLow, pDecide,
 full|audioOnly|accelOnly: {bias, terms: {feature: {center, scale, weight}}}}
```

## Replay harness

```
dart run tool/replay.dart <session_folder> [--labels labels.csv] [--mount rig|wall]
                          [--scorer file.json] [--out decisions.csv]
                          [--sweep sweep.csv] [--no-arm] [--no-presence] [--quiet]
dart run tool/replay.dart --synthetic        # built-in golden session with labels
```

- The harness runs the core exactly as the app does: 5 ms audio chunks, every
  accelerometer sample and every context event, in time order.
- It prints every decision, the learned state and, when labels exist, these
  metrics:
  - precision, recall and F1, with ±50 ms one-to-one matching;
  - **false counts per idle minute** (idle = the session minus ±1 s around
    every label);
  - the latency distribution (median, p95) of matched accepts.
- `--no-arm` and `--no-presence` switch the priors off, to measure how much
  each one helps.
- `--out` writes every decision, with all features, as CSV.
- `--sweep` grid-searches the main margins (135 runs) and writes a CSV:
  - audio margin 4–8 dB,
  - `shockK` 1.2 / 1.5 / 2,
  - jerk floor scale 2 / 3 / 4,
  - `pHigh` 0.75 / 0.85 / 0.95.

## Labelling and retraining

1. **Record.** Turn on Settings → Debug → *Record raw data* and run a Free
   session. Screen-record it, or film it with a second phone that sees the
   bag.
2. **Export.** Results → *SHARE RAW DATA*. Put the files in one folder per
   session.
3. **Label.** Write `labels.csv` with the time of every real hit, in seconds
   since session start.
   - The exported `.txt` log stamps every line with `[+mm:ss.mmm]` on the same
     clock. Use a clearly audible event, such as the first hit, to line the
     video up with the log.
   - Label every hit you can see, including soft ones. Do not label claps,
     taps or noise.
4. **Check.** `dart run tool/replay.dart <folder>` gives the current metrics.
   `--out` shows which decisions are wrong and why (features per row).
5. **Train.** For example:
   ```
   dart run tool/train_scorer.dart --mount rig --out assets/detector/rig.json <folder> <folder> ...
   ```
   - This refits the `full`, `audioOnly` and `accelOnly` models. It uses L2
     logistic regression with class re-weighting, and keeps the same features,
     standardisation and thresholds.
   - Hard rejects (touch, settings) are excluded from training.
   - Use sessions from **one mount type** per run. Keep at least one labelled
     session out of training to check the result on.
6. **Re-check.** Run `tool/replay.dart` on the held-out session, and
   `--sweep` if the margins need moving.
7. **Ship.** The app loads `assets/detector/<mount>.json` at session start.
   Rebuild the app.
   - The asset test requires exact equality with `ScorerSet.defaults` only
     while the asset's `source` starts with "hand-set". Trained assets only
     need to parse, keep the feature list and order the thresholds.

## Golden test

`test/detection_core/golden_session_test.dart` runs a synthetic 12 s gym
session through the core and checks every decision:

- clean hits,
- a hit 250 ms into the previous hit's ringing tail,
- a soft low hit (−10 dB, 8 ms attack) with a strong shock,
- a loud clap with no shock,
- gym-noise swells with no shock,
- a phone tap together with a touch event.

It runs with three noise seeds and the rig profile, and checks that:

- every expected decision is made;
- fast-path latency inside the core is **< 45 ms** after onset (it measures
  34–35 ms);
- the decay, ring τ and lag are learned.
