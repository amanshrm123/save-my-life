# Play Loop & In-Run States — v2 (exact-fidelity pass)

*Companion spec to `docs/architecture/v2.md` §5 and `docs/design/play-loop-v1.md` (the prior pass). Source of visual truth, re-read for this revision: `docs/design/screen-library-v3-2.html` id="b", specifically 2.2 "Active — neutral", 2.3 "On-point hit", 2.4 "Miss", and the named countdown screen. Current build read against it: `lib/features/run/play_screen.dart`, `lib/features/run/countdown_view.dart`, `lib/features/timing_engine/indicator_painter.dart`.*

**Why this doc exists, and what it overrides:** the founder reviewed the built Play Loop screens against the mockup and judged them "not at all similar." Explicit new direction: **build exactly what the mockup shows, prioritizing pixel/layout fidelity over the ergonomic and data-availability judgment calls `play-loop-v1.md` made** — even where that means stubbing fake data or shrinking a previously "must stay full-size" hit target. This doc supersedes `play-loop-v1.md` §3 (the active-run-state zone spec) in full. It does **not** touch and does not re-litigate:

- `play-loop-v1.md` §2 (named countdown) — re-checked against the mockup below (§1) and confirmed to already match; no changes.
- `play-loop-v1.md` §0.1 (splash/loader before every run) — still unresolved, still not this pass's concern, still the founder's call.
- `play-loop-v1.md` §0.2/§4 (final band, 2.5) — still blocked on `outcome_resolver.dart` not existing (Days 6–11). Not built here.
- `play-loop-v1.md` §0.3/§5 (pause, 2.6) — still Days 21–23 scope. Not built here.

Per this project's versioning convention, `play-loop-v1.md` is left in place, unedited, as the historical record of the prior pass's (now-overridden) reasoning.

---

## 0. What's non-negotiable regardless of this fidelity push

These are correctness/safety rules, not style preferences. Nothing below touches them, and nothing in this fidelity push should be read as license to touch them:

1. **Tap capture stays a `Listener`.** Never `GestureDetector`, `InkWell`, `ElevatedButton`, or `StickerButton` (`core/widgets/sticker_button.dart` wraps a `GestureDetector`) in the tap-capture path — those route through the gesture arena and add latency. Only the `Listener`-wrapped container's **size and decoration** change in this pass; `TapSurface`'s `_handlePointerDown` (`lib/features/timing_engine/tap_surface.dart`) is untouched.
2. **Flash-pill/wash logic stays strictly downstream of `registerTap()` resolving.** The existing rule (`play-screen-gate1-v1.md` §3, restated in `play-loop-v1.md` §3.2) is unchanged: the flash band is read from `ref.read(runControllerProvider).lastBand!` only *after* `registerTap` returns inside `PlayScreen`'s `onTapMicros` callback — never inside `TapSurface.onPointerDown` or `timing_engine.resolve()`.
3. **The countdown's `Timer` stays wall-clock**, not `MonotonicClock`, with its `addPostFrameCallback`-deferred start intact (`countdown_view.dart` `initState`). No changes to `CountdownView`'s timing mechanism in this pass (see §1 below — the countdown's visuals already match; nothing needed there at all, mechanism included).

If matching the mockup's compact tap-button size tempted a change to the `Listener` mechanism itself — it doesn't need one. Only the container's `height`/`BoxDecoration` change.

---

## 1. Countdown — re-checked, confirmed matching, no changes

Re-reading v3-2's named countdown screen against `countdown_view.dart`: header ("Hey {name}, get ready" / "Get ready" fallback), gold circle with ink border + flat shadow, unchanged caption — all present and already faithful to the mockup's structure and color system. `play-loop-v1.md` §2's spec is unchanged and still governs this file. **No action needed here.**

---

## 2. The five confirmed gaps — call made on each

### 2.1 Run/Deaths chips — missing, build them now with hardcoded stub values

**Confirmed:** v3-2 2.2/2.3/2.4 all show a `.topbar` row — `<div class="chip">Run <b>12</b></div><div class="chip">Deaths <b>3</b></div>` — pinned above the life bar. Nothing in `play_screen.dart` renders this today; `play-loop-v1.md` §0.4/§3.1 explicitly omitted it for lack of backing data.

**New direction, and the call:** build the chip row now, visually, with stub values. The specific call — **hardcode `Text('Run')`/`'1'` and `Text('Deaths')`/`'0'` as plain literals, not a provider or in-memory counter.** Reasoning: there is currently no restart loop and no death/outcome logic at all (`RunPhase` has only `countdown`/`playing`; a run never ends today, per `run_controller.dart`). With no event to increment on, a "trivial in-memory counter" would sit permanently at its initial value exactly like a literal — it would just be dead provider code pretending to be more real than a hardcoded string. A literal is the honest, cheapest, correct-looking stub. Days 6–11 (`outcome_resolver.dart` + `hive_profile_repository.dart` lifetime counters) replaces these literals with real values; nothing about the chip's visual shell needs to change when that happens.

**Chip styling — exact, from `.chip`/`.chip b` (screen-library-v3-2.html lines 38–39):**

```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: AppColors.paper,
    border: Border.all(color: AppColors.ink, width: 2),
    borderRadius: BorderRadius.circular(999),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Run ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.ink)),
      Text('1', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.ink)),
    ],
  ),
)
```

Same recipe for the Deaths chip (`'Deaths '` + `'0'`). Border width 2dp is deliberately not reused from `_LegendPill`'s existing 1.5dp border — `.chip`/`.pill` in the mockup are both literally `border:2px`; match that here even though it's a small delta from the existing legend pill (not in scope to retrofit the legend pill this pass — flag only, don't touch it).

**Placement:** its own row, `Row(mainAxisAlignment: MainAxisAlignment.spaceBetween)`, at the very top of the screen content (inside `SafeArea`, above the life bar block) — see §3 for the full restructured layout.

### 2.2 Tap zone size/position — shrink to the mockup's compact button, pills move above it

**Confirmed:** `.tapbtn` is `width:100%;height:78px` inside a 466px-tall mockup screen (screen-library-v3-2.html line 48) — roughly 17% of screen height, not the ~50%-flex full-bottom-half block currently built (`Expanded(flex: 50, ...)` in `play_screen.dart`). The mockup's Hit/Miss pills sit in their own row, `padding-bottom:7px`, **above and outside** the `<button>` element (line 200) — they are not children of the button's content column, as they are in the current `_TapZone` build.

**One-line reversal, stated and then not re-litigated (per instruction):** *this explicitly reverses `play-screen-skeleton-v1.md`'s "Zone D must stay full-size for one-handed ergonomics" rule and `play-loop-v1.md` §0.4's restatement of it — founder has directed this override knowingly; the tap target's hit area now equals the compact button's visual bounds, not the former half-screen block.*

**The call on exact size:** a fixed 88dp height, full width. Derivation: the mockup's screen is `.phone` (224×466px) minus its 8px padding on all sides = a 208×450px screen area, whose aspect ratio (0.462) matches real device logical aspect ratios almost exactly (e.g., 390×844 → 0.462) — so 78/450 ≈ 17.3% is a meaningful, not coincidental, ratio. Applied to real target device heights (roughly 650–900dp logical for supported phones), a literal ratio-computed height clamps to the same ceiling on nearly every device in that range, so a computed `MediaQuery`-based formula would add complexity without changing the real output. **88dp is that output, expressed as a plain fixed dp token** — consistent with this codebase's existing chrome-token convention (`play-loop-v1.md` §8: numplate/gold-circle/border-width values are literal dp constants, not computed). 88dp is comfortably above the 48dp minimum accessible tap target, reads as "a compact single hero button," and is unambiguously smaller than the former ~400dp+ half-screen block.

**Pills move out of the button, into their own row above it** — see §3.4 for full layout.

### 2.3 Indicator/progress lane — remove it from the widget tree entirely (the call)

**Confirmed:** nothing in v3-2's section 2 (any of 2.2–2.5) has a moving-indicator/progress-lane equivalent. `IndicatorWidget`/`_IndicatorPainter` (`lib/features/timing_engine/indicator_painter.dart`) — the paper/ink track with a coral tick, styled in the prior pass — has no mockup counterpart at all.

**The call: option (b), remove it from the widget tree entirely.** Not option (a) (hide but keep mounted) and not option (c) (shrink to non-interference). Justification:

- **There is no hidden architectural coupling that "hiding but keeping mounted" would preserve.** `IndicatorWidget`'s `Ticker` (`createTicker((_) => _repaintTick.value++)`) exists solely to trigger its own `CustomPainter` repaints — it feeds nothing into `RunController` or `timing_engine.dart`. The actual timing driver — `clockProvider`'s `MonotonicClock` — is read independently and directly by `TapSurface._handlePointerDown` and by `RunController.registerTap`/`beginPlaying`. Deleting `IndicatorWidget` from the tree changes **zero** behavior of the clock, the tap measurement, or `RunState`. Option (a)'s premise (that a real, non-visual timing driver "may still matter") doesn't apply here — that driver already lives entirely outside this widget.
- **Keeping a ticker mounted with no visible output is a pure cost.** It's a `Ticker` firing every frame, running a `CustomPainter.paint` that renders nothing useful, for no product or architectural benefit — exactly the kind of thing a fidelity pass should remove, not preserve "just in case."
- **The mockup shows nothing here, at any state.** Not shrunk, not hidden-but-present — absent. Fidelity means matching that.

**Action:** remove the `IndicatorWidget(...)` construction (and its `Expanded` wrapper) from `play_screen.dart`'s "Zone B" column. Delete `lib/features/timing_engine/indicator_painter.dart` — it's a self-contained ~60-line file with no other importers (`RunController`/`TapSurface` never reference it), so removing it is a clean deletion, not a refactor risk. If a future design wants a visual progress affordance back, it's cheap to re-author; there's no reason to keep it as inert dead code in the meantime. (If `flutter-developer`/`code-reviewer` prefer to leave the file in place but simply unreferenced rather than delete it outright, that's an acceptable substitute for the file-deletion part specifically — but the widget **must not** be constructed anywhere in `play_screen.dart`; that part is not optional.)

### 2.4 Life bar / tolerance readout — thickness confirmed off, tolerance value confirmed already correct

**Confirmed:** `.lifebar` is `height:12px` (screen-library-v3-2.html line 42). The built `_LifeBar` (`play_screen.dart`) is `height: 20` — thicker than the mockup, as suspected. **Fix: change to `height: 12`.**

**Also confirmed, while checking this block — the built layout order is inverted from the mockup.** The mockup's structure is: `.lifebar` (the track) first, then `.lifemeta` (the "Life 47%" / "±64ms" row) *below* it, `margin-top: 5px` (lines 42–44, 198). The current build renders the "LIFE: {n}% / ±{n}ms" row **above** the bar, and labels it `"LIFE: {n}%"` (all-caps, colon) rather than the mockup's `"Life {n}%"`. Both are fixed in §3.2 below: meta row moves below the bar, copy changes to `"Life {n}%"`. This isn't one of the founder's five numbered items, but it's directly part of confirming "life bar proportions" per item 4's own ask, so it's folded in here rather than left half-fixed.

**Tolerance value — already correct, do not change.** The mockup's "±64ms"/"±58ms" are illustrative/static mockup copy; the build already renders `'±${TimingConfig.onPointMs}ms'` (currently ±80ms, since `TimingConfig.onPointMs = 80`), constant regardless of life%. That's the correctness-over-cosmetics call `play-loop-v1.md` §0.4 already settled (adaptive tightening is disabled — `TimingConfig.adaptiveK = 0.0` — so a narrowing readout would visually promise a mechanic that isn't live). The founder's direction doesn't touch this. **Confirmed: keep exactly as built.**

### 2.5 Numplate — near match, two small corrections while in the neighborhood

**Confirmed close, per the founder's own read.** Checking exact values against `.numplate`/`.numplate .num` (screen-library-v3-2.html lines 46–47):

| Property | Mockup | Built | Verdict |
|---|---|---|---|
| Fill | `var(--paper)` | `AppColors.paper` | Match |
| Border | `2.5px solid ink` | `2.5` width, `AppColors.ink` | Match |
| Radius | `18px` | `18` | Match |
| Shadow | `0 4px 0 ink` | `Offset(0,4)`, ink, blur 0 | Match |
| Padding | `9px 22px` (vert/horiz) | `horizontal: 20, vertical: 6` | **Off** — vertical too tight (6 vs 9), horizontal slightly under (20 vs 22) |
| Number size/weight | `40px / 700` | `40 / w700` | Match |
| Number `line-height` | `1` (explicit) | not set (platform default line-height) | **Off** — Flutter's default line-height is taller than 1, which can visually unbalance the padding above even when padding itself is fixed |

**Fix both:** padding → `EdgeInsets.symmetric(horizontal: 22, vertical: 9)`; add `height: 1.0` to the number's `TextStyle`. Lower priority than §2.1/§2.2 per the founder's own ranking, but trivial to fix while touching this widget, so do it in the same pass.

---

## 3. Full restructured layout (`play_screen.dart`, `RunPhase.playing` branch)

The prior four-way `Expanded(flex: 20/20/10/50)` Column is replaced. The mockup's own `.screen` is a `flex-direction:column` with exactly **one** `flex:1` child (the middle content wrapper) and everything else sized to its own content — match that structure, not an even flex split.

```
┌─────────────────────────────┐
│  Run 1            Deaths 0  │  ← chips row (fixed, content-hugging)
│ ╭───────────────────────╮   │
│ │▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░│   │  ← life bar, 12dp tall (fixed)
│ ╰───────────────────────╯   │
│  Life 47%          ±80ms    │  ← meta row, BELOW the bar
│                              │
│           Tap at             │
│         ╭─────────╮          │  ← Expanded(flex:1) — the only
│         │  16.00   │          │     flexible zone; absorbs all
│         ╰─────────╯          │     remaining vertical space
│      [DELTA/BAND — debug]    │     (numplate + optional flash
│                              │     pill + debug-only readout)
│                              │
│   [Hit +2%]   [Miss -4%]    │  ← legend pills, own row, ABOVE
│  ╭─────────────────────╮    │     the button (not inside it)
│  │  TAP                 │    │  ← compact button, 88dp fixed
│  │  land on the number  │    │     height, full width
│  ╰─────────────────────╯    │
└─────────────────────────────┘
```

### 3.1 Chips row (new — §2.1)

```dart
Padding(
  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: const [
      _Chip(label: 'Run', value: '1'),
      _Chip(label: 'Deaths', value: '0'),
    ],
  ),
)
```

Not wrapped in `Expanded` — sizes to its own content (chip height ≈ padding + 10sp text).

### 3.2 Life bar block (corrected order + thickness — §2.4)

```dart
Padding(
  padding: const EdgeInsets.only(left: 16, right: 16, top: 10),
  child: Column(
    children: [
      _LifeBar(lifePct: runState.lifePct),   // height: 12 (was 20)
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Life ${runState.lifePct.round()}%',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: AppColors.splashTagline)), // #3F5651 — matches
                  // .lifemeta's color exactly; reuse the existing token
                  // rather than adding a new one.
          Text('±${TimingConfig.onPointMs}ms',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: AppColors.splashTagline)),
        ],
      ),
    ],
  ),
)
```

Not wrapped in `Expanded` — fixed content-hugging height.

### 3.3 Center content zone (was Zone B/C — indicator removed, §2.3)

```dart
Expanded(   // the ONLY Expanded in this Column
  flex: 1,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Stack(
      alignment: Alignment.topCenter,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Tap at', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: AppColors.teachBody)),  // was AppColors.mute — mockup's
                // "Tap at" label color is #4a5f5a, which is AppColors.teachBody,
                // not AppColors.mute (#7b8a86). Fix while restructuring.
            const SizedBox(height: 4),
            _Numplate(targetSeconds: targetSeconds),  // padding/line-height fixed, §2.5
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              Text('DELTA: ${runState.lastDeltaMs == null ? '—' : '${runState.lastDeltaMs} ms'}'),
              Text('BAND: ${_bandLabel(runState.lastBand)}'),
            ],
            // NOTE: no IndicatorWidget here anymore — deleted per §2.3.
          ],
        ),
        if (flashBand != null)
          Positioned(top: 0, child: _FlashPill(band: flashBand)),
      ],
    ),
  ),
)
```

The debug-only DELTA/BAND readout (previously its own `Expanded(flex: 10)` "Zone C" row) is folded into this same flexible zone, still `kDebugMode`-gated, so release builds match the mockup exactly (no dead row) and debug builds keep the telemetry available to `tester`/`flutter-developer`.

### 3.4 Bottom control bar (was Zone D — resized + pills relocated, §2.2)

```dart
Padding(
  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LegendPill(label: 'Hit ${_formatSignedLifeDelta(TimingConfig.onPointLifeDelta)}%'),
          const SizedBox(width: 10),
          _LegendPill(label: 'Miss ${_formatSignedLifeDelta(TimingConfig.missLifeDelta)}%'),
        ],
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 88,               // fixed — §2.2's derivation
        width: double.infinity,
        child: TapSurface(         // Listener mechanism unchanged — §0
          clock: clock,
          onTapMicros: /* unchanged handler */,
          child: _TapZone(flashBand: flashBand),  // now contains ONLY
              // "TAP" + "land on the number" — legend pills removed from
              // this widget's Column, they live in the Row above instead.
        ),
      ),
    ],
  ),
)
```

`_TapZone`'s internal build loses its trailing `Row` of legend pills (currently its last child) — everything else about its decoration (coral fill / flash-color-on-tap, 2.5dp ink border, radius 22, flat shadow `Offset(0,6)`, "TAP" + shadowed text, "land on the number" caption) is unchanged, since that chrome already matches `.tapbtn` and isn't part of any confirmed gap.

Legend pill values stay sourced from `TimingConfig.onPointLifeDelta`/`missLifeDelta` (already correct in the current build) — **do not** switch to the mockup's literal "+2%"/"35%" copy, for the same correctness-over-cosmetics reason as the tolerance readout (§2.4): those literal mockup digits don't match `timing_config.dart` and would visually misrepresent the real, tunable band values.

---

## 4. Files/changes summary

| File | Change |
|---|---|
| `lib/features/run/play_screen.dart` | Column restructured: single `Expanded(flex:1)` center zone replaces the old 20/20/10/50 flex split (§3). New `_Chip` widget + chips row, hardcoded `'1'`/`'0'` (§2.1/§3.1). `_LifeBar` height 20→12; meta row moved below the bar, copy "LIFE: {n}%" → "Life {n}%", color `mute`→`splashTagline` (§2.4/§3.2). "Tap at" label color `mute`→`teachBody` (§3.3). `_Numplate` padding/line-height fix (§2.5). `IndicatorWidget` usage removed (§2.3/§3.3). Debug DELTA/BAND readout relocated into the center zone, still `kDebugMode`-gated (§3.3). Legend pills moved out of `_TapZone` into their own `Row` above a `SizedBox(height: 88)`-constrained `TapSurface` (§2.2/§3.4). |
| `lib/features/timing_engine/indicator_painter.dart` | Deleted (or left fully unreferenced, at minimum) — no remaining importers once `play_screen.dart` is updated (§2.3). |
| `lib/features/run/countdown_view.dart` | No changes (§1). |
| `lib/core/timing_config.dart` | No changes — read from only. |
| `lib/core/theme.dart` | No changes — `AppColors.splashTagline`/`teachBody` already exist; reused, not added. |
| `lib/features/run/run_controller.dart` | No changes — the Run/Deaths chips are deliberately hardcoded literals, not backed by new state (§2.1). |

---

## 5. "Done when"

On a real Android device, the neutral/hit/miss states show: a Run/Deaths chip row at the top (hardcoded "Run 1" / "Deaths 0", pill-shaped, paper-fill, ink-bordered, bold numbers); a 12dp-thin life bar with the "Life {n}%" / "±{TimingConfig.onPointMs}ms" meta row sitting below it, not above; a numplate with corrected padding; no visible moving indicator/progress lane anywhere, and `indicator_painter.dart` either deleted or unreferenced; a compact 88dp-tall, full-width tap button with the Hit/Miss legend pills in their own row directly above it, not inside its content column. The `Listener`-based tap capture, the strictly-downstream flash logic, and the countdown's wall-clock deferred-start `Timer` are all provably untouched by this pass (no diff to `tap_surface.dart`'s pointer handling, `run_controller.dart`'s `registerTap`, or `countdown_view.dart`'s timer setup). Nothing above required an `outcome_resolver.dart` stub, a `RunPhase` change, or a `GestureDetector`/`StickerButton` swap.
