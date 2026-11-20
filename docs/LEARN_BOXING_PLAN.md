# Learn Boxing — Plan & Tracking

Status: **v1 BUILT**, needs a device test. Tracked in `ROADMAP.md` → Phase 7.

## 1. Why
- The store listing promises "Learn boxing from scratch": stance, jab, cross, hook, uppercut, combinations. Apple can reject a listing that promises features the app doesn't have (ROADMAP §3.1).
- KnockUp's edge over plain lesson apps: every lesson ends with a **practice round on the bag that the app counts**.

## 2. Decisions (2026-11-18)
| Topic | Decision |
|---|---|
| Visuals | **Animated figure drawn in the app** (no coach or designer yet). A lesson can get a `video` later without code changes. |
| Audience | **Total beginners, fitness boxing** (owner: "yes right"; change the tone in the JSON if this was meant otherwise). Friendly, simple wording. Defense is taught as movement, not sparring. |
| Wording | Written from standard boxing fundamentals (no coach review yet). Worth having a coach read it before launch. |
| Safety | A one-time "Train safely" screen before the first lesson: warm up, wrap hands, clear space, stop on pain, not medical advice. |
| Free / Pro | Suggestion: lessons 1–3 free, 4–10 Pro. Flag `proOnly` in the JSON; locking **off** (`lockProLessons = false`) until decided. |

## 3. The course: "Boxing Basics" (10 lessons, about 5 minutes each)
| # | Lesson | Figure animation | Practice |
|---|---|---|---|
| 1 | Stance & guard | Stance, light bounce | Follow along 45 s: voice cues "Hands up", "Chin down"… |
| 2 | Footwork | Step in / step out | Follow along 60 s: "Step forward", "Step back"… |
| 3 | The jab (1) | Jab | Bag drill: 1, 1-1 · 2 × 45 s |
| 4 | The cross (2) | Cross | Bag drill: 2, 1-2 · 2 × 45 s |
| 5 | The 1-2 | Jab then cross | Bag drill: 1-2 · 2 × 45 s |
| 6 | Lead hook (3) | Lead hook | Bag drill: 3, 1-3 |
| 7 | Rear hook (4) | Rear hook | Bag drill: 4, 3-4 |
| 8 | Uppercuts (5, 6) | Lead then rear uppercut | Bag drill: 5, 6, 5-6 |
| 9 | Defense basics | Block, slip, roll | Follow along 60 s: "Block", "Slip", "Roll" |
| 10 | Put it together | 1-2-3 | Bag drill: mixed combos, 3 × 60 s |

## 4. Lesson screen
1. **Animated figure** (side view, mirrors for southpaw). Loops the move, with a glove trail for hooks and uppercuts, a 1× / ½× speed switch, and pause.
2. **Key point:** one sentence to remember.
3. **How to do it:** 3–4 numbered steps.
4. **Common mistakes:** ✕ mistake → ✓ fix.
5. **Practice:**
   - **Bag drill**: opens Get Ready with the lesson's drill (numbers light up on the bag). The lesson is completed when that session ends with at least `minPunches` punches; Results shows "Lesson N complete".
   - **Follow along**: a timer on the lesson page with spoken cues. The lesson is completed when the timer ends.
6. Landscape: figure on the left, text on the right.

## 5. How it's built (same pattern as drills)
| Piece | File |
|---|---|
| Course content (no code to edit lessons) | `assets/learn/basics.json` |
| Model + validation | `lib/features/learn/domain/lesson.dart` |
| Figure poses & moves | `lib/features/learn/domain/boxer_moves.dart` |
| Figure painter | `lib/features/learn/presentation/widgets/boxer_figure.dart` |
| Progress, safety flag, lesson ↔ drill link | `lib/features/learn/data/learn_service.dart` |
| Course page, lesson page, safety sheet | `lib/features/learn/presentation/…` |
| Results "Lesson complete" | `ResultsController` (reads the active drill id `lesson_<id>`) |

## 6. Later (v2+)
- **Form check:** live cues from the camera's pose ("Hands up!" when the guard drops, "Chin down"). New code that only *reads* the pose; detection unchanged.
- More courses (Southpaw basics, Combos 2, Body work) as JSON files, optionally from Firebase.
- Coach videos per lesson (`video` field).
- Badges: "First lesson", "Basics complete".

## 7. Tracking
- [x] Plan (this file)
- [x] Course JSON (10 lessons) + model + validation + tests
- [x] Animated figure: 14 joints, side view, southpaw mirror, glove trail, ½× speed, pause; 10 moves; poses checked in renders
- [x] Learn service: progress saved on the phone, safety flag, lesson ↔ practice drill link (`lesson_<id>`)
- [x] Course page (progress, Continue, lesson list with ✓ / next / PRO) and lesson page, portrait + landscape
- [x] Follow-along practice (timer + spoken cues) for stance, footwork, defense
- [x] Safety sheet before the first lesson (once)
- [x] Home "Learn Boxing" card opens the course and shows "START" or "3/10"
- [x] Results: "Lesson N complete" chip when the practice drill had enough punches
- [x] Tests (`test/features/learn/`), screenshots (`tool/render_screens_test.dart`: learn, lesson, safety sheet)
- [ ] Device test (figure smoothness, voice cues, a full lesson → practice → Results loop)
- [ ] Coach read-through of the lesson text (recommended before launch)
- [ ] v2: form check ("Hands up!") from the camera pose

## 8. How to edit lessons (no code)
- Edit `assets/learn/basics.json` and hot restart: titles, steps, mistakes, key point, practice.
- `"move"` must be one of: `stance`, `step`, `jab`, `cross`, `one_two`, `lead_hook`, `rear_hook`, `uppercuts`, `defense`, `combo`.
- Practice:
  - `"type": "drill"` with a `drill` block (same format as `assets/drills/programs.json`, plus `minPunches`);
  - or `"type": "follow"` with `followSeconds`, `cueIntervalMs` and `cues`.
- A broken lesson is skipped; it never crashes the app.
- New animations go in `lib/features/learn/domain/boxer_moves.dart` (poses are joint positions in a 1×1 box).
