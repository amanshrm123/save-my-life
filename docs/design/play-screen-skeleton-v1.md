# Play Screen — Walking Skeleton (Days 1–2)

*Companion spec to `docs/architecture/v1.md` §3 "Days 1–2 — Walking skeleton + timing engine" and `docs/discovery/TimingTap_Discovery_v1.md` §3a. This is the bare, legible skeleton only — not the feel-prototype (Days 3–5) and not the polished game. For flutter-developer to build directly from.*

---

## 0. What this phase is (and is not)

**Is:** one screen, plain widgets, numbers on screen you can read and trust. The point of this phase is to prove the timing engine is wired correctly (`Listener.onPointerDown` → `MonotonicClock` → `resolve()`), not to prove the game is fun. Fun is Gate 1 (Days 3–5), not this.

**Is not:** no animation, no art, no sound, no haptics, no card UI, no persistence, no menu/settings screen. Every visual element below is a `Text` widget, a `Container`, or a basic Material component — nothing that requires an `AnimationController`, a custom `Ticker`-driven paint (beyond the one already mandated for the moving indicator in architecture §1.2), or an asset.

If flutter-developer finds themselves reaching for a transition, a curve, a color gradient, an icon animation, or a sound plugin during this phase — stop, that's Days 3–5 scope creep. Flag it and move on.

---

## 1. Component hierarchy

```
Scaffold
 └── SafeArea
      └── Column (fills screen, MainAxisAlignment.spaceBetween-ish — see zones below)
           │
           ├── [ZONE A — Status strip]  (top ~15% of screen)
           │     └── Row
           │          ├── Text: life % readout          e.g. "LIFE: 62%"
           │          └── Text: run phase / target readout   e.g. "TARGET: 16.00s"
           │
           ├── [ZONE B — Indicator]  (middle ~20% of screen)
           │     └── CustomPaint (indicator_painter.dart, Ticker-driven)
           │          — the one moving/time element, per architecture §1.2.
           │          Bare form for this phase: a single horizontal progress
           │          line or numeric countdown is enough. No target "zone"
           │          highlighting, no color ramps — that's Days 3–5 juice.
           │
           ├── [ZONE C — Debug readout]  (middle ~15% of screen)
           │     └── Column (persists after each tap until next target)
           │          ├── Text: "DELTA: {deltaMs} ms"
           │          └── Text: "BAND: {PERFECT|ON_POINT|MISS}"
           │     — Empty/placeholder text ("—") before the first tap of a run.
           │
           └── [ZONE D — Tap surface]  (bottom ~50% of screen, largest zone)
                 └── Listener(onPointerDown: ...)
                      └── Container (full width, tall, one flat fill color,
                                     Center → Text "TAP")
                 — This is the entire lower half of the screen, not a button.
                   See §4 (thumb reachability) for why.
```

Notes on hierarchy:
- Zones A/C are `Text` only — no icons, no cards, no elevation/shadow.
- Zone B is the **only** `CustomPaint`/`Ticker` element on screen, per architecture's hybrid rule (static widgets everywhere else).
- Zone D is a single `Listener`, **not** `GestureDetector`, **not** `InkWell`/`ElevatedButton` (those route through the gesture arena and add latency — architecture §1.2 is explicit that this is banned in the timing path).
- No `AppBar`. A bare debug screen doesn't need one — reclaims vertical space for the tap zone, and there's no navigation yet (Play is the only screen this phase).

---

## 2. Key states

### State 1 — Idle / waiting for tap
Target has just been (re)rolled; player hasn't tapped yet this round.

```
┌─────────────────────────────┐
│ LIFE: 62%      TARGET: 16.00s│  ← Zone A
│                               │
│      [ indicator moving ]    │  ← Zone B (Ticker running)
│                               │
│  DELTA: —                    │  ← Zone C — shows prior tap's result,
│  BAND: —                     │     or "—" placeholders on first run
│                               │
│                               │
│                               │
│            TAP               │  ← Zone D — flat fill, static
│                               │
└─────────────────────────────┘
```
Zone C is deliberately **not cleared to blank** between rounds — it keeps showing the *previous* tap's delta/band until the next tap overwrites it. Bare skeleton, but still legible: you should always be able to look at the screen and know "what did my last tap do," which is the entire point of this phase.

### State 2 — Just tapped (result shown)
Immediately after `onPointerDown` fires, `resolve()` runs synchronously, life% updates, Zone C updates.

```
┌─────────────────────────────┐
│ LIFE: 65%      TARGET: 09.40s│  ← life % already updated
│                               │
│      [ new target, indicator │  ← Zone B has already moved on to
│        already running ]     │     the next round — no pause/freeze
│                               │
│  DELTA: 24 ms                │  ← Zone C — this tap's numbers
│  BAND: PERFECT                │
│                               │
│                               │
│            TAP               │
│                               │
└─────────────────────────────┘
```
No transition, no flash, no color change on tap — the text simply updates on the next frame. This is intentional: any per-tap visual feedback beyond text is a Days 3–5 "juice" concern (tap flash / sound, per architecture §3 Days 3–5). Confirming this *absence* explicitly so flutter-developer doesn't add it early.

### State 3 — Life-bar-full / life-bar-empty (edge states, still bare)
There is no visual "life bar" widget in this phase (no rounded bar, no color gradient, no fill animation) — that is explicitly Days 3–5/6–10 territory once `run_controller.dart` and outcome screens exist. For Days 1–2, life is a **plain number in Zone A**, clamped and printed:

```
LIFE: 100%     ← clamp visible directly in the number, no special styling
LIFE: 0%       ← same — no red flash, no "you died" screen yet (no outcome
                  screen exists this phase per architecture: "no cards, no
                  persistence, no art")
```
Skeleton behavior at 0%/100%: the number simply holds at the clamped value (`life = max(0, min(100, life))`) and the run keeps generating new targets. There is no run-end/outcome transition wired yet — that's Days 6–10 (`outcome_resolver.dart`). If `RunController` in this phase already has a stubbed phase field, it's fine for it to exist internally, but nothing in the UI should react to it yet (no navigation, no card, no restart button). This is worth flutter-developer double-checking against the "done when" criteria in architecture §3 Days 1–2, which only asks for stable delta/band printing, not outcome handling.

---

## 3. What is deliberately left out, and why

| Left out | Why (this is Days 3–5+ or later) |
|---|---|
| Tap flash / color change on tap | Feel juice — architecture explicitly schedules this for Days 3–5 ("a tap flash + one sound... just enough to judge feel") |
| Sound / haptics | Same — Days 3–5, and audio plugins add setup overhead not needed to validate the timing engine |
| Animated life bar (fill/color ramp) | No life-bar *widget* exists yet at all — Zone A is a number. Bar visual comes with feel-prototype/outcome work |
| Target-zone highlighting on the indicator (e.g., color band showing Perfect/On-point windows) | Requires the tuned ms values from Gate 1 playtesting (Days 3–5); showing an untuned band would be actively misleading |
| Outcome/death card, "you died" screen | Doesn't exist yet — no `outcome_resolver.dart` until Days 6–10; architecture explicitly says "no cards" for this phase |
| Menu/settings screen, navigation | Only one screen exists this phase (`router.dart`'s 3-screen shape is a Days 6-10+ concern) |
| Persistence (best streak, loss counters) | Explicitly "no persistence" per architecture; Zone A's life% resets to a fixed start value on hot reload/relaunch, that's fine |
| Any transition/curve animation between states | No `AnimationController` anywhere in this phase; State 1 → State 2 is an instant text update, not a tween |
| Adaptive tolerance narrowing visual feedback | Adaptive `k` is scaffolded-but-off per architecture §4 scope guard; nothing to show yet |

If any of the above shows up in a Days 1–2 PR, it's over-building relative to this spec — flag it in review rather than silently accepting it, since it eats time from the thing Days 1–2 is actually supposed to prove (engine correctness + stable latency, per architecture's "done when").

---

## 4. Thumb reachability / one-handed play

Zone D (tap surface) is the **full width of the screen and roughly the bottom half of its height** — not a centered button, not a bottom-anchored small button, not a floating action button. Three reasons, specific to this being a rapid, repeated-tap timing game:

1. **Precision under speed needs a big, forgiving hit target.** The player is trying to land a press within a narrow time window, not a narrow *spatial* one — the game should never introduce a second, spatial precision requirement (missing a small button) on top of the timing one. A large tap area removes X/Y accuracy from the failure modes entirely, so every miss is attributable to timing, not fumbling — which matters for reading the debug numbers honestly in this phase.
2. **One-handed thumb reach.** On a typical phone held in one hand, the reachable arc is the lower third to half of the screen; the top of the screen requires a grip shift or second hand. Putting the tap zone in the bottom half (Zone D) keeps repeated rapid tapping comfortable without hand repositioning, while the read-only info (Zones A–C, top half) is glanced at, not touched — glancing doesn't have the same reachability constraint that tapping does.
3. **Repeated, rapid taps compound small ergonomic costs.** Because this game is tap-every-few-seconds by design, even a slightly awkward target position gets multiplied over a session. A large lower-half zone is the simplest way to keep every tap comfortable without needing per-device layout tuning at this stage.

This is the one interaction-design decision worth locking now even in the bare skeleton, because Zone D's size/position is structural (affects the widget tree shape flutter-developer builds), whereas everything else in this doc is easy to restyle later without touching layout.

---

## 5. Responsive behavior (brief — full responsive pass is not this phase's job)

- Use proportional (`Expanded`/`flex` or `MediaQuery`-relative) sizing for the four zones, not fixed pixel heights, so the layout doesn't break across phone sizes. This is a five-minute cost now that avoids a rework later — it is not the same as a "polish pass."
- No landscape handling required this phase; portrait-only is fine (game is portrait-first per the tap-zone ergonomics above). Lock orientation to portrait if that's a one-line config change; otherwise don't spend time on it.
- No tablet-specific layout. Out of scope until much later, if ever.

---

## 6. Summary of screen-state contract (for flutter-developer / tester)

| Field | Source | Update timing |
|---|---|---|
| `LIFE: {n}%` | `RunController` life state | Updates immediately after each `resolve()` call |
| `TARGET: {n}s` | Current round's target time | Updates when a new round starts |
| Indicator (Zone B) | `indicator_painter.dart`, `Ticker` + `MonotonicClock` | Continuous, same clock instance as tap measurement |
| `DELTA: {n} ms` | `TapResult.deltaMs` from last `resolve()` call | Updates on tap; holds value until next tap |
| `BAND: {PERFECT\|ON_POINT\|MISS}` | `TapResult.band` from last `resolve()` call | Updates on tap; holds value until next tap |

"Done when" check for this spec (mirrors architecture §3): on a real Android device, tapping prints a stable delta + band, repeated taps show consistent latency with no per-frame drift, and nothing above requires touching an asset, animation, or sound file to satisfy.
