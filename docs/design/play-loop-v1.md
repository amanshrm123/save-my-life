# Play Loop & In-Run States — v1

*Companion spec to `docs/architecture/v2.md` §5 (Days 3–5 feel prototype, and the play-loop-state-treatment work folded into "Days 6–11" / "Days 21–23 polish + pause" per §1/§5 there). Source of visual truth: `docs/design/screen-library-v3-2.html` id="b" ("2 · Play loop & in-run states"), diffed against the prior `docs/design/screen-library-v3.html` id="b" to isolate what actually changed. Builds directly on `docs/design/play-screen-gate1-v1.md` (the currently-built Days 3–5 state) and follows the same visual-fidelity pivot `docs/design/onboarding-flow-v1.md` already executed for onboarding — real colors/shapes/Fredoka, not placeholder `Text`/`Container`. For flutter-developer to build directly from **the parts marked confident below only** — several parts of the new mockup are flagged, not specced, and must not be built until the founder rules on them.*

---

## 0. Read this first — flagged concerns

This revision changes more than "make the bare Gate 1 screens pretty." Four things below are real product/technical conflicts with decisions already locked (architecture v2, the Gate 1 spec, or the skeleton spec's structural rules), not nitpicks. I have not silently built past any of them. §0.1 is the one that matters most — do not skip it.

**Process note, briefly:** worth keeping in view while reading these — Gate 1 has still not run its actual decisive test (≥2 real Android devices, `player-reviewer` verdict, per architecture v2 §2/§5). What happened so far is one lukewarm emulator playtest of the bare-debug build, which is why the visual pivot started. That pivot is a reasonable bet, but it means every screen in this doc is still, technically, pre-Gate-1 scope. That raises the bar for anything that adds friction to the core loop rather than just prettifying it — which is exactly what §0.1 does.

### 0.1 "Splash + loader" before *every run* (new 2.1) — flagged, not specced, recommend against building as designed

**What changed:** v3's section 2 opened on the countdown. v3-2 inserts a brand-new screen in front of it: *"Same splash and 5-sec loader bar as onboarding — shown before each run's countdown, so every run opens on the brand beat."* The section's own subtitle confirms this is per-run, not per-app-launch: *"Each run opens on the splash screen... then a 3-2-1 countdown, then the active states."*

**Why I think this is a real problem, not just a style question:**

1. **It has zero technical justification, unlike the existing Splash.** The current app-launch Splash (`lib/app/splash_screen.dart`, per `onboarding-flow-v1.md` §3.2) exists to cover *real* async work — `Hive.initFlutter()`, box open, `ProfileRepository` load — and is explicitly reasoned about as "app-boot chrome," capped at 900ms–3000ms based on how long init *actually* takes. Between runs, none of that exists: `RunController` is already an in-memory Riverpod provider, the clock is already running, Hive/Firebase are already initialized. A "5-sec loader bar" here has nothing real to load — it would have to be a fabricated wait, sitting in the single most latency-sensitive seam in the entire game.
2. **It directly opposes what a fast-replay tap-timing game needs.** The whole genre promise (and this project's own Gate 1 question — *"does a stranger replay unprompted"*) depends on the gap between "I died" and "I'm tapping again" being as close to zero as possible. Splash (branded beat) + 5s loader + 3s countdown (3-2-1) is **8+ seconds of mandatory dead time before a single tap**, on every single retry, forever. That's not a cosmetic cost — it's a pacing/retention risk big enough to plausibly make "feel" *worse*, which is the exact problem this whole visual pivot was meant to fix, not reintroduce.
3. **It isn't in architecture v2 at all.** v2 §5 Days 3–5 says "+Add the countdown (2.1)" — referring to the *original* v3 2.1 (plain countdown). Nowhere in v2's scope guard (§6), phase plan (§5), or module layout (§4) is a per-run splash/loader mentioned. This is new scope the architecture doc hasn't reconciled, which is itself worth surfacing to product-architect, not just to flutter-developer.

**My recommendation:** don't build the literal 2.1 as designed. Three options, my preference marked:

- **(Recommended) Option A — no splash/loader on retry at all.** Cold-start Splash (already built) stays exactly as-is; it never repeats mid-session. "Again" → straight into the (now-visually-upgraded) countdown, §2 below. This preserves the "shared 3-2-1 rhythm" the countdown already earns its place on, without adding a second, unjustified branded beat behind it.
- **Option B — a much shorter, honest micro-beat, if the founder wants *some* retry-branding.** A ~400–600ms non-blocking flourish (e.g. a brief logo pulse) with **no fake progress bar** — never dressed up as "loading," since nothing is loading. Even this should get a real-device pacing check before shipping, because any added delay on the retry path is a direct trade against the core loop.
- **Option C — build the mockup literally (full splash + 5s loader, every run).** Flagged high-risk. If the founder wants this anyway, it needs an explicit sign-off *and* a `player-reviewer` pass specifically testing retry-loop pacing on real hardware before it ships — not just an assumption that "matches the mockup" is sufficient justification for a change this consequential to the loop's core promise.

**Nothing in §6 below specs Option C.** §6 sketches what Option A/B would look like structurally so flutter-developer isn't blocked, but the founder needs to pick before anything here is built.

### 0.2 Final band (2.5) — the underlying mechanic doesn't exist yet, independent of the naming question

The task framing treats "named final-band text" as a low-risk copy addition. The copy part is low-risk (§0.2 below explains why) — but the **screen itself** is not buildable yet, for a reason that has nothing to do with names:

- There is no concept in the code today of "this is the player's last life" or "the next miss is fatal." `RunState`/`RunController` (`lib/features/run/run_controller.dart`) just clamps life to `[0, 100]` and keeps rolling new targets forever — nothing ends the run at 0%, and nothing distinguishes "normal miss" from "fatal miss."
- This is not an oversight — it's `outcome_resolver.dart` territory, explicitly not built until architecture v2's Days 6–11 phase, and the Gate 1 spec already flagged this exact gap: *"Final-band... styling (screen-library 2.5)... there's no state yet to trigger this from"* (`play-screen-gate1-v1.md` §5). That's still true today; I checked — no `outcome_resolver.dart` exists in `lib/features/run/`.
- The mockup's 2.5 also introduces new UI logic beyond styling — a single "Nail it — Survive" pill replacing the two Hit/Miss pills, a red-bordered numplate — all of which is meaningless without the Survived/Death outcome logic behind it.

**Decision, not just a flag:** 2.5 stays deferred to Days 6–11, per the architecture's own plan, unchanged by this mockup revision. What *is* low-risk and worth banking now: the **naming pattern** itself (reading `ProfileRepository.name`, composing "Hey {name}, ___" vs. a no-name fallback) is established cleanly in the countdown (§2) and can be reused verbatim on 2.5 once outcome logic exists. That reuse is the one piece of this screen worth committing to now — the screen itself is not.

### 0.3 Pause (2.6) — still out of scope this pass

2.6 is unchanged between v3 and v3-2 (not a new addition in this revision) but the task asked me to confirm its status rather than assume. Checking: architecture v2 §5 explicitly places pause in **Days 21–23 — Cross-feature polish + pause**, bundled with "run freeze/resume state" and a `code-reviewer` audit that "pause must not perturb the timing path — clock pauses cleanly, no drift on resume." That's real engine work (clock pause semantics), not a skin. The Gate 1 spec's own exclusion table said the same thing months ago (*"No pause functionality is specced anywhere in current scope"*), and nothing in the codebase has changed that — there's no `RunPhase.paused`, no freeze logic, no pause affordance anywhere in `run_controller.dart`/`play_screen.dart` today.

**Decision:** 2.6 stays deferred to Days 21–23, unchanged. Not specced below. If the founder wants pause pulled forward, that's a scope/timeline conversation with architecture first, not something to slot into a "visual fidelity" pass.

### 0.4 Smaller flags — worth a founder glance, lower stakes than §0.1–0.3

- **"Run 12" / "Deaths 3" chips (Zone A) reference counters that don't exist yet.** There is no run-count or lifetime-deaths tracking anywhere in the code — both need the outcome/restart loop (Days 6–11) and the persisted lifetime counters (`hive_profile_repository.dart`, same phase) before they'd show anything but a permanently frozen "Run 1 / Deaths 0." §3 below omits these chips for that reason; recommend adding them once they'd show real numbers, not before.
- **The "±64ms" / "±58ms" tolerance readout implies adaptive difficulty, which v1 explicitly disables.** The mockup shows this value narrowing at low life (±64ms → ±58ms in the final-band shot). Architecture's scope guard is explicit: *"Adaptive difficulty tightening... Fixed bands ship; k scaffolded off"* (v2 §6), and `TimingConfig.adaptiveK = 0.0` today. If this readout is built, it must show the current fixed `TimingConfig.onPointMs` value, constant regardless of life% — not a value that appears to shrink, which would visually promise a mechanic that isn't live.
- **Legend pill copy "Miss 35%" doesn't match anything in `timing_config.dart`.** `TimingConfig.missLifeDelta = -4.0`. "35%" reads as a mockup authoring slip (or a value from a different draft); flutter-developer should source these pills from the real config constants (`onPointLifeDelta`, `missLifeDelta`), not copy the mockup's literal digits.
- **The mockup's "2.3 On-point hit" screenshot actually shows Perfect-band numbers.** Its flash pill reads "PERFECT +3%" (`+3%` matches `perfectLifeDelta`, not `onPointLifeDelta = 2.0`) under a caption that says "On-point." §3 below specs both bands with their own correct copy/values rather than reproducing this inconsistency.
- **Zone D's tap surface must not shrink to a literal small pill.** The mockup's `.tapbtn` reads visually as a modest, centered button — but `play-screen-skeleton-v1.md` §4 locked "the full width of the screen and roughly the bottom half of its height" as a structural, ergonomics-driven decision (precision + one-handed thumb reach + repeated-tap fatigue), explicitly *not* a "centered button." §3 below resolves this by applying the mockup's *visual* chrome (color, border, shadow, corner radius) to the *existing full-size* Zone D, rather than shrinking Zone D to match the mockup's cramped proportions. This is a deliberate divergence, stated here so nobody "fixes" it back to literal mockup proportions later.

---

## 1. What this pass is (and isn't)

**Is:** the visual-fidelity reskin of the already-built, currently-bare Gate 1 states — countdown, neutral, on-point hit, miss — using the same font/color/shape system `onboarding-flow-v1.md` already established (Fredoka, `AppColors`, the flat zero-blur `BoxShadow` recipe, `StickerButton`'s visual language). Plus: personalizing the countdown with the player's name, since `ProfileRepository.name` already exists and costs nothing extra to read here.

**Is not:** the splash/loader question (§0.1, unresolved), the final band (§0.2, blocked on outcome logic), pause (§0.3, out of phase), or "Run/Deaths" chips (§0.4, no backing data). None of those are specced below beyond the flag itself.

---

## 2. Countdown (named) — full spec

**Where it lives:** same file, `lib/features/run/countdown_view.dart`. This is a cosmetic wrap of the existing `CountdownView` — the timing mechanism (three `Timer.periodic` ticks, 1000ms each, post-frame-callback-deferred start, `beginPlaying()` call at the end) is **unchanged**. Nothing about the Gate 1 spec's countdown rules (`play-screen-gate1-v1.md` §1) is touched: still no per-digit animation, still no transition into the Play layout, still wall-clock `Timer` pacing rather than `MonotonicClock`.

**What's new:** a header line above the number, and real chrome around the number instead of a bare 120sp `Text`.

```
┌───────────────────────────┐
│                           │
│  Hey Aman, get ready       │  ← header, name-aware (or "Get ready")
│                           │
│         ╭─────╮           │
│         │  3  │           │  ← gold circle, ink border + flat shadow
│         ╰─────╯           │
│                           │
│  First target drops when   │  ← caption, unchanged copy
│  it hits zero.             │
│                           │
└───────────────────────────┘
```

**Header text — the name-aware part:**
- Read `ref.watch(profileRepositoryProvider).valueOrNull?.name`. This is safe to read synchronously here: `profileRepositoryProvider` is a `FutureProvider` that `SplashScreen` already `await`s before routing anywhere (`splash_screen.dart` `_runInit()`), and `CountdownView` is only ever reached *after* Splash has resolved and routed — so by the time Play exists, the provider is already resolved `AsyncData`, no loading branch needed here.
- Name present: `"Hey {name}, get ready"`, with `{name}` in `AppColors.coral` — same `RichText`/`TextSpan` pattern `splash_screen.dart` already uses for "Stay **Alive!**" (reuse that composition style, don't invent a new one).
- Name absent (skipped naming): plain `"Get ready"`, no colored span, same weight/size. This is the same "conditional text composition on one widget, not a second template" pattern `onboarding-flow-v1.md` §3.4/§5.6 already established for no-name fallbacks elsewhere — nothing new architecturally.
- Style: 16sp, weight 700, `AppColors.ink`.

**The circle (recommended concrete values — mockup's 96px is inside a 224px-wide phone mockup, not 1:1 with a real device, same translation caveat `onboarding-flow-v1.md` §2.4 already called out):**
- Diameter 140dp, `BoxDecoration`: fill `AppColors.gold` *(new token — see §9)*, border 3.5dp `AppColors.ink`, flat `BoxShadow(offset: Offset(0, 6), color: ink, blurRadius: 0)` — same zero-blur recipe as `onboarding-flow-v1.md` §2.3, just a bigger offset to match the mockup's `0 6px 0` on this element specifically.
- Number: 56sp, weight 700, `AppColors.ink` (not white — the mockup's number sits directly on the gold fill with no separate text-shadow treatment).
- No animation on digit change — same hard "no per-digit bounce/scale" rule as before.

**Caption below the circle:** unchanged copy, "First target drops when it hits zero." — style matches the existing teaching-card body convention (`AppColors.teachBody`, 14sp/600, centered, capped max-width ~230dp scaled to a fraction of screen width per the responsive rule in §8).

**Explicitly not changed:** the 1000ms-per-digit timing, the post-frame-callback timer start (the on-device countdown-skipping fix already in place — do not touch), the instant swap into the Play layout when "1" finishes.

---

## 3. Active run states — neutral / on-point hit / miss (visual fidelity reskin)

**Where it lives:** `lib/features/run/play_screen.dart`, the `phase == RunPhase.playing` branch. Same 4-zone Column structure from the skeleton — this pass restyles Zones A, B/C (numplate), and D; it does not change zone proportions, the `Listener`-based tap capture, or any timing/state logic in `run_controller.dart`/`timing_engine.dart`.

### 3.1 Zone A — life meter

Keep the existing `lifePct`-driven fill logic and widen it from a strict binary threshold to a three-tier read, since this pass is explicitly the "juice/polish" upgrade the Gate 1 spec already flagged as a valid later addition (`play-screen-gate1-v1.md` §2: *"this is a five-minute upgrade later... if the feel-tuning pass wants it"*):

| Life% | Fill color |
|---|---|
| `> 50` | `AppColors.green` |
| `25 < life <= 50` | `AppColors.coral` |
| `<= 25` | `AppColors.red` |

(This reframes the mockup's "shifts toward coral after a miss" as a life%-driven tier rather than an event-driven transient — simpler to build, same visual story, and doesn't need new state beyond what `lifePct` already provides.)

- Track: `AppColors.paper` fill, 2px `AppColors.ink` border, `BorderRadius.circular(999)`, ~1.5dp inner padding around the fill (matches the shape recipe `onboarding-flow-v1.md` §5.2 already used for the splash preload bar — reuse it for visual consistency between the app's few bar widgets).
- Still **no width animation** — snap on rebuild, per Gate 1 §2's explicit "not required, don't build now" call. Nothing in the new mockup requires revisiting that.
- Keep the numeric `Life {n}%` label next to the bar (still useful, costs nothing).
- **Tolerance readout, if built:** `"±{TimingConfig.onPointMs}ms"`, constant across all life levels (§0.4) — do not vary this with `lifePct`.
- **Do not add "Run N" / "Deaths N" chips this pass** (§0.4) — leave Zone A's top row as it is today (or empty) until Days 6–11 gives these real values to show.

### 3.2 Zone B/C — numplate

Replace the bare `TARGET: {n}s` debug text with:

```
Tap at
┌───────────┐
│   16.00    │   ← numplate: paper fill, 2.5px ink border,
└───────────┘      radius 18, flat shadow (0,4) ink, number 40sp/700 ink
```

- Small "Tap at" label above, 11sp/600, `AppColors.mute`-ish (matches mockup's small gray label).
- Number keeps the exact same source/formatting as today — `runState.targetDurationMicros / 1000000`, `toStringAsFixed(2)` — no logic change, only the container chrome around it.
- **Flash pill** (on-point/miss result) now floats near this zone rather than washing the whole tap surface (a deliberate relocation from the Gate 1 spec's Zone-D-color-wash approach, matching the new mockup's placement): a small pill, `BorderRadius.circular(999)`, 2.5px ink border, flat shadow (0,4) ink, positioned via `Stack`/`Positioned` roughly where Zone B/C's center sits.
  - Perfect: `"PERFECT +{TimingConfig.perfectLifeDelta}%"`, `AppColors.green` fill, white text.
  - On-point: `"ON POINT +{TimingConfig.onPointLifeDelta}%"`, same green fill, white text (own correct copy per band — see §0.4's note that the mockup's own on-point screenshot mislabeled itself).
  - Miss: `"MISS {TimingConfig.missLifeDelta}%"` (render the sign, e.g. "MISS -4%" — don't drop it), `AppColors.red` fill, white text.
  - Same **120ms hard-cut, no fade** timing as today — only the visual container and position change, not the show/hide mechanics or the "must fire strictly after `registerTap` resolves, never inside `TapSurface`/`resolve()`" hard rule from `play-screen-gate1-v1.md` §3. That rule is unchanged and still governs this.

### 3.3 Zone D — tap surface

Apply the mockup's `.tapbtn` visual chrome to the **existing full-size Zone D container** — do not shrink Zone D to the mockup's small-pill proportions (§0.4's ergonomics flag).

```dart
// Inside the existing Listener-wrapped Container (do NOT swap Listener
// for GestureDetector/StickerButton — see note below):
Container(
  width: double.infinity,
  // fills the whole ~50%-flex Zone D, same as today
  decoration: BoxDecoration(
    color: flashColor == null ? AppColors.coral : /* keep existing flash-on-tap behavior if still wanted, see note */,
    border: Border.all(color: AppColors.ink, width: 2.5),
    borderRadius: BorderRadius.circular(22),
    boxShadow: [BoxShadow(offset: Offset(0, 6), color: AppColors.ink, blurRadius: 0)],
  ),
  child: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('TAP', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
          color: Colors.white, shadows: [Shadow(color: AppColors.coralDark, offset: Offset(0, 1.5))])),
        Text('land on the number', style: TextStyle(fontSize: 9, color: Colors.white70)),
      ],
    ),
  ),
)
```

**Important — do not reuse the `StickerButton` widget here.** `StickerButton` (`core/widgets/sticker_button.dart`) wraps a `GestureDetector`, which is exactly what architecture bans in the timing-capture path (`play-screen-skeleton-v1.md` §1: "not `GestureDetector`... those route through the gesture arena and add latency"). Copy `StickerButton`'s *visual recipe* (border/shadow/radius/text-shadow) by hand into the existing `Listener`-wrapped `Container` — the `Listener.onPointerDown` capture mechanism itself must not change.

**Legend pills** ("Hit +2% / Miss -4%") below the button: static informational text, sourced from `TimingConfig.onPointLifeDelta`/`missLifeDelta` (not the mockup's literal "35%" — §0.4), `AppColors.paper` pill chrome, unchanged regardless of run state.

**Whether the whole-zone color wash from Gate 1 (§3 there) survives alongside the new floating flash pill, or gets replaced by just the pill, is flutter-developer's call** — either reads fine (a brief coral/red tint under the "TAP" label plus the floating pill, or just the pill alone); this doc doesn't need to lock that detail, it's non-structural.

---

## 4. Final band (2.5) — explicitly deferred

Not specced. See §0.2. Revisit once `outcome_resolver.dart` exists (Days 6–11) — at that point, reuse the exact naming pattern from §2 (`ProfileRepository.name`-driven, no-name fallback, coral-colored name span) rather than re-deriving it.

---

## 5. Pause (2.6) — explicitly deferred

Not specced. See §0.3. Revisit at Days 21–23 per architecture v2 §5, alongside the run-freeze/resume engine work it depends on.

---

## 6. Splash + loader (2.1) — not specced pending founder call

No build spec here — see §0.1 for the concern and the three options. If the founder picks Option A (recommended), there is nothing to build: cold-start Splash already exists and already doesn't repeat mid-session. If Option B, the structure would be a small stateless widget (~500ms `TweenAnimationBuilder` logo pulse, no progress bar, no async gating) inserted between an outcome screen's "Again" tap and `RunController` re-entering `RunPhase.countdown` — but exact timing/visual should wait for the founder's decision, not be guessed here.

---

## 7. Key states summary (for tester)

| State | Trigger | What's shown |
|---|---|---|
| Countdown | `RunPhase.countdown` (every run start) | Named/no-name header, gold circle 3→2→1, static caption |
| Neutral | `RunPhase.playing`, no recent tap | Life bar (3-tier), numplate, tap button, legend pills — no flash |
| On-point hit | Immediately after a Perfect or On-point tap | Green flash pill (band-correct copy/%), life bar ticks up, 120ms hold |
| Miss | Immediately after a Miss tap | Red flash pill, life bar ticks down (and may cross a color tier), 120ms hold |
| Final band | *(deferred, §4)* | Not built this pass |
| Pause | *(deferred, §5)* | Not built this pass |
| Splash+loader | *(flagged, §0.1/§6)* | Not built this pass pending founder call |

---

## 8. Responsive behavior (brief)

Same discipline as every prior spec in this repo: proportional sizing (`Expanded`/`flex`, `MediaQuery`-relative caps), not fixed pixel heights, so the reskinned zones hold up across phone sizes. The numplate and tap-button chrome (border widths, shadow offsets, corner radii) are literal tokens per `onboarding-flow-v1.md` §2.4's precedent — keep them as fixed dp values regardless of screen width; only overall zone proportions and text max-widths should scale. Portrait-only, no tablet layout — unchanged from every prior doc's reasoning.

---

## 9. Summary of files/changes (for flutter-developer)

| File | Change |
|---|---|
| `lib/features/run/countdown_view.dart` | Add name-aware header (reads `profileRepositoryProvider`), gold circle chrome around the number, caption text. Timing/mechanism unchanged (§2). |
| `lib/features/run/play_screen.dart` | Zone A: 3-tier life-bar color, optional fixed tolerance readout, no Run/Deaths chips (§3.1). Zone B/C: numplate chrome, relocated band-correct flash pill (§3.2). Zone D: `.tapbtn`-style chrome applied to the existing full-size `Listener` container, band-correct legend pill values from `TimingConfig` (§3.3). |
| `lib/core/theme.dart` | Add `AppColors.gold` (`#FFC23C`) — new token needed for the countdown circle; add `goldDark` (`#E5A516`) too while touching this file, for later reuse (rewarded/skins work, out of scope here but cheap to add now). |
| `lib/core/timing_config.dart` | No changes — read from, not written to (§0.4's copy-correction sources). |
| Not touched this pass | `run_controller.dart` (no new state needed for anything specced above), `outcome_resolver.dart` (doesn't exist — §0.2), any pause/freeze logic (§0.3), any splash/loader route (§0.1/§6). |

---

## 10. "Done when"

For the parts actually specced here (§2–3): on a real Android device, a first-time-named player sees "Hey {name}, get ready" before every run and a no-name player sees a clean "Get ready" fallback with no broken text; the countdown reads as a real branded moment (gold circle, real type) rather than a bare number; the neutral/hit/miss states show a readable three-tier life bar, a styled numplate, band-correct flash pills sourced from real `TimingConfig` values (not the mockup's literal, occasionally-wrong copy), and a full-bottom-half tap zone that still *looks* like the mockup's button without shrinking the actual forgiving hit area. None of this required building the splash/loader (§0.1, unresolved), the final band (§0.2, blocked), or pause (§0.3, out of phase) — and nothing above should have needed a `RunPhase` change, an `outcome_resolver.dart` stub, or a `GestureDetector` swap in the tap-capture path.
