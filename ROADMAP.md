# Product Redesign Roadmap

Single place to track the redesign. Update it after every task.
Status values: `DONE` · `IN PROGRESS` · `PENDING` · `BLOCKED`

**Current phase:** Phase 5 — Monetization (`IN PROGRESS`): usage counting and the paywall screen are done; limit enforcement and RevenueCat are next. Phase 4 needs a device test; Phases 2 and 3 are device-tested.

---

## 1. Goal

Ship a store-ready, premium-feeling punch-training app under a **new brand**:

- Ember Black theme
- 2–3 taps from Home to a live session
- Rich animation
- Free tier with a daily punch limit. Unlimited via a monthly/yearly subscription or a one-time lifetime purchase.

### Principles
1. **2-tap start.** Free ≤ 2 taps and Prompt ≤ 3 taps from Home to a live session.
2. **No jargon for normal users.** dB, ARM, fusion, thresholds and telemetry appear only in Developer mode.
3. **Detection logic is untouched.** The new UI binds only to existing controller observables and methods:
   - Observables: `punchCount`, `promptText`, `formattedElapsedTime`, `liveDecibelLevel`, `detectionStatusText`
   - Methods: `finishSession()`, `resetPunchCount()`, `showAudioSettingsSheet()`, `autoConfigureSettings()`
4. **Every screen animates.** Staggered entrance, press-scale on tap targets, haptics on punches.
5. **Works offline.** Fonts are bundled, and the purchase entitlement is cached.

---

## 2. Decisions log

| Date | Decision |
|---|---|
| 2026-11-17 | Theme: **Ember Black** (charcoal + ember orange-red + gold) |
| 2026-11-17 | Brand: **KnockUp**. App Store: "KnockUp: Learn Boxing". Google Play: "KnockUp - Learn Boxing". Tagline: **"Learn Boxing. Build Confidence."** |
| 2026-11-17 | Home-screen label is **KnockUp** on both platforms. The longer names are set in the store consoles only. |
| 2026-11-17 | **Room check runs before every session** (no reuse for the day: a new room must never be judged by an old check). It overlaps the photo and the 3-2-1, so it adds ~0–1 s. Saved check = backup only. |
| 2026-11-17 | Free daily limit **300 punches**. Display fallback prices: **\$4.99/mo · \$29.99/yr (7-day trial) · \$59.99 lifetime**. Live prices come from RevenueCat later. |
| 2026-11-17 | Store, RevenueCat and console setup is done by the owner later. All mobile-side work proceeds now. |
| 2026-11-17 | Monetization: **free tier (N punches/day)** + **Monthly / Yearly (trial) / Lifetime** via RevenueCat, entitlement `pro` |
| 2026-11-17 | Advanced detection settings: **hidden behind Developer mode** (tap the version label 7× in Settings) |

---

## 3. Open inputs needed from owner

| Item | Status |
|---|---|
| Final app name | DONE (KnockUp) |
| Logo / icon artwork. Placeholder in use: the code-drawn mark rendered to `assets/brand/*.png` (launcher icon + native splash). Swap the PNGs when real artwork exists. | PLACEHOLDER |
| App ids | Android: DONE (`com.finalview.knockup`). iOS: **owner-managed**, currently `com.daman.punch-detection-demo` for testing. Do not change it from code (see §9). |
| Free daily punch limit | DONE (300) |
| Prices: monthly / yearly / lifetime | DONE (fallbacks; final prices are set in the stores) |
| RevenueCat account + App Store Connect / Play Console products | BLOCKED |
| Privacy policy + Terms URLs (camera & mic usage) | BLOCKED |

### 3.1 Store-listing gap (important)
The approved listing promises **"Learn boxing from scratch"**: fundamentals, jab/cross/hook/uppercut technique, stance and movement, structured sessions, and combinations. The app today only **counts punches**.
- Apple review (Guideline 2.3.1, accurate metadata) can reject a listing that describes features the app doesn't have.
- **Phase 7 — Learn content** has been added to fill this gap before submission.
- The other option is to trim the description to what ships.

---

## 4. Current-state analysis (baseline, 2026-11-17)

### 4.1 Taps to reach a session today
Portrait, Fusion mode, permissions already granted.

| Path | Screens | Taps |
|---|---|---|
| Free | Splash (2 s) → Home → Pre-Check: Mode → Reference Photo → Confirm Camera → Calibrate 5 s → Session | **6** |
| Prompt | Splash → Home → Workout Setup (difficulty) → same 4 Pre-Check steps → Session | **7** |
| Missing permissions | + permission step, OS dialogs, and a second Continue | +2–3 |

### 4.2 UX problems

**Pre-session**
- Mode selection shows 5 cards. 4 of them are labeled "only for testing".
- "Confirm Camera" is a static card with no preview, so it is a wasted tap.
- The photo and the 5 s calibration are 2 separate waits, repeated every session.
- Pre-check `onInit` resets all detection settings to defaults every time.
- Workout Setup is a full screen for one optional 3-way choice.
- Onboarding, Mount Guide and Mode Selection pages exist but are unreachable, so there is no real first-run experience.

**In session**
- 5 header controls: back, mode pill, reset, tune, auto-config.
- Tapping the mode pill silently switches the detection mode.
- Reset appears twice.
- The Prompt mode pill uses a `6.ts` font, which is unreadable.
- "MIC ⚙ dB" and "ARM 📊" badges are jargon.
- The detection settings sheet is ~3,000 lines with ~15 controls.
- Colors are hardcoded (`Colors.cyanAccent`, `Colors.purpleAccent`), and `AppColors.lime` is actually cyan.
- Prompt mode is a bare number: no countdown ring, no hit/miss feedback, no streak, and reaction time is always 0.
- The red Finish button is easy to tap by accident.

**Post-session**
- Results show diagnostics ("Signal Fusion Summary", spike log, `.txt` export) instead of a reward.
- **History is never saved.** Nothing calls `SaveWorkoutRecord`, and the datasource is in-memory only.
- The Settings page sliders write to `ConfigService`, which sessions never read, so they have no effect.

**Brand / theme**
- 3 app names: Hyper Hitter (code), PunchDetect (Android), PunchSense (iOS).
- iOS bundle id typo: `punchDetectionDemoo`.
- No icon or splash generators.
- Fonts are fetched at runtime via google_fonts.
- The only animation is `AnimatedPunchCountText`.
- No storage, auth or payments.

---

## 5. Target experience

### 5.1 New flow
- **First launch only:** animated splash → 3-slide onboarding (value · phone placement · permissions) → one-time setup (face photo + room calibration, saved) → Home.
- **Free Fight:** Home → tap **Free Fight** → **Get Ready** (auto 3-2-1) → Session. **1–2 taps.**
- **Reaction Drill:** Home → tap **Reaction Drill** → difficulty chips in a bottom sheet → **Start** → Get Ready → Session. **2–3 taps.**
- **Get Ready screen.** One screen replaces the 4 pre-check steps:
  - Live preview with a body outline.
  - Face capture and the 5 s ambient calibration run **together** during a countdown ring.
  - If today's calibration exists, it offers "Use last setup".
- **Sensitivity:** Low / Medium / High. It maps to the existing `EnvironmentPreset` (High Sens / Balanced / Strict).
- **Developer mode** unlocks: tune sheet, auto-config, mode cycling, MIC/ARM telemetry, `.txt` export, diagnostics.

### 5.2 Session screen
- Full-bleed camera with a vignette.
- Top bar: close · pause · sound.
- Large animated counter and a ring timer.
- On each punch: counter bump, ember ripple, light haptic, punches-per-minute chip.
- **Hold-to-finish** button. Reset lives in the Pause sheet.
- Prompt mode: huge combo number, per-prompt countdown ring, hit/timeout flash, streak counter.
- Landscape: camera on the left, slim glass HUD on the right.

### 5.3 Results / History / Home
- **Results:**
  - Confetti and a count-up of total punches.
  - Stats: punches per minute, duration, best streak, change vs. last session.
  - Shareable image card.
  - "Train again" button.
- **History:**
  - Persisted sessions.
  - Weekly chart, streak calendar, personal bests.
- **Home:**
  - Greeting.
  - Today's punches meter (also the free-tier meter).
  - 2 mode cards.
  - Recent sessions.

### 5.4 Monetization
- **Free tier:** `AppConstants.freeDailyPunchLimit` punches per day.
- **At the limit:** an animated "limit reached" sheet opens the Paywall. Counting stops, and the session is still saved.
- **Paywall:**
  - Plans: Monthly · **Yearly** (Best value, 7-day trial) · **Lifetime**.
  - Restore purchases.
  - Terms and Privacy links.
- **Services:**
  - `SubscriptionService` (RevenueCat, `isPro` Rx, cached).
  - `UsageService` (daily counter, resets at midnight).

### 5.5 Ember Black design tokens

| Token | Value |
|---|---|
| bg | `#0B0B0F` |
| surface | `#16161D` |
| surfaceRaised | `#1F1F28` |
| stroke | `#2A2A35` |
| primary | `#FF4D2E` |
| primaryGradient | `#FF4D2E → #FF8A3D` |
| accent (gold) | `#FFB547` |
| success | `#3DDC97` |
| danger | `#FF3B5C` |
| textPrimary | `#F5F5F7` |
| textSecondary | `#8E8E99` |

**Fonts:** Sora (headings) · Space Grotesk (numerals) · Inter (body). All bundled in `assets/fonts`.

**Animation stack:**
- `flutter_animate` for entrances and staggers.
- `lottie` for confetti and onboarding.
- A custom painter for the punch ripple.
- `HapticFeedback` for touch feedback.

---

## 6. Phase checklist

### Phase 0 — Foundations (`DONE`, except fonts)
- [x] Create `ROADMAP.md` (this file)
- [x] Add deps: `shared_preferences`, `flutter_animate`. `lottie` is added later with the confetti work.
- [ ] Bundle Sora / Space Grotesk / Inter in `assets/google_fonts/` so `google_fonts` stops fetching at runtime. Then set `GoogleFonts.config.allowRuntimeFetching = false`.
- [x] `StorageService` (`lib/core/services/storage_service.dart`): onboarding flag, developer mode, daily punch usage. Initialised in `main()`.
- [x] Brand and monetization constants in `AppConstants`: `appName`, store names, `tagline`, `freeDailyPunchLimit`, fallback prices, `developerModeTapCount`

### Phase 1 — Design system (`DONE`, migration ongoing)
- [x] `app_colors.dart`: Ember Black semantic tokens. The legacy names (`cyan`, `lime`, `panel`…) remap to Ember, so the whole app is re-themed already.
- [x] `app_text_styles.dart`: Sora headings, Space Grotesk `number()`, Inter body. New `display()` style.
- [x] `app_theme.dart`: Material 3 dark with color scheme, sheets, dialogs, sliders, switches and snackbars themed
- [x] Component kit in `lib/core/widgets/ui/`:
  - `PressScale`, `PrimaryButton`, `GhostButton`, `GlassIconButton`
  - `GlassCard`, `AppBackground`, `StatTile`, `MeterBar`, `RingProgress`, `HoldToConfirmButton`
- [x] `KnockUpLogo` / `KnockUpMark` replace `HyperHitterLogo` (deleted)
- [x] Animated splash (flutter_animate)
- [ ] `ChipSelector`, `PunchCounter`: build them with Phases 2 and 3, where they're first used
- [x] Replace hardcoded `Color(0x…)` and `Colors.cyanAccent/purpleAccent` in the session pages, camera panel and lock pill (done in Phase 3). The developer-only sheets still have some.

### Phase 2 — Flow simplification (`DONE`, device-tested 2026-11-17)
- [x] First-run flag. Splash → Onboarding (first run) or Home (`splash_controller.dart`).
- [x] Onboarding redesigned: welcome → phone setup tips → camera/mic access. Sets `onboardingDone`.
- [x] Home redesigned:
  - greeting and today's punch meter (free-tier meter, live once Phase 5 counts usage)
  - Free Fight and Reaction Drill cards
  - "Learn Boxing — SOON" teaser
  - history and settings buttons
- [x] Home: "Recent" strip (last 3 sessions + See all), hidden until the first session is saved.
- [x] **Get Ready screen** (`session_precheck/presentation/pages/get_ready_page.dart`, route `/get-ready`):
  - Replaces the 4 pre-check steps.
  - "I'm ready" → photo countdown → room-noise check runs while the user holds still → 3-2-1 → session.
  - ~~Today's room check is saved and reused~~ → replaced: the room is measured every session (see below).
  - Room check every session, hidden in the flow:
    - starts when the user holds still for the photo;
    - the 3-2-1 starts as soon as the photo is done, and the session opens when the check is also done ("LISTENING…" under the number);
    - a loud moment during the check (max ≥ average + 12 dB, `AppConstants.roomCheckSpikeRetryDb`) → "A bit noisy — stay quiet", measured once more;
    - no microphone samples → the last good check is used instead of the 40 dB fallback;
    - if the punch target ends up at its 90 dB limit, the session shows "Noisy room · punch firmly" for its first 10 s (`SessionArguments.noisyRoom`, screen only).
  - "Skip photo" is available.
  - Uses `SessionPreCheckController(express: true)`. The old step-by-step page is reachable only through Developer mode.
- [x] Reaction Drill pace bottom sheet: Beginner / Intermediate / Advanced, plus a combo number legend (1 jab … 6 rear upper). The pace is remembered. The Workout Setup page is no longer in the flow.
- [x] Sensitivity High / Normal / Low in Settings (`SensitivityLevel` → `EnvironmentPreset`). Normal = the previous engine defaults, exactly.
- [x] Developer mode: tap the version in Settings 7×.
  - Shows: tune and auto-config icons, mode cycling on the session label, MIC/ARM badges, Advanced setup, Diagnostics.
  - All of these are hidden for normal users (`DevOnly` widget).
- [x] Settings page replaced. The old sliders did nothing (`ConfigService` isn't read by sessions).
  - New page: Sensitivity, Replay intro, version, Developer section. ("Forget room check" removed: the room is checked every session.)
- [~] "Stop resetting settings every session": **kept the reset on purpose**. `changeSettingToDefault()` still runs, then the user's Sensitivity is applied on top. This way Developer tweaks never leak into normal sessions.
- **Taps now:** Free = Home → Free Fight → I'm ready (**2**). Prompt = Home → Reaction Drill → Start drill → I'm ready (**3**).

### Phase 3 — Session redesign (`DONE`, device-tested 2026-11-17)
- [x] Shared frame `widgets/hud/session_shell.dart`, used by both pages.
  - Top bar: pause, title, timer (+ sound toggle in the drill).
  - Camera with the HUD over its bottom edge.
  - **Hold to finish** button.
  - The Free and Prompt pages are now ~50 lines each.
- [x] Punch feedback (`hud/punch_ripple.dart`): an ember ring bursts from the camera centre + light haptic on every counted punch. The counter pops and glows.
- [x] Punches-per-minute chip (`PaceChip`, rolling 30 s window, resets with the count).
- [x] Pause sheet (`hud/session_pause_sheet.dart`): Resume / Reset count / End session.
  - Back button opens it too. Before, back ended the Free session and threw away the Prompt session.
  - Punches aren't counted while it's open (existing `notifySettingsViewOpened/Closed` gate).
  - The clock and the drill's voice calls keep running while paused (no pause in the controller).
- [x] Drill (`hud/prompt_call_display.dart`):
  - big number in a ring that runs down until the next call;
  - combo shown underneath with the current step highlighted;
  - green glow when the last call was answered, ember when missed;
  - streak chip ("in a row", gold from 3).
  - Screen-only rule: a call counts as answered when ≥1 punch is counted before the next call.
  - Needed one display-only addition to `PromptSessionController`: `promptTick` (+1 per call), because the same number can be called twice in a row.
- [x] Camera panel restyled:
  - plain-language hint chip ("Step into view", "Move a little closer", "Camera off · counting by sound");
  - photo card and "Tracking you" pill moved to the top;
  - raw detector status (`Candidate Impact (…)`) and MIC/ARM badges in Developer mode only.
- [x] Landscape: camera left, glass side panel right (top bar, HUD, hold to finish). Sensor stats panel only in Developer mode.
- [x] Mode pill, tune and auto-config moved into a Developer-mode row under the top bar.

### Phase 4 — Results & history (`CODED`, needs a device test)
- [x] **Sessions are saved** (`LocalHistoryDatasource`: JSON list in SharedPreferences, key `workout_history_v1`, newest first, max 1000).
  - One app-wide `HistoryRepository` in `InitialBindings`.
  - `WorkoutRecord` gained `sessionType`, `difficulty`, `bestStreak`, `callsAnswered`, `callsMade` (optional, so older saved data still loads).
  - Saved by `ResultsController` when the Results screen opens; sessions with 0 punches are not saved.
  - Today's punch total (`StorageService.todayPunches`, the Home meter) now goes up after each session.
- [x] **Drill score** moved into `PromptSessionController` (`streak`, `bestStreak`, `lastCallAnswered`) and handed to Results as `DrillScore` via the `drillScore` getter. One added line in `FreeSessionController.finishSession` (`drill: drillScore`); detection unchanged.
- [x] **Results page** rewritten:
  - total counts up with a confetti burst (`core/widgets/ui/confetti_burst.dart`);
  - chips: "First session saved!", "New record: most punches", "New best pace" (sessions ≥ 30 s), "New best streak", "+N / −N vs last time" (same mode);
  - stats: Time, Pace (from 10 s), and for drills Best streak + Calls answered;
  - "Today N punches · N-day streak" line;
  - Train again (replaces Results with Get Ready, same mode and pace), Share, Done. Back = Done.
- [x] `.txt` export + spikes log moved to `results/presentation/widgets/results_dev_panel.dart`, shown only in Developer mode. Export file names renamed `knockup_*`.
- [x] **Share card** (`result_share_sheet.dart`): preview sheet with a 320×400 branded card rendered to PNG (~1088×1360) and shared with share_plus.
- [x] **History ("Progress") page** rewritten: sessions / punches / day-streak summary, "This week" chart (`weekly_punch_chart.dart`), personal bests, sessions grouped by day, empty state, clear-history confirm, pull to refresh.
- [x] History detail page shows the real saved session (route argument is the `WorkoutRecord`; `HistoryDetailArguments` deleted).
- [x] Progress maths in `history/domain/history_insights.dart` (last 7 days, day streak, bests, previous session, date labels without `intl`).
- [x] Tests: `test/features/history/history_insights_test.dart`, extra cases in `history_storage_test.dart` (restart, duplicates, old data, corrupt data), `test/features/results/results_page_test.dart` (saves once, chips, landscape overflow, 0 punches).

### Phase 5 — Monetization (`IN PROGRESS`, purchases BLOCKED on accounts)
- [x] `UsageService` (`core/services/usage_service.dart`): today's punches counted **live during the session** and saved on every punch.
  - Killing the app mid-session keeps the punches used (before, they were only added when Results opened).
  - Resetting the count in the pause menu doesn't give punches back.
  - Midnight reset via the stored date. Registered in `InitialBindings`; tracked by the session screen (`SessionShell` → `_UsageTracker`).
  - Fixed: `StorageService.setTodayPunches` now starts both writes together, so rapid punches can't read a stale total.
- [x] Home free-tier meter is live (reads `UsageService.todayPunches`).
- [x] In-session limit (decision 2026-11-17: **stop counting, session continues**). `hud/daily_limit_guard.dart`:
  - at the limit, the session's existing punch gate is held closed (`notifySettingsViewOpened`, the same gate the pause menu uses), so no punch is counted; detection code unchanged;
  - limit sheet: "That's today's N free punches" → **Go unlimited** (paywall), **End session** (Results), **Keep training (not counted)**;
  - HUD chip "Free limit reached · not counting";
  - already used up at session start → stops on the first frame;
  - usage is capped at the limit (a punch in flight is not charged);
  - becoming Pro mid-session (`UsageService.isPro`) reopens the gate.
- [x] Home: starting Free Fight / Reaction Drill with the limit used up opens the paywall instead ("You've used today's N free punches"). Meter label: "N free punches left" / "Free punches used · resets at midnight" / "Unlimited" (Pro).
- [x] Paywall page (`features/paywall/`, route `/paywall`):
  - KnockUp Pro hero, 3 honest benefits (unlimited punches, no mid-session stop, new lessons/drills as they launch);
  - plans: Yearly (selected, "SAVE 50%", 7-day trial, per-month price), Monthly, Lifetime;
  - button text per plan, auto-renew small print, Restore purchases, Terms, Privacy;
  - portrait pins the buy button; landscape scrolls everything.
- [x] Paywall redesigned (2026-11-17) so the plans are visible without scrolling: compact header, one-line benefits, **3 plan tiles side by side** (Monthly · Yearly preselected with "SAVE 50%" and "$2.50 / mo" · Lifetime), one-line price summary, renewal terms, slim pinned buy bar. Landscape: benefits left, plans + buy right. Checked on 390×844, 375×667 and landscape renders.
- [x] Entry points (2026-11-17, owner asked to remove the big Home card): gold **PRO** button in the Home top bar (next to History / Settings), **Go unlimited ›** inside the today card once the free punches are used up, and Settings → KnockUp Pro.
- [x] Home today card: **210 / 300** with a meter (gold when used up), "N punches left today" or "All free punches used · Go unlimited", "Resets at midnight". Pro users: just the count + UNLIMITED.
- [x] Fixed: `MeterBar` fill had 0 height (bar always looked empty).
- [x] Test switches in `AppConstants`: `alwaysShowUpgrade = true` (Pro card always visible), `purchasesConnected = false` (Buy/Restore show "Preview only"), `termsUrl` / `privacyUrl` empty.
- [ ] `SubscriptionService` with `purchases_flutter`, entitlement `pro`, offline cache
- [ ] Sandbox purchase testing on iOS and Android

### Phase 6 — Rebrand & release (`IN PROGRESS`)
- [x] `AppConstants.appName` = KnockUp, Android `android:label`, iOS `CFBundleDisplayName` / `CFBundleName`
- [x] All "Hyper Hitter" / "PunchDetect" / "PunchSense" strings removed from `lib/`, the manifest and Info.plist
- [x] New id **`com.finalview.knockup`**:
  - Android `namespace` + `applicationId`; Kotlin moved to `com/finalview/knockup/`.
  - iOS: **not changed by us.** The owner manages the iOS bundle id in Xcode (currently `com.daman.punch-detection-demo` for testing) and switches it before the App Store upload.
  - Native audio channel renamed `knockup/call_mode_audio` (Dart + Kotlin).
  - The Dart package is still named `punch_detection_demo` (imports only; not visible to users or stores).
- [x] New logo widget (`KnockUpLogo`)
- [x] `flutter_launcher_icons` + `flutter_native_splash` set up (config in `pubspec.yaml`), using placeholder PNGs from `tool/generate_brand_assets_test.dart`.
  - Android adaptive icon (gradient background + glove), iOS icon (no alpha), dark native splash with the ember tile, Android 12 splash.
  - Old `.webp` launcher icons and the unused round icon removed.
- [ ] Real icon artwork: replace `assets/brand/*.png`, then `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`.
- [x] iOS permission prompts rewritten in plain language (camera, microphone, motion, speech).
- [ ] Delete unreachable legacy pages:
  - `permissions_page`, `calibration_page`, `free_mode`, `workout_session`
  - `benchmarking`, `mode_selection`, `mount_guide`
  - the old `settings_page` sliders
- [ ] Release build with `--obfuscate --split-debug-info`
- [ ] Store listing assets (screenshots, description, privacy labels)

### Phase 7 — Learn content (`PENDING`, needed to match the store listing)
- [ ] "Learn" tab on Home: Fundamentals → Stance → Jab → Cross → Hook → Uppercut → Footwork → Combos
- [ ] Lesson page: short text steps, an illustration or looping animation per move, common mistakes, then "Practice this", which starts a drill
- [ ] Guided drills: timed rounds per punch or combo, using the existing prompt engine (spoken cues)
- [ ] Progress: lessons completed, badges. Optionally, Pro locks the advanced lessons.

---

## 7. Verification checklist (run after each phase)
- [ ] `flutter analyze` clean
- [ ] Real Android and iOS device, portrait and landscape
- [ ] Tap count: Free ≤ 2, Prompt ≤ 3 from Home
- [ ] Detection regression: same 30-punch set, count within ±1 of the pre-redesign build
- [ ] History survives an app restart, and the usage counter resets after midnight
- [ ] Sandbox purchases (monthly / yearly / lifetime), restore, limit sheet at N, Pro unlimited offline
- [ ] `grep -ri "hyper hitter\|punchdetect\|punchsense"` returns nothing in the release build

---

## 8. Changelog
- **2026-11-17**: "Reset to 0 (test)" button on Home (switch `showTestUsageReset`). Added `docs/LAUNCH_SETUP.md` (subscriptions, Firebase, connectivity, hosting, release checklist).
- **2026-11-17**: Home: today card shows used / limit, Pro card replaced by a PRO button in the top bar + in-card "Go unlimited" at the limit, MeterBar fill fixed, logo shrinks first on tight top bars.
- **2026-11-17**: Paywall redesigned (plans visible without scrolling). Fixed oversized text in landscape on all new screens (`.sp` → `.fs` / context styles). Stat units spacing, shorter stat labels, Progress list newest-first without repeated dates. Screenshot tool added. `flutter test`: 400 pass, the same 2 old detection failures.
- **2026-11-17**: Daily limit enforced: counting stops at the limit (session continues), limit sheet, HUD chip, paywall from Home when used up, Pro resume hook. Limit = one constant. `flutter test`: 397 pass, the same 2 old detection failures.
- **2026-11-17**: Usage counted live per punch (kill-safe); paywall screen + Home/Settings entry points (always visible for testing, purchases in preview mode); weekly chart 1px overflow fixed. `flutter test`: 391 pass, the same 2 old detection failures.
- **2026-11-17**: Phase 4 coded: sessions saved, new Results (confetti, records, vs last time, share card), Progress page (week chart, bests, list), Home recent strip, drill score in results. `flutter analyze`: 0 new issues. `flutter test`: 381 pass, the same 2 old detection failures.
- **2026-11-17**: Owner tested Phases 2 and 3 on device: working. Android app id set to `com.finalview.knockup` (iOS id stays owner-managed, currently `com.daman.punch-detection-demo`). Placeholder launcher icon and native splash generated. Debug APK builds as `com.finalview.knockup` / "KnockUp".
- **2026-11-17**: Room check changed to every session, overlapped with the photo and 3-2-1; one automatic re-check on a noisy moment; noisy-room hint in the session. "Use today's check" row and "Forget room check" setting removed. `flutter analyze` shows 0 new issues; smoke test passes.
- **2026-11-17**: Phase 3 coded: new session screens (shared shell, punch ripple + haptics, pace chip, pause sheet, hold to finish, drill call ring + streak, restyled camera overlays, landscape glass panel). `flutter analyze` shows 0 new issues. 2 detection tests (`body_motion_gate_test`, `camera_person_check_test`) fail, and fail the same way on the last commit, so they were already broken.
- **2026-11-17**: Baseline analysis done; plan approved; `ROADMAP.md` created.
- **2026-11-17**: Phase 2 coded: onboarding, Home, Get Ready, drill sheet, Settings, Developer mode gating. `flutter analyze` shows 0 new issues; widget smoke test passes.
- **2026-11-17**: Brand set to KnockUp. Phase 0 and 1 delivered: Ember Black theme applied app-wide, UI kit, storage service, animated splash, platform display names. `flutter analyze` shows 0 errors; the 6 remaining warnings were already there.

---

## 9. Commands & how-to

Run every command from the project root.

### App ids
| Platform | Id | Where | Who changes it |
|---|---|---|---|
| Android | `com.finalview.knockup` | `android/app/build.gradle.kts` (`namespace`, `applicationId`), Kotlin package `android/app/src/main/kotlin/com/finalview/knockup/` | Code |
| iOS | `com.daman.punch-detection-demo` (testing) | Xcode → Runner → Signing & Capabilities (`PRODUCT_BUNDLE_IDENTIFIER`) | **Owner only.** Never change it from code or scripts. |

Note: the iOS `RunnerTests` target still says `com.finalview.knockup.RunnerTests`; it isn't part of the app. The owner can change it in Xcode if wanted.

### App icon & native splash (after new artwork)
1. Put the artwork in `assets/brand/` (all 1024×1024 PNG):
   - `app_icon.png`: full square, **no transparency, no rounded corners** (iOS + legacy Android; the OS rounds it).
   - `app_icon_foreground.png`: the symbol only, transparent background, kept inside the middle ~66% (Android adaptive icon + Android 12 splash).
   - `app_icon_background.png`: background layer for the Android adaptive icon.
   - `splash_logo.png`: logo on a transparent background for the native splash.
2. Generate:
   ```
   dart run flutter_launcher_icons
   dart run flutter_native_splash:create
   ```
3. Check that the iOS bundle id was not touched: `git diff ios/Runner.xcodeproj/project.pbxproj` should not show `PRODUCT_BUNDLE_IDENTIFIER` changes.
4. Uninstall the app from the phone, then run it again (launchers cache icons).

Settings for both generators live in `pubspec.yaml` (`flutter_launcher_icons:` and `flutter_native_splash:`). Splash colours: background `#0B0B0F`, Android 12 icon background `#FF4D2E`.

To re-make the **placeholder** images from the code-drawn mark (only while there is no real artwork):
```
flutter test tool/generate_brand_assets_test.dart
```
then run step 2.

### Everyday checks
```
flutter analyze                    # expect only the 6 old issues (dead code, avoid_print)
flutter test test/widget_test.dart # smoke test
flutter test                       # all tests; 2 detection tests were already failing before the redesign
```
Format only the files you edited (`dart format <file>`). Never run `dart format lib/...` on whole folders: it reformats ~100 unrelated files.

### Builds
```
flutter build apk --debug                 # Android debug
flutter build ios --debug --no-codesign   # iOS compile check (signing is set in Xcode)
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols   # Play Store
flutter build ipa --release --obfuscate --split-debug-info=build/symbols         # App Store
```
Keep `build/symbols/` from each release; it is needed to read crash stack traces.

### Launch setup (subscriptions, Firebase, hosting)
Step-by-step guide: **[docs/LAUNCH_SETUP.md](docs/LAUNCH_SETUP.md)**. It covers RevenueCat + App Store + Google Play products, Firebase Crashlytics / Analytics / events, connectivity, Privacy Policy & Terms on Firebase Hosting, and the release checklist.

### Reset today's punch count (testing)
With `showTestUsageReset = true`, the Home today card shows **Reset to 0 (test)**. Set it to `false` before release.

### Change the free daily punch limit
Edit **one number** in `lib/core/utils/constants.dart`:
```dart
static const int freeDailyPunchLimit = 300; // e.g. 200 or 500
```
Every screen reads it (Home meter, session limit sheet, paywall text). To turn the limit off completely, set `enforceDailyLimit = false`. Then run the app again (a hot restart is enough; it's a `const`).

### Before release: monetization switches (`lib/core/utils/constants.dart`)
| Constant | Testing | Release |
|---|---|---|
| `alwaysShowUpgrade` | `true`: Pro card always on Home | `false`: Pro card only when today's free punches are used up (Settings row stays) |
| `purchasesConnected` | `false`: Buy / Restore say "Preview only" | `true` once RevenueCat + store products work |
| `termsUrl`, `privacyUrl` | empty | real URLs (required by the App Store for subscriptions) |
| `freeDailyPunchLimit` | 300 | 300 (or your choice) |
| `enforceDailyLimit` | `true` | `true` (`false` = nobody is ever stopped) |
| `showTestUsageReset` | `true` ("Reset to 0 (test)" on the Home today card) | **`false`** |

### Text sizes (landscape)
`.sp` scales with screen **width**, so in landscape it is ~2.2× too big. Use `AppTextStyles.x(context)` / `.ts(context)` (with a context) or `.fs` (no context; same correction, `core/utils/size_box.dart`). `AppTextStyles.x()` without a context uses `.fs`. Don't add new plain `.sp` font sizes.

### Screenshots of the new screens (no device needed)
```
flutter test tool/render_screens_test.dart --dart-define=OUT=build/screens
```
Writes PNGs of Paywall, Results, Progress and Home in portrait, small phone and landscape to `build/screens/` (macOS only: uses Arial in place of the Google fonts). Fails if a screen throws or overflows. The iOS simulator can't run this app on Apple-silicon Macs (ML Kit has no arm64 simulator build), so this is the quick visual check.

### Developer mode (on a device)
Settings → tap the version label 7 times. It shows the advanced detection controls, Diagnostics and the old step-by-step setup.

