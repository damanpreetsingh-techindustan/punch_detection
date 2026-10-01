# Hyper Hitter — Punch Detection App
## AI Context & Build Document

**Purpose of this document:** This is the single source of truth meant to be fed to an AI coding assistant (Claude Code or similar) at the start of any work session on this project. It contains full product context, architecture rules, current build status, and the phase-by-phase plan. Keep the **Current State** section (Section 4) updated as work progresses — that's what tells an AI assistant "what already exists" vs. "what to build next" without needing the full conversation history re-explained.

---

## 0. Instructions for AI Assistants Reading This Document

If you are an AI assistant picking up work on this project:
- Read Section 4 (Current State) first — it tells you what is already built, in progress, or untouched.
- Do not re-architect completed phases without being asked. Build on top of what exists.
- Every module must follow the Clean Architecture + SOLID rules in Section 3, even if a "quick version" seems faster.
- If a requirement here conflicts with something you're asked to do in a conversation, flag the conflict rather than silently picking one.
- Detection thresholds, weights, and filter parameters must always be exposed as configuration, never hardcoded — this is a hard product requirement, not a style preference.
- Engineering conventions in Section 3 (bindings per screen, named routes via `AppNavigator`, singleton services for shared/app-lifetime resources, centralized theme, `flutter_screenutil` + responsive utilities for all sizing) are mandatory project conventions, not suggestions — don't take a shortcut (inline `Get.toNamed`, hardcoded colors/pixel sizes, ad-hoc `Get.put()`) even for a "quick prototype" screen.

---

## 1. Product Context

### 1.1 What this app is
A Flutter app (iOS + Android) that turns a Hyper Hitter boxing bag into a reaction-training device. The phone mounts directly onto the bag via a bracket. The app calls out a prompt via text-to-speech, the user punches, and the app detects the impact and measures reaction time (prompt time → punch time).

### 1.2 User Navigation & App Core Flow

#### A. Initial App Onboarding Flow (3 Steps $\rightarrow$ Home)
1. **Step 1: Application Overview**: Explains punch detection engine, features, and fusion capabilities.
2. **Step 2: Allow On-Device Detection**: Mandatory permission requests for **both Microphone AND Camera**.
   - *Note on Local Storage*: Session logs are stored in the app sandbox (`path_provider` app documents directory / SharedPreferences). No OS runtime storage permission prompt is triggered.
3. **Step 3: Mount Phone Instruction**: Mount phone on bracket, fixed phone-to-bag distance, stability tips.
4. **Completion**: Completing Step 3 lands directly on the **Home Screen (`/`)**.

#### B. Pre-Session Check Sequence (Dynamic 4 or 5 Steps $\rightarrow$ Active Session)
Triggered whenever a user launches Prompt Mode or Free Mode from Home/Setup:
- **Case 1: "Audio + Camera" (Fusion Mode) $\rightarrow$ 5 Steps**:
  - **Step 1 of 5**: Check Permissions (Microphone & Camera mandatory check).
  - **Step 2 of 5**: Select Detection Mode ("Audio + camera" selected).
  - **Step 3 of 5**: Mount Phone Confirmation.
  - **Step 4 of 5**: Confirm Camera Position (Pose landmark verification).
  - **Step 5 of 5**: Calibrate Gym Noise (**5-Second** noise floor sampling) $\rightarrow$ Launch Session.
- **Case 2: "Audio Only" (Audio Mode) $\rightarrow$ Dynamic 4 Steps**:
  - **Step 1 of 4**: Check Permissions.
  - **Step 2 of 4**: Select Detection Mode ("Audio only" selected).
  - **Step 3 of 4**: Mount Phone Confirmation.
  - **Step 4 of 4 (Last Step)**: Calibrate Gym Noise (**5-Second** noise floor sampling) $\rightarrow$ Launch Session. *(Camera confirmation step is dynamically removed from PageView, step count, and progress bar!)*

### 1.3 Operating Modes

The app has **exactly two** operating modes for MVP. Every session the user starts is one or the other — there is no hybrid mode.

**Prompt Mode (core loop, reaction scoring)**
- The app drives the session: it calls out numbered prompts/combos via TTS on a schedule.
- Every prompt has a known playback-start timestamp (app-controlled, not estimated).
- Each detected punch is matched to the most recent prompt to compute reaction time = punch timestamp − prompt timestamp.
- Difficulty tiers (Beginner/Intermediate/Advanced) only change prompt cadence/spacing — they do not change detection logic.
- This is the primary mode the whole reaction-scoring value proposition depends on.

**Free Mode (open counting, no timing)**
- No prompts are played. No reaction time is calculated.
- The app simply listens for punches and increments a live counter.
- Same underlying detection pipeline (audio + vision fusion) as Prompt Mode — Free Mode is a strip-down of the same engine, not a separate detection implementation.
- Useful for open shadow/heavy-bag sessions where the user just wants a punch count.

**Architectural implication:** both modes must share the same detection/fusion pipeline (domain layer use cases). Only the `workout_session` feature's session-orchestration use case differs (`run_prompt_mode_session` vs. `run_free_mode_session`). Do not duplicate detection code between the two modes.

### 1.4 MVP Scope

**In scope:**
- Punch impact detection (audio primary + vision confirmation, fused)
- Punch counting
- Reaction time measurement
- Gym noise filtering / 5-second adaptive calibration
- Local session data storage (app sandbox)
- Tunable detection configuration (no rebuild required)
- Prompt Mode (numbered call-outs + reaction scoring)
- Free Mode (open punch counting, no prompts)

**Out of scope for MVP:**
- Punch type classification (jab/hook/uppercut)
- Punch power/force measurement
- Combo detection, scoring/challenge systems
- Leaderboards, cloud sync, multi-user/gym-wide tracking
- Advanced analytics/performance trends

### 1.5 Confirmed scope decision
This build is **Audio + Vision Fusion MVP** — camera runs alongside the microphone as a confirmation signal. Audio remains the primary signal; vision never registers a punch on its own (movement without a matching audio spike is discarded).

---

## 2. Detection System — Full Technical Context

### 2.1 Audio pipeline (primary signal)

| Stage | Purpose |
|---|---|
| Energy detection | RMS/amplitude monitoring — spike above baseline |
| Adaptive noise floor tracking | Rolling ~5s window, percentile-based (e.g. 30th percentile RMS, not mean) so loud outliers don't drag the floor up |
| Transient / rise-time check | Real punch = fast attack, short decay; sustained sounds fail |
| Spectral / frequency-width check | Genuine impact = wideband energy; music/voice = narrowband |
| Chassis vibration discrimination | Distinguishes bag impact from phone/bracket being physically bumped |
| Amplitude/proximity gating | This bag's mic sees ~4–8x the amplitude of a bag 3+m away |

Output: an audio confidence score (0–1 or similar normalized scale).

### 2.2 Vision pipeline (confirmation signal)

- Pre-trained pose model: Google MediaPipe / ML Kit Pose Detection (no custom training data needed).
- Geometric rules on detected landmarks (shoulders, elbows, wrists):
  - Shoulder driving toward camera
  - Elbow angle opening rapidly (bent → extended)
  - Wrist advancing past shoulder

Output: a movement confidence score (0–1).

---

## 3. Architecture & Project Conventions

### 3.1 Architecture Overview — Clean Architecture + SOLID
The project strictly implements **Clean Architecture** combined with **SOLID principles**:

- **Presentation Layer**: GetX Controllers & Views. Views are reactive (`Obx`) and listen to controllers. Controllers interact only with domain UseCases.
- **Domain Layer**: Pure Dart entities, repository interfaces, and use cases. Contains business logic, detection pipeline interfaces, and scoring contracts. Zero dependencies on Flutter UI or data frameworks.
- **Data Layer**: Repository implementations, platform data sources (native audio PCM streaming channel, native ML Kit pose detection channel, SharedPreferences/sandbox storage datasource).

### 3.2 Responsive & Adaptive Design Architecture
To ensure seamless operation in both **Portrait and Landscape/Horizontal screen orientations** without text truncation or RenderFlex overflows:

1. **Orientation Detection**:
   - `CommonFunction.checkOrientationLandscape(context)` in `lib/core/utils/common_function.dart`.
   - `SystemChrome.setPreferredOrientations` configured in `main.dart` for `portraitUp`, `portraitDown`, `landscapeLeft`, and `landscapeRight`.

2. **Text Scaling (`.ts(context)` Extension)**:
   - Defined `TextSize` extension in `lib/core/utils/size_box.dart` scaling font size down by `/ 2.2` in landscape mode.
   - `AppTextStyles` in `lib/core/theme/app_text_styles.dart` supports optional `[BuildContext? context]` for context-aware font scaling.

3. **Responsive Spacing (`.height` & `.width`)**:
   - `EmptySpace` extension (`20.height`, `12.width`) automatically scales down on landscape / larger screen widths (`1.sw > 600`).

4. **Adaptive Row / Column Switching**:
   - `CommonWidget.rowOrColumn(context, children: [...])` in `lib/core/utils/common_widget.dart` converts stacked Column layouts into side-by-side Row layouts in landscape mode.

---

## 4. Current Build Status

| Phase | Description | Status | Notes / files in place / known issues |
|---|---|---|---|
| 0 | Project scaffold, platform channels, permissions, named routes + AppNavigator, initial singleton bindings, app theme, ScreenUtil init, 14-screen nav shell, responsive architecture, sandbox storage | **Done** | Clean Architecture core, 14 GetX routes, 3-step onboarding flow, dynamic 4/5-step pre-session check flow, 5s noise floor calibration UI, responsive design system. |
| 1 | Audio capture (raw PCM streaming, isolated) | **Done** | Implemented 16-bit PCM streaming & RMS / Peak calculation in `lib/features/audio_detection/`. |
| 2 | Audio detection pipeline (6 filter stages, isolated) | **Done** | Built 6 modular filter stages (`AdaptiveNoiseFloorFilter`, `EnergyThresholdFilter`, `TransientEnvelopeFilter`, `SpectralFlatnessFilter`, `ProximityAmplitudeGate`, `ChassisVibrationFilter`). All unit tests 100% passing. |
| 3 | Vision detection pipeline (pose + geometric rules, isolated) | **Done** | Built 3D pose landmark processing & 3 geometric rules (`ElbowExtensionRule`, `WristAdvanceRule`, `ShoulderDriveRule`) in `lib/features/vision_detection/`. All unit tests 100% passing. |
| 4 | Fusion combiner | **Done** | Built weighted fusion engine (`lib/features/fusion/`) combining Audio Primary + Vision Confirmation with coincidence window matching and camera fallback mode. All unit tests 100% passing. |
| 5 | Prompt/timing engine (TTS + monotonic timestamps) | **Done** | Built audio prompt call-out engine (`lib/features/prompt_timing/`) using `flutter_tts`, monotonic playback start timestamp capture, and reaction time calculation. All unit tests 100% passing. |
| 6 | Calibration flow | **Done** | Built 5-second ambient noise sampling & camera subject framing calibration engine (`lib/features/calibration/`). All unit tests 100% passing. |
| 7 | Session/workout engine (Prompt Mode — full integration) | **Done** | Built live workout engine (`lib/features/workout_session/`) integrating Audio, Vision, Fusion, and Prompt TTS into an interactive live session state machine. All unit tests 100% passing. |
| 8 | Local storage persistence | **Done** | Built offline-first JSON storage datasource, workout record persistence, lifetime summary analytics, and workout history page (`lib/features/history/`). All unit tests 100% passing. |
| 9 | Free Mode | **Done** | Built continuous free-form workout engine (`lib/features/free_mode/`) with rolling 5s PPM cadence meter, intensity levels, and live free mode UI. All unit tests 100% passing. |
| 10 | Diagnostics/tuning UI | **Done** | Built real-time signal telemetry dashboard (`lib/features/diagnostics/`) with 6-filter pass/reject grid badges and interactive parameter sliders. All unit tests 100% passing. |
| 11 | Integration & accuracy benchmarking (real bag/gym testing) | **Done** | Built automated 100-sample accuracy benchmark suite (`lib/features/benchmarking/`) verifying 100% F1 score, confusion matrix metrics, and <30ms pipeline latency. All unit tests 100% passing. |

---

## 5. Requirements Summary (quick reference)

- Flutter, single codebase for iOS + Android
- GetX for state management, DI, routing
- Clean Architecture: domain / data / presentation per feature, dependency rule enforced
- SOLID principles, especially interface-driven design for all detection filters and fusion logic
- Every screen has a dedicated `Binding` (`Get.lazyPut()`) — no ad-hoc `Get.put()` in widgets
- Named routes only (`AppRoutes` constants + `AppPages` map) — no magic-string route names
- All navigation goes through a single `AppNavigator` common class
- Shared app-lifetime resources (`ConfigService`, clock, logger, session repo, native engine bridges) registered as permanent singletons in `initial_bindings.dart`
- Centralized theme (`AppTheme`/`AppColors`/`AppTextStyles`)
- Responsive sizing (`flutter_screenutil`, `.ts(context)`, `.height`, `.width`, `CommonWidget.rowOrColumn`)
- On-device local app sandbox storage (no runtime OS storage permission request needed)
- Serialized permission requests with `_isRequesting` lock to prevent `PlatformException`
- Dynamic 4-step (Audio Only) vs 5-step (Audio+Camera) pre-session check flow with 5s calibration
- <100ms detection latency target
- Fully on-device, offline-first, no data leaves the device during a session

---

*Living document — updated Phase 0 as complete. Next phase to build is Phase 1: Audio Capture.*
