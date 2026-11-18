# Punching Bag Targets & Drill Library — Plan

Status: **PLANNED** (waiting on the owner's answers in §7). Tracked in `ROADMAP.md` → Phase 8.

## 1. Goal
1. Show **where** each number lands, using the KnockUp bag (`assets/images/punching_bag.png`), so beginners learn the 1–6 system by looking, not reading.
2. During a Reaction Drill, **light up the target** on the bag as each number is called (large in landscape).
3. Build drills as **data**, so new programs (e.g. a famous boxer's style) can be added with a JSON entry and an image, not new code.

## 2. The bag and its targets
The image already has the numbers printed, so the app only draws a glow and a ring over the called spot. Positions are fractions of the image (0–1), measured on the 500×500 PNG:

| # | Punch | Bag spot | x | y |
|---|---|---|---|---|
| 1 | Jab | Centre, right | 0.58 | 0.50 |
| 2 | Cross | Centre, left | 0.42 | 0.50 |
| 3 | Lead hook | Left side | 0.15 | 0.49 |
| 4 | Rear hook | Right side | 0.84 | 0.49 |
| 5 | Lead uppercut | Bottom, left | 0.42 | 0.83 |
| 6 | Rear uppercut | Bottom, right | 0.58 | 0.83 |

Stored once in `lib/features/drills/domain/bag_targets.dart`. If the bag artwork changes, only this table changes.

## 3. Where the bag appears

| Place | What it shows |
|---|---|
| **Reaction Drill sheet** (Home) | The bag replaces the 1–6 chips. Tap a number to see its spot light up, plus its name and "lead hand / rear hand". A "How to read the calls" teaching moment. |
| **Drill session, landscape** | Large bag. The called target pulses (ember glow + ring + number). The *next* call shows as a faint outline, so the user can prepare. On a hit the target flashes green; on a miss, a short ember shake. |
| **Drill session, portrait** | Smaller bag under/next to the call ring (see question Q2). |
| **Program detail page** (§4) | The bag showing the program's favourite combos. |

Widget: `PunchBagView(highlight: int?, next: int?, result: hit/miss?, onTapTarget)`. A single reusable widget, drawn with a `Stack` + `LayoutBuilder` so it scales to any size.

## 4. Drill library (future-proof structure)

### 4.1 Data model (`lib/features/drills/domain/`)
```dart
class DrillProgram {
  final String id;              // 'beginner_basics', 'outside_jabber', …
  final String title;           // 'Jab & Move'
  final String subtitle;        // 'Long-range basics'
  final String? coachName;      // optional: who the style is from (see §6)
  final String? imageAsset;     // card / header image
  final String level;           // beginner | intermediate | advanced
  final List<List<int>> combos; // e.g. [[1,1,2],[1,2,3]]
  final int callIntervalMs;     // pace between calls
  final int rounds;             // 0 = open-ended (today's behaviour)
  final int roundSeconds;
  final int restSeconds;
  final bool proOnly;
  final List<String> tips;      // shown before starting
}
```

### 4.2 Content as a file, not code
- All programs live in **`assets/drills/programs.json`**, with images in `assets/drills/images/`.
- Adding a boxer or program = add one JSON entry + one image. No code change.
- Later the same JSON can come from Firebase (Remote Config or Firestore), so new drills ship **without an app update**.

### 4.3 How the session uses it
- `PromptSessionController` already picks combos from `AppConstants.comboList` at a fixed pace. It will read `combos` and `callIntervalMs` from the selected program instead.
- The existing three paces (Beginner / Intermediate / Advanced) become the first three built-in programs, so nothing users have today disappears.
- Punch counting and detection are not touched; only the call list changes.
- Rounds and rest (optional): "Round 1 of 3 · 2:00", a bell, and a 30 s rest with the bag dimmed.

### 4.4 Screens
1. **Drills tab / list** (from the Reaction Drill card): program cards with image, level, length, and a PRO tag where relevant.
2. **Program detail**: image, description, tips, combos shown on the bag, a pace choice, and **Start**.
3. **Session**: as in §3.

## 5. Phases

| Step | Work | Depends on |
|---|---|---|
| 8.1 | `bag_targets.dart`, `PunchBagView` widget + tests; add the asset to `pubspec.yaml` | — |
| 8.2 | Drill sheet: bag legend (tap a number → highlight + name) | 8.1 |
| 8.3 | Drill session: highlight the current call, preview the next, hit/miss flash; landscape layout per Q1 | 8.1, Q1, Q2 |
| 8.4 | `DrillProgram` model + `programs.json` with the three current paces; controller reads combos and pace from the program | — |
| 8.5 | Drills list + program detail screens; Pro lock | 8.4, Q4 |
| 8.6 | Rounds / rest / bell (optional) | 8.4 |
| 8.7 | Remote content (Firebase) | Firebase setup (`docs/LAUNCH_SETUP.md` §2) |

## 6. Suggestions
1. **Southpaw switch.** For left-handed boxers, the lead hand is the right one, so the targets mirror (1 left-centre, 2 right-centre, and so on). One switch in Settings flips the bag. Without it, about 10–15 % of users get confusing targets.
2. **Show the next call faintly.** Real coaches do this ("1-2… 3"). It makes fast paces playable.
3. **Real boxer names and photos need permission.** Using a famous boxer's name or picture to sell an app (e.g. "Train like Ali") can break publicity and trademark rights, and stores can reject it. Safer options:
   - name programs after **styles** ("Peek-a-boo pressure", "Philly shell counters", "Outside jabber") with your own artwork;
   - or get a licence or partnership for real names and images.
4. **Higher-resolution bag image.** The PNG is 500×500. That's fine for the sheet, but slightly soft on a large landscape tablet. A 1500×1500 version (transparent background) would be sharper.
5. **Free vs Pro.** Keep the three basic paces free; make the style programs Pro. That gives the paywall a reason beyond the punch limit and matches the "new lessons and drills" promise already on it.
6. **This also covers part of the store-listing gap** (ROADMAP §3.1, "Learn boxing"): the bag legend plus program tips are a first step towards lessons.

## 7. Open questions for the owner
- **Q1 – Landscape drill layout.** The camera must stay on for detection, but it doesn't have to be big. Options:
  - (a) bag large on the left, camera as a small picture-in-picture, HUD on the right;
  - (b) camera left, bag in the right panel instead of the stats;
  - (c) bag only, camera hidden.

  Recommended: **(a)**, so the user can still see that they're in frame.
- **Q2 – Portrait.** Show the bag in portrait sessions too (small, beside the call ring), or landscape only?
- **Q3 – Boxer programs.** Real names and photos (do you have rights?), or style names with your own artwork?
- **Q4 – Pro.** Which programs are free and which need Pro?
- **Q5 – Southpaw.** Add the mirror switch (recommended)?
- **Q6 – Rounds.** Keep drills open-ended (today), or add rounds, rest and a bell?
