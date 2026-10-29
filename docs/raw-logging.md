# Raw session logging

Full-rate sensor recording for offline replay and tuning. Instrumentation only:
nothing here feeds detection.

## Turning it on

- **Before a session:** Settings → Debug → **Record raw data**.
- **During a session:** session settings sheet → *Debug / experiments* →
  **Record raw data**. Recording starts or stops at that moment.
- The flag is `AppConstants.recordRawSessionData` (default `false`). It stays
  set until the app restarts.
- Currently recorded by the **Free session** only.

After the session, open the Results page and tap **SHARE RAW DATA**. This shares
every file in the session folder through the system share sheet. The usual
`.txt` / `.csv` export still works.

## Folder

```
<app documents>/raw_sessions/session_<sessionStartMs>/
  audio.wav
  audio_sync.csv
  accel.csv
  events.jsonl
  session_meta.json
```

`<sessionStartMs>` is the session start on the detection clock (see below). The
folder is finalized a moment after the session ends: first the event file is
closed and copied in, then the WAV header is patched and `session_meta.json` is
written.

## Time base

Every timestamp uses the **detection clock**, `MonotonicClock.epochUs()` (or
`epochMs()`). It is the wall clock read once at app start plus a monotonic
stopwatch, so values look like epoch time but never jump when the phone's clock
changes.

- `t_us`: microseconds on the detection clock.
- `tMs` in `events.jsonl`: milliseconds since session start.
- `epochMs` in `events.jsonl`: detection-clock milliseconds.

## audio.wav

- Mono, 16-bit signed little-endian PCM, **16 kHz**, standard 44-byte RIFF
  header.
- Android captures at 16 kHz and the samples are written unchanged.
- iOS captures at 44.1 kHz. The audio is resampled to 16 kHz with a
  band-limited windowed-sinc filter (`lib/detection_core/audio/resampler.dart`,
  cutoff ≈ 7.4 kHz). The resampler holds back the last ~1 ms of input, so the
  WAV may be that much shorter than the capture.
- The microphone settings in force (noise suppression, echo cancel, audio
  source, iOS measurement mode) are listed in `session_meta.json` →
  `flags` and `audio.service`.

## audio_sync.csv

Maps WAV sample indices to the detection clock.

```
wav_sample_index,t_us,capture_sample_index
```

- **One row per second.** Each row is the audio buffer that arrived with the
  least delay in that second.
- `capture_sample_index` is the number of samples captured at the native rate
  up to the end of that buffer. `wav_sample_index` is the same point on the
  16 kHz WAV timeline.
- `t_us` is the buffer's **arrival** time. It is therefore late by the delivery
  latency, typically 2–20 ms, and never early.

Use the fitted mapping in `session_meta.json`. It handles both the latency and
the capture clock's drift against the system clock (tens of ppm, i.e. tens of
ms over 10 min):

```
t_us(wav_sample_index) = audio.mappingWav.interceptUs
                       + wav_sample_index * audio.mappingWav.usPerSample
```

- The slope is a least-squares fit over all sync points.
- The intercept is the lower envelope (the least-delayed point).

Implementation: `SampleClockMapping.fit` in
`lib/detection_core/timing/sample_clock.dart`.

`audio.firstSampleUs` is a quick estimate of the first sample's time: first
buffer arrival minus its duration.

## accel.csv

Raw 3-axis accelerometer, **gravity included**, in m/s².

```
t_us,sensor_ns,x,y,z
```

| | Android | iOS |
|---|---|---|
| Source | `TYPE_ACCELEROMETER` | CoreMotion accelerometer |
| Rate | `SENSOR_DELAY_FASTEST` (capped at 200 Hz on Android 12+ without `HIGH_SAMPLING_RATE_SENSORS`) | 100 Hz requested |
| Native timestamp (`sensor_ns`) | `SensorEvent.timestamp` (elapsedRealtimeNanos) | `CMAccelerometerData.timestamp` (system uptime) |

- `t_us` comes from the **sensor event timestamp**, not the arrival time,
  mapped onto the detection clock.
- **Mapping.** Every native batch carries the native "now" at send time. The
  smallest (Dart receive time − native now) seen is the clock offset; that
  observation travelled fastest (`ClockOffsetEstimator`). Early rows can be off
  by up to the first batches' channel delay (≤ a few ms).
  `accel.service.clockOffsetUs` in the meta file holds the offset at the end,
  so you can re-map `sensor_ns` yourself: `t_us = sensor_ns / 1000 + clockOffsetUs`.
- **Axes.** Device coordinates. iOS values are converted from g and
  sign-flipped to Android's convention: a phone lying face up reads z ≈ +9.81.
- Native code: `android/.../RawSensorChannels.kt`, `ios/Runner/AppDelegate.swift`
  (`RawAccelStreamHandler`).
- Dart: `lib/core/services/raw_sensors/raw_accelerometer_service.dart`.

The legacy 50 Hz `sensors_plus` vibration envelope used by the legacy detector is
still logged in `events.jsonl` as `vibe` events.

## events.jsonl

One JSON object per line:

```
{"tMs": <ms since session start>, "epochMs": <detection clock ms>, "kind": "<kind>", "data": {...}}
```

This is the session event file (`SessionEventRecorder`), copied into the folder.

| kind | what |
|---|---|
| `session_start` | config snapshot, OS |
| `calibration` | pre-check calibration: floor stats and every 10 ms block level `[ms, dB]` |
| `audio` | every 10 ms level block (`db`, `clipped`, `chunk`, `lagMs`) |
| `vibe` | legacy vibration envelope sample |
| `touch` | pointer-down on the session screen |
| `settings` / `config_change` / `ui` | sheet open/close, setting changes, app lifecycle, camera ready/failed, raw recording on/off |
| `cam` | per-frame pose result (score, FSM state, distance ratio) |
| `cam_landmarks` | **raw recording only**: every landmark of each analysed frame (see below) |
| `cam_invalid` | frame rejected by the person / distance rules |
| `decision` | every impact decision with its inputs: audio peak / baseline / rise / target, vibration window peak, camera state, ms since a valid person was seen, decided-after and processing lag |
| `punch` | counted punch |
| `session_end` | totals (counters and min/avg/max stats) |

Each `cam_landmarks` entry:

- `arrivalMs`: when the frame reached Dart. The entry is stamped with this time.
- `doneMs`: when ML Kit finished.
- `w`, `h`, `rotation`, `front`: image size, rotation and camera.
- `lm`: a list of `[landmarkTypeIndex, x, y, z, likelihood]`. Coordinates are in
  image pixels; type indices follow ML Kit's `PoseLandmarkType` order.

## session_meta.json

- `formatVersion`: currently `1`.
- `sessionStartMs`, `sessionEndMs`, `sessionType`, `timeBase`.
- `device`: from the native channel.
  - Android: manufacturer, model, device, osVersion, sdkInt.
  - iOS: machine id such as `iPhone15,2`, osVersion.
- `os`, `osVersion`: the Dart view of the OS.
- `mountType`, `detectionMode`, `engine`, `flags`: every detection and
  experiment flag.
- `audio`:
  - `captureSampleRate`, `wavSampleRate`, `captureSamples`, `wavSamples`,
    `durationS`, `chunks`.
  - `medianChunkIntervalMs`, `firstSampleUs`, `syncPoints`.
  - `mappingCaptureTimeline`, `mappingWav`.
  - `measuredRateHz`: the capture rate **measured** against the detection clock.
  - `service`: chunk size, source and the result of each start attempt.
- `accel`:
  - `samplesWritten`, `medianIntervalMs`, `rateFromMedianHz`.
  - `service`: native sensor info, `achievedRateHz`, `clockOffsetUs`,
    `medianExtraLatencyUs`.
- `camera`: `requestedFps`, `framesDelivered`, `framesAnalyzed`, `deliveredFps`,
  `analyzedFps` (measured), image size, lens.
- `sessionTotals`: all counters and stats, including the legacy vibration
  stream interval.
- `recorderErrors`: should be empty.

## Size

About 32 KB/s of audio plus about 6 KB/s of accelerometer data, roughly 2–2.5 MB
per minute. Landmark events add about 1 MB per minute at 15 fps.

## Known limits

- **Restarting the microphone** mid-session (mic experiment toggles) leaves a gap
  in the capture that the sample counter does not see. The sync points still
  show it, but one straight-line mapping across the gap is wrong. Use the sync
  points piecewise, or avoid toggling mic experiments while recording.
- **Sharing too soon:** if you tap SHARE RAW DATA within a fraction of a second
  of the session ending, the WAV header may not be patched yet. Tools that
  ignore the size fields still read it.

## fusionV2 additions (Phase 4)

When the fusionV2 engine runs, `events.jsonl` also contains:

| kind | what |
|---|---|
| `decision` with `path: FUSION_V2` | every fusionV2 decision: `onsetUs`, `decidedUs`, `latencyMs`, `accepted`, `p`, `pRaw`, `path` (fast / low / direct / waited / hard), `reason`, `mode`, `hand`, every feature, the context factors, `calibrating`, `receivedMs` |
| `arm_motion` | output of the optical-flow prior per analysed frame (`flow`, `div`, left/right values, `pose`, `activity`, `hand`, `computeMs`, `mode`). The replay harness feeds these back as arm activity. |
| `latency` | per counted punch: `onsetMs`, `decidedMs`, `receivedMs`, `renderedMs`, `coreMs`, `e2eMs` |
| `quick_calibration` | result of the optional 10 s calibration |
| `audio_service` with `mode: fusionV2_native` | native capture info (buffer size, source, read period) and the clock offset |

In fusionV2 the raw WAV is recorded from the native low-latency capture. On iOS
it is captured at the hardware rate and resampled to 16 kHz, as before.
`session_meta.json` gets `engine: fusionV2` and `fusionLatency` (median and p95
of the end-to-end and core latency).
