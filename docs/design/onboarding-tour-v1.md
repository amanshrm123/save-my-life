# Stay Alive — First-Time Feature Tour v1

Status: proposed, implementation-ready
Owner: product-architect
Branch: `feat/onboarding-tour` (worktree `/Users/apple/SML-worktrees/onboarding-tour`)
Consumes: `docs/architecture/v1.md` §2/§3/§8 (Riverpod, plain `Navigator`, memory rules),
`docs/architecture/v3.md` §7/§11 (prefs write-through, once-only flags),
`docs/design/remaining-screens-v1.md` §5.1 (Home dashboard geometry),
`docs/design/onboarding-v1.md` §1 (type/color tokens).
Consumed by: `flutter-developer` (build from this doc), `game-ux-designer` (mock the
overlay, then verify the built screen per CLAUDE.md rule 6), `tester` (§10).

This is a **design/architecture spec, not code**. Where a Flutter mechanism is named
it describes the effect to reach for and the lifecycle constraint, not literal syntax.

---

## 0. What this is, and what it is NOT

The founder's ask: *"a tour functionality for the app like how tour works for 1st time
user giving info and like where to find what."*

**This is a UI/feature-discovery tour: a spotlight overlay on the Home dashboard that
points at four real on-screen elements and says what each one is for.** It is a new,
additive feature in its own module. It does not touch, replace, reorder, or re-run the
existing onboarding flow.

The hard boundary against the shipped onboarding (`onboarding_screen.dart` +
`teach_card.dart`) — this is the single most important thing for the flutter-developer
stage not to blur:

| | Existing onboarding (shipped, untouched) | This tour (new) |
|---|---|---|
| Teaches | Abstract game rules — tap the number, life goes up/down, three endings | Where things live on Home — what this card is, what that tile does |
| When | Before the player ever reaches Home, once | After the player has played at least one run (§2) |
| Form | 4 full-screen `PageView` pages, own route | Non-route overlay drawn on top of the live Home screen |
| Points at | Nothing — centered emoji + prose | Actual, measured, on-screen widget rects |
| Gate | `onboarding_complete` | `home_tour_shown` (new, separate key) |
| Module | `lib/features/onboarding/` | `lib/features/tour/` |

The only file inside `lib/features/onboarding/` this spec permits changing is one import
line in `teach_card.dart` (see §7's `PageDots` promotion). Zero behavior or visual change
to onboarding. If that promotion is contested during review, drop it and cross-import
instead — the tour must not become a reason to reopen onboarding.

Copy overlap is also forbidden: no tour step may re-explain tapping the number, the life
meter, or the three endings. `teach_card.dart` already owns that content.

---

## 1. The tour: four steps, in this order

Targets are the shipped Home dashboard elements in `home_screen.dart`. Copy is final —
it is single-call-site, so it lives in `lib/features/tour/domain/tour_step.dart`, **not**
in `core/copy/app_copy.dart` (that file's own doc comment scopes it to strings reused
across more than one screen).

| # | Target widget (`home_screen.dart`) | Emoji | Headline | Body |
|---|---|---|---|---|
| 1 | `_StreakCard` | 🔥 | Keep your streak | Play once a day to hold it. Miss a day, back to zero. |
| 2 | the 3-`StatTile` `Row` (as one rect) | 📊 | Your record | Survived, Eternal, Deaths. Tap any tile for full stats. |
| 3 | `HomeAvatarCard` | 🧍 | This is you | The fill is your best life ever. Tap to change your look. |
| 4 | `_SettingsIconButton` | ⚙️ | Everything else | Sound, name and daily reminders live behind the gear. |

Order is the dashboard's own top-to-bottom reading order, with the gear deliberately last
as an "and one more thing, up top" catch-all — step 4's body signposts the upward jump
explicitly, so the one non-linear move reads as intentional.

Step 2 highlights the **whole tile row as a single rect**, not three cutouts. One rect,
one path, and the row is a single semantic unit anyway (all three tiles navigate to the
same Stats screen).

Step 3's copy must not collide with the existing `NoteChip.hint` "👆 Pick your look" pill
that `HomeAvatarCard` already renders when `avatarId == -1`. They can legitimately be on
screen together (a player can reach the tour without ever opening the picker); "Tap to
change your look" and "Pick your look" reinforce rather than contradict, which is
acceptable. Do not add logic to suppress one for the other.

### 1.1 Elements deliberately NOT given a step

- **The Play button.** It is a 50dp coral button labelled "Play". Explaining it insults
  the player and costs a step. The tour instead *ends* by dismissing onto an
  unobstructed Play button — the call to action is the exit, not a slide.
- **The ad banner footer slot.** Two independent reasons: (a) never spotlight your own
  ad inventory to a brand-new player — it converts a helpful tour into a monetization
  ask and is the kind of thing player-reviewer will correctly flag; (b) `BannerAdSlot`
  lives on the unmerged `applovin-ads` branch, and taking a hard dependency would block
  this branch on that one. See §8 for the merge-order coordination note.
- **Wordmark / tagline.** Decorative, self-evident.

---

## 2. Trigger & lifecycle

### 2.1 Trigger — REVISED from "first Home arrival post-onboarding"

**Decision: the tour fires on the first appearance of the Home *dashboard* where the
player has completed at least one run (`totalRunsPlayed >= 1`) and `home_tour_shown`
is false.**

The default assumption in the brief (fire immediately on first Home arrival after
onboarding) is rejected on two concrete grounds:

1. **It points at empty scaffolding.** At that exact moment the streak card reads
   "0 days" with an empty week bar, all three stat tiles read `0`, and the avatar has
   never been picked. Step 1 would explain a streak that does not exist and step 2 a
   record that is three zeros. One run later, every one of those elements has real
   content and the copy lands on something the player can see change.
2. **It stands between the player and their first run.** The player has just tapped a
   button literally labelled "Start playing." Interposing a four-step blocking overlay
   before the first run taxes the single most important event in the funnel. Firing it
   *after* run 1 means the tour is answering questions the player now actually has.

The gate is one extra condition inside `_HomeScreenState._onBecameVisible()` — the
method that already exists as, per its own comment, *"the only place that decides
whether to act on the `justAdvanced` / reminder-prompt gate."* This is structurally the
same cost as the rejected option, not more.

Concrete eligibility, all required, evaluated in `_onBecameVisible()`:

- `!homeTourShown` (or the Settings replay flag is pending — §2.3)
- `statsProvider.totalRunsPlayed >= 1`
- `!snap.justAdvanced` — already an early return; the streak-advanced celebration
  replaces the dashboard body wholesale, so there is nothing to spotlight
- `!isBrokenAtOpen(...)` — already an early return, same reason

In practice the tour lands after the player's first run (via the Outcome screen's "Home"
link), or after their second (if they took the streak-advanced screen's "Play day 1"
path straight back into a run), or on the next cold launch. All three land on a
populated dashboard. It is not reachable-only-by-luck: any cold launch on a day the
streak is intact renders the dashboard with `justAdvanced` false.

### 2.2 Precedence against the reminder opt-in

Both the tour and `_maybeScheduleReminderPrompt` are scheduled from `_onBecameVisible()`.
**Rule: evaluate the tour first; if the tour is going to show, return before reaching
the reminder-prompt gate.** The reminder prompt is re-evaluated the next time Home
becomes visible, and its own `reminder_opt_in_shown` flag is untouched by the skip.
Collision is rare in practice (tour at run ≥ 1, reminder at streak day 2 — a different
calendar day) but the ordering must be written down, not left to which `if` happens to
come first.

Never stack the two: a modal route pushed on top of a spotlight overlay would leave the
overlay's measured rects pointing at a covered screen.

### 2.3 Replay from Settings — IN scope

**Decision: add one Settings row, `🧭 Replay tour`, with a chevron, placed directly below
"Daily reminder" and above the divider that opens the legal group** (it is behavioral,
not legal).

Mechanism, ~10 lines, reusing machinery the tour already needs:

1. Tapping the row sets a transient in-RAM `pendingHomeTourProvider` (`StateProvider<bool>`)
   to true, then `Navigator.pop()`s back to Home.
2. Home's existing `didPopNext()` → `_onBecameVisible()` reads the pending flag, sets it
   back to false, and starts the tour **regardless of `home_tour_shown`**.
3. `totalRunsPlayed >= 1` is not required on this path — the player asked for it
   explicitly. `justAdvanced` / streak-broken still suppress it (nothing to point at).

Worth its small cost: it turns a one-shot blocking overlay into a re-openable reference,
gives QA a way to re-run the tour without wiping progress, and is the standard mitigation
for the usual complaint about forced tours. If the flutter-developer hits real friction
here, **this is the first thing to cut** — the tour itself is the deliverable.

`pendingHomeTourProvider` is deliberately a plain transient `StateProvider<bool>`, not a
persisted flag: a queued replay must not survive an app kill.

### 2.4 Persistence flag

Follows the `reminder_opt_in_shown` pattern exactly (`preferences_service.dart:250-264`).

- `lib/core/persistence/preferences_keys.dart`: **`const String kKeyHomeTourShown = 'home_tour_shown';`** — bool, default false.
  Named `home_tour_shown`, not `tour_shown`, so a future per-screen tour adds its own key
  with no migration.
- `lib/core/persistence/preferences_service.dart`: `bool get homeTourShown` +
  `Future<void> setHomeTourShown(bool)`, same try/catch-swallow shape as every neighbour.
- **No `kPrefsSchemaVersion` bump.** A new key whose absent default (`false`) is already
  the correct state for both fresh installs and existing v2 installs. Existing players
  therefore do get the tour once on their next dashboard visit — that is intended for an
  added feature, and is called out here so it is a decision, not a surprise.
- `clearAll()` already wipes it, so Settings' "Reset progress" correctly re-arms the tour.
  After a reset the player goes splash → onboarding → Home with `totalRunsPlayed == 0`,
  so the tour correctly waits for their first post-reset run. No extra work.

**The flag means "we have shown this," not "the player finished it."** Skipping and
completing write the identical value, same semantic as `reminderOptInShown`.

**Written on first display**, in a post-frame callback once step 1 has rendered — the
exact pattern `ReminderOptInScreen.initState` already uses. A player who kills the app
mid-tour is not re-tour'd next launch.

---

## 3. Visual presentation

The app's design language is flat sticker-book: `AppColors.paper` fills, 2.5dp
`AppColors.ink` borders, **zero-blur** hard offset shadows, Fredoka, coral as the
"look here" accent. There are no blurs, no gradients (outside the Eternal card), and no
Material elevation anywhere. The overlay must obey all of that.

```
┌──────────────────────────────┐
│ Stay Alive              (⚙)   │  ← real Home, dimmed under the scrim
│ One tap. From dust to forever.│
│ ╔══════════════════════════╗ │  ← spotlight cutout: unscrimmed hole,
│ ║  DAILY STREAK            ║ │     3dp coral ring, 8dp inflate,
│ ║  1 day   ▓░░░░░░         ║ │     corner radius matched to the target
│ ╚══════════════════════════╝ │
│ ╭──────────────────────────╮ │  ← coach card: paper fill, 2.5dp ink
│ │ 🔥  Keep your streak      │ │     border, 14dp radius, 5dp hard shadow
│ │ Play once a day to hold   │ │
│ │ it. Miss a day, back to 0.│ │
│ │ ● ○ ○ ○           [Next]  │ │  ← PageDots(count: 4) + green StickerButton
│ ╰──────────────────────────╯ │
│         Skip the tour         │  ← AppTypography.ghostLink, steps 1-3 only
│                               │
│         [    Play    ]        │  ← dimmed, not tappable
└──────────────────────────────┘
```

### 3.1 Scrim + cutout

- Scrim: flat `AppColors.ink` at **0.72** opacity. No blur — the app has no blur anywhere.
- Cutout: the target rect inflated by **8dp**, as an `RRect`. Radius matches the target's
  own chrome: 16 for `_StreakCard`, 14 for the tile row and `HomeAvatarCard`, and for the
  28dp gear a radius of half the inflated height so it renders as a circle.
- Ring: **3dp `AppColors.coral`** stroke on the cutout edge, zero blur. Coral is the app's
  primary/"act here" accent; an ink ring would disappear into the ink scrim.
- **Painting method is load-bearing, not an implementation detail:** one `CustomPainter`
  that builds `Path.combine(PathOperation.difference, <full-screen rect>, <cutout RRect>)`
  and issues a single `drawPath` for the scrim plus one `drawRRect` for the ring. Do
  **not** use `saveLayer` + `BlendMode.clear` — that allocates a full-screen offscreen
  buffer every frame, which is exactly the wrong trade for a RAM-resident app (§9).
  `shouldRepaint` compares the rect.
- The painter receives a **`Rect`**, never a `GlobalKey`, `BuildContext`, `Element` or
  `RenderObject` (§9).

### 3.2 Coach card

Reuses the app's existing card chrome verbatim — introduces no new visual vocabulary:
`AppColors.paper` fill, 2.5dp `AppColors.ink` border, 14dp radius, `BoxShadow` ink /
`Offset(0, 5)` / blurRadius 0. Max width 300, 12dp padding.

Contents, top to bottom:
1. Row: emoji (20dp) + 8dp gap + headline — Fredoka 14/w700 `AppColors.ink`.
   (Not `AppTypography.headline`'s 17 — that is a screen-title size and overpowers a
   floating card.)
2. Body — `AppTypography.body` verbatim (11.5/w600/1.45 `bodyMute`), max 2 lines.
3. Row, `spaceBetween`: `PageDots(activeIndex: step, count: 4)` on the left; a green
   `StickerButton` on the right — label `Next` on steps 1-3, `Got it` on step 4, fill
   `AppColors.green` / labelShadow `AppColors.greenDark`, `height: 36`, `fontSize: 12`,
   `restShadowOffset: 4`. Green + "Next"/"Got it" is the same button treatment the teach
   cards use, which visually rhymes the two flows without duplicating their content.
4. `Skip the tour` — `AppTypography.ghostLink`, centered **below** the card (on the scrim,
   not inside it), 10dp gap. Steps 1-3 only; on step 4 "Got it" is the only exit and a
   skip link there is redundant. Below-the-CTA placement matches onboarding's
   "Skip for now".

**Placement:** below the cutout when the cutout's bottom edge sits in the top 55% of the
screen, otherwise above it, with a 12dp gap. Horizontally clamped to the screen's 16dp
gutters. **No arrow/tail** in v1 — with exactly one element lit on a dark scrim the
association is unambiguous, and tail geometry per placement is real work for no clarity
gain (deferred, §6).

### 3.3 Motion

- The cutout rect animates between steps via `TweenAnimationBuilder<Rect?>` with a
  `RectTween`, 220ms `Curves.easeInOutCubic` — the spotlight visibly *travels* to the
  next element, which is most of what sells a tour.
- Scrim and coach card fade in over 180ms on first show (`AnimatedOpacity`), fade out
  over 150ms on dismiss.
- **No pulsing/breathing ring**, no auto-advance. All motion is implicit-animation only;
  `_HomeScreenState` gains **no** `AnimationController` and **no** `TickerProviderMixin`
  (§9).

---

## 4. Interaction model

| Input | Behavior |
|---|---|
| Tap anywhere on the scrim | Advance one step (last step → dismiss) |
| Tap the `Next` / `Got it` button | Same as above — both paths exist deliberately |
| Tap inside the cutout | **Advance.** The cutout is decorative; the real widget beneath is NOT triggered |
| Tap `Skip the tour` | Dismiss immediately |
| Android back button / back gesture | Dismiss the tour. Must NOT pop Home |
| App backgrounded and resumed | Tour stays on its current step |
| Auto-advance timer | **None** |

**The overlay blocks all interaction with the live UI underneath.** A full-screen
`GestureDetector` with `HitTestBehavior.opaque` absorbs every tap. This is deliberate:
the spotlighted gear would otherwise navigate to Settings mid-tour, leaving a measured
overlay drawn over a covered route. A pass-through/"decorative only" model is a strictly
worse v1 — it invites exactly the state the overlay cannot recover from.

Because the overlay is not a route, the back button reaches `Navigator` unimpeded and —
since Home is the stack root after splash's `pushReplacement` — would **exit the app**.
`PopScope(canPop: false)` wrapping Home while `_tourStep != null`, with the callback
ending the tour, is therefore mandatory, not polish. Without it the tour is escapable
only by quitting.

### 4.1 Failure and edge states — all end the tour silently

The flag is written on first display, so silent termination never re-arms the tour.

- A target key resolves to `null`, or its `RenderBox` is not laid out / has zero size →
  end the tour. Never paint a spotlight over nothing, never throw.
- `build()` takes the `justAdvanced` or streak-broken branch while the tour is up (e.g.
  the player crossed midnight with the app open and `didChangeAppLifecycleState`'s
  `setState` re-evaluated) → end the tour. Those branches replace the dashboard body
  wholesale, so every measured rect is instantly garbage.
- Screen metrics change (rotation, text-scale change, keyboard) → re-measure the current
  step's rect in a post-frame callback. Home already implements `WidgetsBindingObserver`,
  so `didChangeMetrics` is available at zero structural cost. There is no orientation
  lock in `main.dart`, so this is a real case, not theoretical.

### 4.2 Accessibility

- The scrim `GestureDetector` carries a `Semantics` label of the current step's headline
  + body, so a screen reader announces the step rather than an unlabelled tap target.
- `PageDots` already emits `"page N of 4"`.
- The `Skip the tour` link is a real semantic button.
- No timed advance, so no time-limited-interaction failure.

---

## 5. Architecture & module layout

```
lib/features/tour/
  domain/tour_step.dart                  NEW  immutable step model + the const 4-step
                                              list (emoji, headline, body, radius).
                                              All tour copy lives here.
  data/tour_repository.dart              NEW  thin wrapper over PreferencesService,
                                              mirroring SettingsRepository exactly
  state/tour_providers.dart              NEW  tourRepositoryProvider (Provider),
                                              pendingHomeTourProvider (StateProvider<bool>)
  presentation/widgets/tour_overlay.dart NEW  Positioned.fill scrim + painter + placement
  presentation/widgets/coach_mark_card.dart NEW  the paper card of §3.2

lib/core/persistence/preferences_keys.dart      CHANGE  + kKeyHomeTourShown
lib/core/persistence/preferences_service.dart   CHANGE  + homeTourShown getter/setter
lib/core/widgets/page_dots.dart                 NEW     (moved, see §7)
lib/features/home/presentation/home_screen.dart CHANGE  see below
lib/features/settings/presentation/settings_screen.dart CHANGE  + "Replay tour" row
lib/features/onboarding/presentation/widgets/teach_card.dart CHANGE  one import line only
```

A separate `features/tour/` module (not a subfolder of `onboarding/`) makes the boundary
in §0 structural rather than conventional.

### 5.1 Changes to `home_screen.dart`

- Four nullable `GlobalKey?` fields, attached to `_StreakCard`, the stat-tile `Row`,
  `HomeAvatarCard`, and `_SettingsIconButton`.
- One nullable `int? _tourStep` (null = no tour) plus one `Rect? _spotlightRect`.
- `_maybeStartTour()`, called from `_onBecameVisible()` **before**
  `_maybeScheduleReminderPrompt` (§2.2).
- `Scaffold.body` becomes `Stack(children: [ SafeArea(<existing content, unchanged>),
  if (_tourStep != null) TourOverlay(...) ])`, with the overlay `Positioned.fill`.
  The existing body tree is not otherwise restructured.
- `PopScope(canPop: _tourStep == null)` wrapping the `Scaffold` (§4).

Coordinate conversion, so this is not left to guesswork: the target rect is measured in
**global** coordinates (`RenderBox.getTransformTo(null)` / `localToGlobal`), and
`TourOverlay` converts to its own local space via its own `RenderBox.globalToLocal`.
Two lines, and it stays correct regardless of what padding, `SafeArea` or (future)
`AppBar` sits above it — do not assume the Stack's origin is the screen origin.

### 5.2 State management

Step index and rect are ephemeral UI state on `_HomeScreenState`, exactly like the
existing `_isVisible` and `_reminderPromptScheduled`. **They are deliberately not held in
a Riverpod notifier**: a keep-alive provider holding transient overlay state would
outlive Home's own disposal for zero benefit, against this app's RAM-resident discipline
(architecture v1 §1). Riverpod's role here is exactly two objects — the repository
provider and the transient replay flag.

`tourRepositoryProvider` reads through `preferencesServiceProvider`, whose getters are
**synchronous**, so eligibility is decided without an await (§9 depends on this).

---

## 6. Explicitly OUT of scope for v1

Named so the flutter-developer stage does not over-build:

- **Tours on any screen other than Home.** No Play Loop, Stats, Settings, Outcome, or
  avatar-picker tour. `home_tour_shown`'s name leaves that door open for a later phase.
- **A reusable tour framework.** No generic `TourController`, no step registry other
  features can push into, no cross-screen sequencing engine, no per-step callbacks. One
  module, one hardcoded `const` list of four steps.
- **Any third-party package** (`tutorial_coach_mark`, `showcaseview`, `flutter_intro`).
  Each ships its own overlay/controller lifecycle and its own Material-flavoured visual
  language that would have to be fought back into the sticker-book style, for something
  that is ~200 lines here. Same posture as architecture v5 §5 on `appinio_social_share`.
- **An ad-banner step** (§1.1).
- **A Play-button step** (§1.1).
- **Coach-card arrow/tail** (§3.2).
- **Pulsing/breathing spotlight ring, and auto-advance** (§3.3, §4).
- **Analytics events** for tour start/step/skip/complete — the app has no analytics
  layer, only Sentry. A single optional breadcrumb on completion is permitted, not
  required; do not build an event pipeline for it.
- **Localization.** English-only, like the rest of the app.
- **Re-showing the tour after an app update**, "what's new" variants, or version-aware
  tour state.
- **Multi-rect / multi-element spotlights** beyond step 2's single row rect.

---

## 7. `PageDots` promotion

`PageDots` currently sits in `lib/features/onboarding/presentation/widgets/page_dots.dart`
and already takes a `count` parameter (default 3), so `count: 4` works as-is.

**Decision: move it to `lib/core/widgets/page_dots.dart`.** This codebase has an explicit,
documented convention for exactly this — `sticker_button.dart` ("Reused across the whole
app… so it lives in `core/widgets/`") and `toast_pill.dart` (promoted out of the outcome
screen so `ShareTargetSheet` could reuse it rather than introduce a second visual
language). A second consumer is the stated criterion, and the tour is one.

Blast radius: one import line in `teach_card.dart`. No behavior change, no visual change,
no widget-API change. If a reviewer objects to touching the onboarding folder at all
(§0), the fallback is a cross-feature import from `features/tour/` — cross-feature imports
already exist in this codebase (`settings_providers` → `onboarding_providers`). Do not
fork a second copy of the widget.

---

## 8. Coordination with the in-flight `applovin-ads` branch

`/Users/apple/SML-worktrees/applovin-ads` restructures Home's `Scaffold.body` for the
54dp `BannerAdSlot` footer: content moves into an `Expanded` with `SafeArea(bottom: false)`,
and the slot sits outside it in its own `SafeArea(top: false)`. Both branches therefore
edit the same `build()` region of `home_screen.dart`.

Whichever lands second owns these two items:

1. **Re-verify the rects.** Nothing in this spec hardcodes a position — every rect is
   measured at runtime — so the tour is structurally immune to the reflow. But the
   coach-card placement heuristic (§3.2, "top 55%") should be eyeballed once against the
   shortened content area, and step 4's card must still clear the top inset.
2. **Pause the banner while the tour is up.** Pass `isVisible: _isVisible && _tourStep == null`
   to `BannerAdSlot`. Home stays the "visible route" during the tour, so without this the
   native banner keeps auto-refreshing creatives behind an opaque scrim — wasted native
   memory and network, and precisely the unviewable-impression pattern that widget's own
   doc comment already warns about.

This branch takes no dependency on that one and can merge in either order.

---

## 9. Memory safety (CLAUDE.md rule 7)

This app is RAM-resident by design; the mechanism was chosen for that, not just for
convenience. Failure modes considered and how each is handled:

1. **`OverlayEntry` leak — avoided by construction.** The tour is *not* an `OverlayEntry`
   and *not* a pushed route. It is a conditional child of Home's own `Stack`. Setting
   `_tourStep = null` unmounts the whole subtree — painter, card, tickers — through the
   normal framework path. There is nothing to remember to remove in `dispose()`, which is
   the classic coach-mark leak.
2. **Route side effects — avoided.** A transparent pushed route would fire Home's
   `didPushNext()`, which clears `justAdvanced`, flips `_isVisible` false (killing the
   avatar fill animation and pausing the banner), and emits a Sentry route breadcrumb.
   A Stack child causes none of that.
3. **`GlobalKey` retention — bounded and released early.** The four keys are created in
   `initState` **only when the tour is actually eligible** — decidable synchronously,
   since `PreferencesService` getters are sync (§5.2). In every session after the tour
   has been seen, Home allocates zero extra objects and builds its targets with null
   keys. When the tour ends, the fields are set back to `null` in the same `setState`
   that clears `_tourStep`, so the keys are released mid-session rather than living for
   the process lifetime. The keys only ever attach to widgets in Home's own live tree, so
   they never pin a detached element.
4. **Painter captures a `Rect`, never a node.** The measured rect is stored as a plain
   `Rect` (four doubles) in `_HomeScreenState` and handed to the painter as a value. The
   painter never holds a `GlobalKey`, `BuildContext`, `Element` or `RenderObject` — the
   other classic overlay retention path.
5. **No per-frame offscreen buffer.** `Path.combine(difference)` + `drawPath`, explicitly
   **not** `saveLayer` + `BlendMode.clear`, which would allocate a screen-sized RGBA
   buffer every frame the tour is visible (~8 MB on a modern phone). `shouldRepaint`
   compares the rect so the tour is otherwise repaint-idle between steps.
6. **No long-lived tickers or timers.** No `AnimationController` and no
   `TickerProviderStateMixin` is added to `_HomeScreenState`; all motion is implicit
   (`TweenAnimationBuilder`, `AnimatedOpacity`) inside the tour subtree, so every ticker
   dies with the subtree. No auto-advance means no `Timer` to cancel on dispose — a
   `Timer` surviving a screen teardown is precisely the class of bug rule 7 targets.
7. **Measurement is once-per-step, not per-frame.** The rect is resolved in a single
   post-frame callback when the step changes (plus on `didChangeMetrics`). No
   `findRenderObject()` in `build()` or `paint()`.
8. **No new assets.** No images, no fonts, no cached bitmaps, no network. Copy is four
   short `const` string pairs in the rodata segment.
9. **Persistence cost is one bool**, written once, through the existing
   swallow-on-failure path. No list, no cache, no growth over time.
10. **Provider footprint is two objects** — a `Provider` wrapping an already-resident
    service and a `StateProvider<bool>`. Nothing new is kept alive.

---

## 10. Test guidance (scoped per CLAUDE.md rules 4 and 5)

Add tests for the tour and for the Home/Settings integration points only. Do **not** run
the full `flutter test` suite for this change.

**Unit**
- `PreferencesService.homeTourShown`: default false; round-trips true; a failing backing
  store returns the default rather than throwing (mirror the existing prefs tests).
- `TourRepository`: `shown` / `markShown` delegate correctly.
- Rect resolution helper (extract it as a pure function taking a `GlobalKey?` so this is
  testable): null key → null; unlaid-out box → null; zero-size box → null.

**Widget** — new `test/features/tour/`, plus extensions to
`test/features/home/presentation/home_screen_test.dart`
- `totalRunsPlayed == 0`, flag false → no overlay.
- `totalRunsPlayed >= 1`, flag false → overlay renders at step 1, and `home_tour_shown`
  is written exactly once.
- Flag already true → no overlay.
- Tapping the scrim advances 1 → 2 → 3 → 4; `Got it` on step 4 dismisses; flag stays true.
- `Skip the tour` on step 1 dismisses; flag is true.
- **Blocking:** while the overlay is up, a tap at the Play button's location does not
  navigate to `/play`.
- Back button while the overlay is up dismisses the tour and does **not** pop Home.
- `justAdvanced == true` → no overlay. Streak-broken → no overlay.
- Tour eligible and reminder-prompt eligible in the same frame → the tour shows and
  `/reminder-opt-in` is not pushed (§2.2).
- Settings "Replay tour" sets `pendingHomeTourProvider` and pops; Home then starts the
  tour even with `home_tour_shown == true`.

**Run scope:** `test/features/tour/`, `test/features/home/`, the prefs test file, and the
Settings screen test. Not the onboarding, play-loop, outcome, or sharing suites — none of
their files change.

---

## 11. Flags for downstream pipeline stages

**code-reviewer**
1. No `OverlayEntry` and no pushed route — the overlay must be a `Stack` child of Home
   (§9.1/§9.2). Reject any implementation that reintroduces either.
2. No `saveLayer` / `BlendMode.clear` in the scrim painter (§9.5).
3. The four `GlobalKey`s must be nulled out when the tour ends, and must not be allocated
   at all when `home_tour_shown` is already true (§9.3).
4. `PopScope(canPop: false)` while the tour is up — without it, back exits the app (§4).
5. The flag is written on **first display**, not on completion, and skip writes the same
   value as finish (§2.4).
6. Tour is evaluated **before** the reminder prompt in `_onBecameVisible()` (§2.2).
7. No `AnimationController` / `TickerProviderStateMixin` added to `_HomeScreenState`, and
   no `Timer` anywhere in the feature (§9.6).
8. Tour copy lives in `tour_step.dart`, not `core/copy/app_copy.dart` (§1).
9. Every rect-resolution failure path ends the tour silently — no throw, no spotlight over
   an empty rect (§4.1).
10. The only permitted diff inside `lib/features/onboarding/` is one import line (§0, §7).

**game-ux-designer** (CLAUDE.md rule 6 — must verify the built screen against the mockup
before this is done)
Needs a mockup for: scrim opacity, the coral ring weight, cutout inflate/radius per
target, coach-card geometry and internal spacing, the four steps' card placements against
a real populated Home (including step 4 near the top inset), the `Skip the tour` link
position, and the step-to-step rect travel.

**tester** — scope is the overlay, its gates, and the Settings replay row. Not the whole
first-run flow end to end. See §10.

**app-store-specialist / play-store-specialist** — expected to be a no-op, stated here so
both stages can close out fast: no new permissions, no new SDK or dependency, no new
native code, no new network calls, no new data collection or sharing. No Data Safety form
change, no iOS privacy-manifest change. The only new persisted value is one local bool
already covered by existing on-device-storage disclosures.

**player-reviewer** — the two things worth judging: (a) does firing after the first run
(rather than immediately) feel like help arriving at the right moment or like an
interruption of a session already in flow; (b) is four blocking steps one too many. If
the answer to (b) is yes, the first step to cut is step 2 (the stat tiles are the most
self-describing of the four).
