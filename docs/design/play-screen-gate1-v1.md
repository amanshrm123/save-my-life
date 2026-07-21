# Play Screen — Feel Prototype (Days 3–5, Gate 1) v1

*Companion spec to architecture's Days 3–5 entry ("Feel prototype + GATE 1") and `docs/discovery/TimingTap_Discovery_v1.md` §3a. Builds directly on top of `docs/design/play-screen-skeleton-v1.md` (Days 1–2) — this document only specs the **delta**: what's added, nothing already-built is repeated except where a zone's contents change. For flutter-developer to build directly from.*

> **Note on sources:** this spec was written against `docs/architecture/v1.md` §3 "Days 3–5" (the current architecture doc in this repo) and `docs/discovery/TimingTap_Discovery_v1.md` §3a — a `v2.md` and a `screen-library-v3.html` were referenced as inputs but do not exist in this checkout yet. The Days 3–5 scope language in v1 §3 matches what was asked for verbatim ("a tap flash + one sound... just enough to judge feel"), so this doc proceeds from that. Colors/shapes below are reasonable defaults, not pulled from a mockup that isn't in the repo — if `screen-library-v3.html` lands later, reconcile hex values against it, but the durations/behavior/scope boundaries below hold regardless, since even the mockup's full fidelity is explicitly out of bounds for this phase.

---

## 0. What this phase is (and is not)

**Is:** the walking skeleton (Days 1–2) plus exactly four additions — a countdown, a real life bar, a minimal tap flash, and one sound — because right now the skeleton is pure debug text, and text-only feedback is too sterile for a stranger to fairly judge "does this feel good." These additions exist **only** to make that judgment possible.

**Is not:** a polish pass. No haptics, no particle/juice animation, no easing curves, no color ramps, no final-band styling, no pause overlay. If flutter-developer finds themselves reaching for an `AnimationController` with a `Curve`, a haptics package, or more than two flash/sound states — stop, that's later-phase scope creep (see §5).

Everything in §§1–4 below is deliberately buildable with `Timer`/`Future.delayed`, flat `Container` color swaps, and one lightweight SFX package — nothing that needs animation-curve tuning time, because Gate 1's clock is short and player-reviewer needs a build this week, not a beautiful one.

---

## 1. Countdown (screen-library 2.1, minimal form)

**Purpose:** per the brief, "the 3-2-1 sets a shared rhythm and is part of what a stranger judges as feel" — it's not decoration, it's the first few seconds of pacing a stranger experiences before they've even tapped once.

**Where it lives:** not a new route/screen. `RunPhase` (already stubbed in `run_controller.dart`) gets a second value:

```dart
enum RunPhase { countdown, playing }
```

`RunController.build()` now starts in `RunPhase.countdown` instead of `RunPhase.playing`. `PlayScreen.build()` branches on `runState.phase` at the top: `countdown` → render the **Countdown view** below (replaces the whole screen body); `playing` → render the existing 4-zone Column from the skeleton (now with the life bar and flash, §2–3).

**Countdown view (full-screen, not squeezed into Zone B):**

```
Scaffold
 └── SafeArea
      └── Center
           └── Text('3' | '2' | '1', huge, bold, single flat color)
```

**Sequence (exact, no ambiguity):**
1. On entering `RunPhase.countdown`, show `"3"` for 1000 ms, then `"2"` for 1000 ms, then `"1"` for 1000 ms — 3000 ms total, driven by a plain `Timer.periodic(const Duration(seconds: 1))` (or three chained `Future.delayed` calls) inside a small `ConsumerStatefulWidget` (call it `CountdownView`). This timer is **wall-clock pacing, not scored** — it must **not** go through `MonotonicClock`. The architecture's monotonic-clock-only rule (§1.2) applies to the tap-timing path only; a code-reviewer flagging this as a violation would be a false positive, worth calling out so nobody "fixes" it.
2. After `"1"` has shown for its full second, cancel the timer and call a new controller method `RunController.beginPlaying()`, which: sets `phase = RunPhase.playing`, **re-rolls** `roundStartMicros` to `clock.elapsedMicroseconds` (now), and rolls a fresh `targetDurationMicros` — so the first round's timing starts clean at the instant "1" disappears, not from whenever the countdown happened to begin.
3. No transition between "1" and the Play layout — instant widget swap on the next frame (same as skeleton's "no transition/curve" rule for State 1→2). No "GO" frame, no fade, no cross-dissolve.
4. Numbers do not animate individually — no scale/bounce/ease per digit, one flat color throughout, single large font (recommend ~120sp equivalent, centered) so it reads clearly from arm's length. This is the entire countdown spec — anything more elaborate is 2.1's full-fidelity version, deferred.

**When it plays:** currently, only once per app session, since no restart/outcome loop exists yet in this phase (`outcome_resolver.dart` is Days 6–10). This is intentional and forward-compatible: because it's just a `RunPhase` value, once restart is wired later, re-entering `RunPhase.countdown` on every new run requires no new mechanism — this doc's job is done once the *pattern* exists.

---

## 2. Life bar

**Purpose:** a real bar the player can read at a glance, not a number they have to parse. Keep the numeric `LIFE: n%` text too — it's still useful for tester/debug and costs nothing to keep.

**Where it lives:** Zone A (status strip) gains a second row below the existing `LIFE / TARGET` text row:

```dart
Column(
  children: [
    Row(...existing LIFE/TARGET text...),
    const SizedBox(height: 8),
    Container(                                   // track
      height: 20,
      decoration: BoxDecoration(
        color: const Color(0xFFDDDDDD),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: (runState.lifePct / 100).clamp(0.0, 1.0),
          child: Container(                       // fill
            decoration: BoxDecoration(
              color: runState.lifePct <= 25
                  ? const Color(0xFFE53935)        // danger red
                  : const Color(0xFF4CAF50),        // healthy green
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    ),
  ],
)
```

**Rules, exactly:**
- **One binary threshold, not a ramp.** Fill color is green above 25% life, red at or below 25%. No gradient, no interpolation, no per-percent color math — "no color-ramping logic beyond what's needed to read state at a glance" means exactly this: a single if/else.
- **No width animation.** The bar's width snaps to the new `lifePct` on rebuild — no `AnimatedContainer`, no tween. This is a five-minute upgrade later (swap `Container` for `AnimatedContainer`) if the feel-tuning pass wants it, but it is **not required** for Gate 1 and shouldn't be built now.
- Bar width is proportional (`FractionallySizedBox`/`Expanded`), not fixed pixels, so it holds up across phone sizes per the skeleton's existing responsive rule (§5 there).
- Zone A's flex weight may need a small bump (e.g. 15 → ~20, borrowed from elsewhere) to fit the bar comfortably without shrinking Zone D (the tap surface) — adjust proportionally, don't hardcode pixel heights.

---

## 3. Minimal tap flash

**Purpose:** legibility feedback only — so a stranger can tell "that was good" or "that was bad" by a glance at color, not by reading `BAND: MISS` text. This is a color pop, not an animation sequence.

**Exact spec (buildable with zero curve tuning):**
- **Two colors, binary.** Perfect and On-point both flash the **same** hit color; only Miss is different. Do not build a third color/state for Perfect — that's a future nice-to-have (see §5), not required to judge feel.
  - Hit (Perfect or On-point): `Color(0xFF4CAF50)` (same green as the life bar's healthy fill, for visual consistency).
  - Miss: `Color(0xFFE53935)` (same red as the life bar's danger fill).
- **Fixed duration, no easing.** The flash color appears immediately and disappears after exactly **120 ms** — a hard cut on, hard cut off. No fade-in, no fade-out, no `Curve`, no `AnimationController`. Implement as a state value that gets set, then cleared by a plain `Timer(const Duration(milliseconds: 120), () => ...)`.
- **Where it renders:** reuse Zone D's existing `Container` — don't add a new overlay widget. Its `color` becomes: flash color if a flash is active, else the existing neutral `Color(0xFFDDDDDD)`.
- **How it's wired (recommended, not mandatory in exact mechanics):** add a small `StateProvider<Color?> tapFlashColorProvider` (starts `null`). In the `TapSurface.onTapMicros` callback in `PlayScreen` — **after** `registerTap(pressMicros)` returns — read the now-updated `runState.lastBand` and set `tapFlashColorProvider` to the matching color; start the 120 ms timer to reset it to `null`. Zone D's `Container.color` reads `ref.watch(tapFlashColorProvider) ?? const Color(0xFFDDDDDD)`.
- **Hard rule:** the flash logic must live entirely **outside** `TapSurface`'s `onPointerDown` and outside `timing_engine.resolve()`. It reacts to an already-resolved `TapResult`; it must never sit in, or add any delay to, the tap-capture path. This is the same non-negotiable the skeleton doc's timing rules already established — flash is decoration bolted onto the *result*, never onto the *measurement*.

---

## 4. One sound (two short cues)

**Purpose:** the minimum audio needed for a playtester to judge feel without staring at the screen — sound is often what makes a tap "feel" responsive at all.

**Recommendation: two short one-shot cues, not one.** The brief allows either "distinct tones for hit vs miss" or "one neutral tap-confirm sound" — two short clips costs barely more than one and gives far more signal for Gate 1's actual question (does this feel good), so: build two.

- **Hit cue:** one short (<300 ms), bright/positive tone — plays for both Perfect and On-point (matching the flash's binary treatment; no separate "Perfect" fanfare).
- **Miss cue:** one short (<300 ms), low/negative tone (a soft thud/buzz, not harsh).
- **No music, no loop, no ambient bed, no volume slider/settings, no ducking logic.** Whatever the OS's system volume/silent switch already does is the only volume control this phase needs.
- **Package:** recommend `audioplayers` (lightweight, no codegen, standard for one-shot SFX in Flutter). Add as a new dependency; wrap it in one new file, `lib/core/sound_service.dart`, exposing exactly `playHit()` and `playMiss()`. Assets: `assets/sfx/hit.mp3`, `assets/sfx/miss.mp3` — any short royalty-free clip works; exact sound *design*/mastering is out of scope here.
- **Trigger point:** identical to the flash — right after `registerTap` resolves in `onTapMicros`, call `soundService.playHit()` or `.playMiss()` based on `lastBand`. **Fire-and-forget — do not `await` the play call** in that callback. Sound must never add latency to the next round's timing or sit anywhere near the tap-capture path.

---

## 5. Explicitly still excluded — and why

| Excluded | Why (later phase, not this one) |
|---|---|
| Haptics | Needs per-device vibration tuning and platform permission considerations; a stranger can judge feel from sight + sound alone. Later polish pass. |
| Particle/juice animation (screen shake, scale-bounce, confetti, easing curves) | Needs `AnimationController` + curve-tuning time Gate 1 doesn't have, and it's premature before Gate 1 even confirms the core loop is worth polishing. |
| Life-bar color ramp tied to life% (continuous gradient/interpolation) | This phase needs one binary danger threshold to "read state at a glance" — a full ramp is a visual-polish decision, not a legibility requirement. |
| Perfect vs On-point distinct flash/sound | Collapsed to one "hit" treatment for both (§§3–4) — splitting them is a future juice upgrade, not required to judge whether the loop feels good. |
| Final-band "you're one miss from death" styling (screen-library 2.5) | `outcome_resolver.dart` / final-band logic don't exist until Days 6–10 — there's no state yet to trigger this from. |
| Pause overlay (screen-library 2.6) | No pause functionality is specced anywhere in current scope; irrelevant to judging core tap feel. |
| Countdown animation (per-digit bounce/scale, transition wipe into Play) | This phase's countdown is a plain instant text swap (§1) — full mockup fidelity is explicitly capped below this phase. |
| Width/color tweening on the life bar or flash (`AnimatedContainer`, curves) | Explicitly deferred — see §§2–3, both call this out directly as a later five-minute upgrade, not now. |
| Outcome/death card, share pipeline, ads, persistence | Unchanged from the skeleton doc — still Days 6–10+, not this phase. |

If any of the above shows up in a Days 3–5 PR, it's over-building relative to this spec — flag it in review; it eats time from the actual gate (does a stranger replay unprompted), not from making the prototype look finished.

---

## 6. What Gate 1 is actually judging (keep this in view)

Per the One-Pager: **"Does the tap feel good enough that a stranger replays it unprompted — and comes back the next day?"** `player-reviewer` is the decisive voice on this gate, per architecture.

Every addition in this doc — countdown, life bar, flash, sound — exists **only** to make that judgment fair. Days 1–2's text-only skeleton is honest about engine correctness but too sterile to fairly judge *feel*: a stranger shouldn't have to read `BAND: MISS` to know they messed up. Nothing here is meant to make the game look finished — it should still look and feel like an early prototype, just one where the tap itself is legible enough to judge on its own merits.

The real Days 3–5 deliverable that this doc doesn't cover — because it's not a UX question — is **tuning the actual ±ms values in `timing_config.dart`** (currently the Discovery §3a placeholder defaults: ±30 ms Perfect, ±80 ms On-point) on a real device with `tester` running it across ≥2 Android devices/refresh rates. This spec's job is to make sure that when those tuned values are in and a real stranger picks up the phone, what they see/hear is enough to fairly answer the gate's question — not to decide the numbers themselves.

---

## 7. Summary of changes vs the Days 1–2 skeleton (for flutter-developer)

| File | Change |
|---|---|
| `lib/features/run/run_controller.dart` | `RunPhase` gains `countdown`; `build()` starts in `countdown`; new `beginPlaying()` method (sets `playing`, re-rolls `roundStartMicros`/`targetDurationMicros`) |
| `lib/app/app.dart` (`PlayScreen`) | Branch on `runState.phase`: `countdown` → new `CountdownView`; `playing` → existing 4-zone Column, now with life bar added to Zone A and flash-color logic added to Zone D |
| New: `CountdownView` widget (own file or inline) | Full-screen 3-2-1 per §1, own local `Timer`, calls `beginPlaying()` when done |
| New: `tapFlashColorProvider` (`StateProvider<Color?>`) | Set/cleared per §3, read by Zone D's `Container.color` |
| New: `lib/core/sound_service.dart` | Wraps `audioplayers`; `playHit()` / `playMiss()` per §4 |
| New: `assets/sfx/hit.mp3`, `assets/sfx/miss.mp3` | Registered in `pubspec.yaml`; `audioplayers` added as a dependency |
| `lib/core/timing_config.dart` | Values re-tuned on-device (not a UX change — tester/player-reviewer activity, see §6) |

**"Done when" for this spec:** on a real Android device, a first-time player sees a 3-2-1 that sets a visible rhythm, can read their life state from the bar without parsing a number, gets an immediate color+sound cue on every tap that tells them hit-vs-miss without reading `BAND:` text — and none of the above required an `AnimationController` curve, a haptics plugin, or an asset beyond two short SFX clips.
