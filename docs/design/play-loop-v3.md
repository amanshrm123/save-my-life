# Play Loop — v3 (five founder changes, visual/interaction spec)

*Companion spec to `docs/architecture/v3.md` (read in full; this doc fills exactly the visual/interaction blanks v3 explicitly left for `game-ux-designer`, per v3 §7.4/§9). Visual language re-read before writing anything here: `docs/design/play-loop-v2.md` (the current pixel-fidelity build) and `docs/design/screen-library-v3-2.html` id="b" (2.2–2.4, plus 3.1's death card for tone reference only — not reused wholesale, see §3 below). Every color, shadow, radius, and font weight below is pulled from that existing system; nothing new is invented. Current build read against: `lib/features/run/play_screen.dart`, `lib/core/theme.dart`, `lib/core/widgets/sticker_button.dart`, `lib/features/timing_engine/tap_surface.dart`.*

**What this doc does NOT re-litigate** (v3's founder-confirmed calls, treated as locked):
- Death-only cycle-end, no Survived/"life saved" this pass (v3 §3.1).
- The death state is an intentionally bare placeholder — not a designed card (v3 §3.5). §3 below gives it just enough concrete layout to be buildable, deliberately no more.
- Both the numplate and the bottom button are tap targets, sharing one handler (v3 §6.2).
- Perfect fixed +3%; On-point/Miss ranged, whole-integer rolls (v3 §4.1).
- The flight mechanism itself — `AnimationController` + `Tween<Offset>` between two `GlobalKey`-resolved anchors, in a `Stack` overlay, firing strictly after `registerTap()` resolves (v3 §7.2/§7.3). This doc supplies the *exact numbers* v3 asked for; it does not touch the ordering rule, the `GlobalKey`/`RenderBox` mechanism, or the Gate-1 ban on animating anything else.

---

## 1. The flying result pill (item 5 — v3 §7)

### 1.1 What travels, and what doesn't

One pill. No trail, no particles, no secondary element. The pill's own chrome is **unchanged from the current static `_FlashPill`** — reused exactly, not restyled for motion:

```dart
// unchanged from play_screen.dart's existing _FlashPill:
padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
decoration: BoxDecoration(
  color: band == miss ? AppColors.red : AppColors.green,
  border: Border.all(color: AppColors.ink, width: 2.5),
  borderRadius: BorderRadius.circular(999),
  boxShadow: [BoxShadow(color: AppColors.ink, offset: Offset(0, 4), blurRadius: 0)],
),
// text: fontSize 13, w700, white — copy sourced from runState.lastLifeDelta
// per v3 §4.3 ("PERFECT +3%" / "ON POINT +2%" / "MISS -4%"), not
// TimingConfig constants anymore.
```

A flat-shadow, hard-edged sticker chip in motion reads as "one solid object jumping," which is the right amount of juice for a feedback pill — motion blur or a trail would make it look like a *projectile with a wake*, which is a different (richer) idea than what was asked for and is explicitly out of scope (v3 §7.5). Don't add either.

### 1.2 Exact timeline — total 460ms

One `AnimationController(duration: Duration(milliseconds: 460))`, driving three curves off the same controller:

| Phase | Window | Duration | What moves |
|---|---|---|---|
| **Launch** | 0–50ms | 50ms | Opacity 0→1, scale 0.85→1.0, both `Curves.easeOut`. Position tween is already running underneath (see Travel row) — launch and travel overlap; this is deliberate, it's what makes the pill feel like it *peels off* the button rather than materializing then moving. |
| **Travel** | 0–260ms | 260ms | Position: `Tween<Offset>` (see §1.3), `Curves.easeOut`, expressed as `CurvedAnimation(parent: controller, curve: Interval(0.0, 0.565, curve: Curves.easeOut))` (0.565 × 460 ≈ 260ms). Interval's curve holds its output at 1.0 for any `t` past 0.565, so position is automatically pinned at the arrival point for the rest of the timeline — no extra clamping logic needed. |
| **Dwell** | 260–370ms | 110ms | Nothing moves. Full opacity, full scale, pinned position. This is the "read the result" beat. |
| **Fade-out** | 370–460ms | 90ms | Opacity 1→0, `Curves.easeIn`. Position and scale stay pinned — it fades in place, it does not shrink or pop. |

Implement opacity and scale as `TweenSequence`s on the same controller (weights sum to 100, matching the ms breakdown above: 10.9 / 69.5 / 19.6):

```dart
final opacity = TweenSequence<double>([
  TweenSequenceItem(weight: 10.9, tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut))),
  TweenSequenceItem(weight: 69.5, tween: ConstantTween(1.0)),
  TweenSequenceItem(weight: 19.6, tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn))),
]).animate(controller);

final scale = TweenSequence<double>([
  TweenSequenceItem(weight: 10.9, tween: Tween(begin: 0.85, end: 1.0).chain(CurveTween(curve: Curves.easeOut))),
  TweenSequenceItem(weight: 89.1, tween: ConstantTween(1.0)),
]).animate(controller);
```

**Why 460ms, not the ~400–450ms starting recommendation:** travel is tightened slightly (260ms vs the suggested ~280ms) to fund a clean 90ms fade-out instead of a hard cut — the old `_FlashPill` disappeared via a blunt 120ms `Timer`, which was a limitation of the state-provider approach, not a deliberate design choice. Since the controller is already driving opacity for the launch, a matching fade-out costs nothing extra to add and reads much better than a snap-to-gone. Net total is 10ms over the upper end of the starting estimate — still well inside "feedback, not a cutscene," and, given the shortest possible gap between two *organic* taps is 3 real seconds (the target re-rolls over a 3–20s window, `run_controller.dart` `_minTargetDurationMicros`), 460ms is nowhere close to blocking the next scored round. The one case where it matters is deliberate spam-tapping — covered in §1.5.

### 1.3 The travel path — effectively vertical, not diagonal

Architecture frames this as a `Tween<Offset>` between two independently-resolved `GlobalKey` anchors, which reads as general 2D motion. In this layout it collapses to one dimension: **the numplate and the tap button are both horizontally centered, full-width elements in the same single-column layout**, so their `GlobalKey`-resolved centers share the same X coordinate. Flutter-developer can implement this as a `Tween<double>` on Y, wrapped in `Positioned(left: 0, right: 0, top: animatedY, child: Center(child: pill))` — simpler than general offset math, while still deriving `animatedY` from real `RenderBox` positions (never a hardcoded pixel), which is the actual reason architecture wanted `GlobalKey`/`RenderBox` measurement in the first place (cross-device correctness, not diagonal motion for its own sake).

**Anchor points, both measured from the pill's own bottom edge** (the pill's height is constant across all three band labels — only its width varies with text length — so bottom-edge anchoring keeps a single consistent reference point through the whole flight):

- **Launch anchor:** pill's bottom edge sits **4dp above the tap button's top edge** (`GlobalKey` on the button's visible content box, i.e. the `SizedBox(height: 88)` / `_TapZone` container). Reads as "popping off the button."
- **Arrival anchor:** pill's bottom edge sits **40dp above the numplate's top edge** (`GlobalKey` on `_Numplate`'s container). This is deliberately *not* the tight 12–14dp gap you'd get from just clearing the numplate's border — the "Tap at" label sits only ~4dp above the numplate with its own ~16dp line height, so a tight gap risks the arriving pill overlapping that label. 40dp clears the whole "Tap at" + numplate cluster with margin, landing the pill in the same general neighborhood the old `Positioned(top: 0)` pill occupied, just tied to a real anchor instead of an arbitrary flex-zone edge.

This also resolves a possible worry cleanly: because the pill arrives *above* the numplate rather than centered on it, a new target number rolled in mid-flight (the controller re-rolls `targetDurationMicros` inside `registerTap`, before the animation even starts) is never obscured by the settling pill — the digits stay fully legible the entire time.

### 1.4 The old static pill and the button wash

Delete the current `Positioned(top: 0, child: _FlashPill(band: flashBand))` from the center zone's `Stack` entirely — the flight layer's arrival state *is* the new result display; there must never be two pills rendered.

**The button's coral→green/red color wash stays exactly as-is, on its own independent 120ms clock** — do not couple it to the new 460ms pill timeline. `tapFlashBandProvider` + `_pendingFlashClearTimer` keep driving `_TapZone`'s fill/text-shadow exactly as today; the new `AnimationController` is a second, independent trigger reading the same tap result at the same moment. Architecture already calls these "coexisting, no conflict" (v3 §7.3) — the wash is the instant launch flash, the pill is the sustained readout; they don't need to end at the same time, and re-tuning the wash's duration is not part of this ask.

### 1.5 Re-tap behavior — snap away, never queue

Every tap runs the same `onTapMicros` handler regardless of the controller's current status. The handler always calls `controller.forward(from: 0.0)` after updating the pill's band/text to the new result. No special-casing "is it mid-flight" — `forward(from: 0)` is a single value reset:

- If the controller was idle (previous flight finished), this is just a normal fresh launch.
- If the controller was mid-flight, the value resets to `0.0` synchronously — the in-flight pill's opacity snaps to `0` and its position snaps to the launch anchor **within the same frame**, then the same 460ms sequence begins again, now showing the new tap's band/color/text.

**This is a snap-away, not an abbreviated completion.** The previous pill does not finish its flight, does not cross-fade, and does not blend with the new one — it disappears and a fresh pill launches from the button. This is the simpler of the two options v3 raised and the more honest one: attempting to "complete an abbreviated version" of the interrupted flight adds real edge-case surface (what happens on a *third* tap 20ms later?) for no clarity benefit, since the player's attention is on the newest result anyway.

**Flag for `tester`:** deliberately spam-tapping the numplate/button faster than ~460ms apart is expected to look like a rapid flicker of pills relaunching from the button — that's correct behavior per this spec, not a bug. Worth an explicit pass confirming it doesn't look broken under real fast-tap abuse, since it's the one scenario where the timeline in §1.2 is actually stressed.

### 1.6 Load-bearing implementation note: the overlay must not eat taps

The flight layer sits in a `Stack` above the existing Column so it can travel across regions that belong to different parts of that Column. Whatever wraps the pill in that top layer (`Positioned` + `Center` per §1.3) **must not intercept pointer events** — wrap it in `IgnorePointer` (or ensure the `Positioned`/`Center`/pill subtree simply has no hit-testing surface, which is true by default for `Text`-in-`Container` as long as nothing adds a `GestureDetector`/`Listener` there). If this is missed, a pill drifting over the numplate's tap-target region mid-flight would silently intercept taps meant for the second `TapSurface` described in §2 — a real regression to the item-3 ergonomics work, not just a cosmetic bug. This isn't spelled out in architecture's §7.3 and is worth flagging explicitly since it's easy to miss.

---

## 2. The numplate's tap-target treatment (item 3 — v3 §6.2)

### 2.1 No dedicated pressed-state affordance — the call

**No new visual treatment on the numplate.** It keeps its exact existing chrome: `paper` fill, 2.5dp ink border, radius 18, flat shadow `Offset(0, 4)` ink, no hover/press-state change.

Reasoning: every genuinely-pressable surface in this visual system — `.cta`, `.tapbtn`, `.btn`, `.ghostbtn`, `StickerButton` — shares one recipe: a solid fill, an ink border, and a flat offset drop-shadow with zero blur. The numplate *already has that exact recipe* (it's visually identical in construction to a button, just currently non-interactive). Making it tappable doesn't require it to look different, because it already speaks this system's established "this is a pressable card" visual language. Adding a distinct pressed/active state on top of that would also require *some* form of visual feedback timed to the touch — which, per Gate 1 (still in force outside the one pill this pass authorizes), means an `AnimationController` on a second element. That's explicitly not authorized here. **Do not add one.** The bottom button's existing "TAP / land on the number" copy plus the flying pill now visibly originating at the button and arriving at the numplate is enough teaching; a static-only affordance change isn't needed on top of that.

### 2.2 Hit area — exact padding

Numplate's own rendered box, from its existing spec (`play-loop-v2.md` §2.5): padding `horizontal: 22, vertical: 9`, border 2.5dp, 40sp/700 text at `height: 1.0`. That yields an *approximate* content box of ~63dp tall × ~150dp wide (varies slightly with the digit string), comfortably below the 48dp minimum on its own for width but only barely above it on height, and the actual glyph area is smaller still.

**The call:** wrap the numplate in a second `TapSurface`, with the numplate padded inside it by **`EdgeInsets.symmetric(horizontal: 28, vertical: 24)`** before the `Listener` boundary:

```dart
TapSurface(
  clock: clock,
  onTapMicros: onTapMicros, // the SAME handler passed to the bottom button
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
    child: _Numplate(targetSeconds: targetSeconds),
  ),
)
```

This yields an effective hit box of roughly **~111dp tall × ~206dp wide** — well above the 48dp minimum on both axes, and generously larger than the numplate's own visual bounds (the number *looks* like the target, the actual tappable region is the padded card-plus-whitespace around it, per v3 §6.2's "forgiving" instruction). The 24dp vertical padding is intentionally generous relative to the 28dp horizontal padding because the numplate's own box is already close to the minimum on height; the asymmetry keeps the two axes landing at comparable, both-generous final dimensions rather than one axis just barely clearing 48dp.

The `Listener`'s `HitTestBehavior.opaque` covers the full padded box, so the tappable region visually extends into the surrounding whitespace above/below/around the number — this is fine, nothing else in that zone competes for the tap (the "Tap at" label and the debug-only DELTA/BAND text are not tap targets).

---

## 3. The bare death placeholder (item 1 — v3 §3.5)

### 3.1 Full-screen replacement, not a modal overlay

v3 §3.5's wording ("a simple centered overlay") is read here as *a screen*, not a dialog stacked on top of the still-mounted Play UI. **The call: `PlayScreen` gets a third early-return branch, structurally identical to today's `if (phase == countdown) return CountdownView();` pattern:**

```dart
if (runState.phase == RunPhase.dead) {
  return _DeathPlaceholder(deathCount: runState.deathCount);
}
```

Reasoning: the eventual outcome card (Days 6–11) is itself a full-screen replacement (`.card-screen` occupies the whole phone body in the mockup, not an overlay on the play state) — building the placeholder the same way now means zero structural rework when it's swapped out later. It also avoids the pointless cost of keeping a now-stale life-bar/numplate/button tree mounted and rendering behind a scrim for no reason. No dimming scrim, no modal chrome (that's the `.overlay`/`.modal` recipe used for Pause, §2.6 of the mockup — reserved for that later, unrelated feature; do not reuse it here).

### 3.2 Layout — exact, and genuinely minimal

```dart
class _DeathPlaceholder extends StatelessWidget {
  const _DeathPlaceholder({required this.deathCount});
  final int deathCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,   // same background as the rest of Play — no new surface
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'You died',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 14),
              _Chip(label: 'Deaths', value: '$deathCount'),   // reused verbatim, same widget as the top bar
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => ref.read(runControllerProvider.notifier).startNewCycle(),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14), // ensures >=48dp tap height
                  child: Text(
                    'Play again',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- **Headline: "You died"** — plain, no punctuation flourish, no badge pill/icon (the outcome card's `.badge.death` chrome with the skull glyph is a *designed* element reserved for the real card; reusing it here would make the placeholder look more finished than it's supposed to be). 22sp/700/ink — a step up from the teaching-card headline size (17sp) since it's the sole focal element on an otherwise-empty screen, but nowhere near splash-screen scale.
- **Death count: reuse `_Chip` verbatim**, same widget class already built for the top bar (`_Chip(label: 'Deaths', value: '$deathCount')`). Zero new visual vocabulary — this is the "reuse chip style" option, chosen specifically because it costs nothing new to build and is already wired to the same data.
- **"Play again": a plain underlined text link, not a `StickerButton`/`.cta`/`.ghostbtn` treatment.** This is the deliberate middle ground: a full colored CTA card (border + flat shadow + fill) would be more "designed" than a placeholder should be — the whole point is that the real outcome card replaces this wholesale. But unlike onboarding's "Skip for now" link (mute-gray, tiny 11sp, a *secondary* de-emphasized action), "Play again" here is the *only* action on the screen — rendering it as low-contrast mute text risks looking unstyled/broken rather than intentional. **Compromise: ink-colored (not mute), 16sp, bold, underlined** — reads clearly as "this is a tappable link," carries visual weight appropriate to being the sole CTA, but has no container chrome at all. `GestureDetector` (not `Listener`) is correct here — this is ordinary UI navigation, not the latency-critical tap-capture path, so the Listener-only rule doesn't apply (the same reasoning that already lets onboarding's CTAs use `GestureDetector`/`StickerButton`).
- Padding around the "Play again" text (`horizontal: 24, vertical: 14`) exists purely to guarantee a ≥48dp tap height on the invisible hit box, without adding any visible button chrome.

### 3.3 Explicit non-scope, restated

No death-line copy pool, no per-death flavor text, no art, no share button, no "Death #N of 1000" framing (that's the real card's `.cardbox death .no` line, backed by content that doesn't exist yet). If this looks *too* plain when built — that's correct. It's meant to look like a stub, because it is one.

---

## 4. Legend pills showing ranges (item 4 — v3 §4.3)

### 4.1 Exact string format

**`Hit +2 to +3%`** and **`Miss -5 to -3%`** — spelled-out "to" for both, not a dash shorthand. Two reasons for "to" over a compact `+2-3%`/`-5–-3%` form:

- **Miss's range is negative-to-negative.** A dash-joined `-5-3%` (or `-5–3%`) is genuinely ambiguous at a glance — does it read as "−5 to −3" or "minus five-dash-three"? Spelling "to" removes the ambiguity entirely.
- **Consistency between the two sibling pills matters more than either being maximally compact on its own.** Using "to" for Miss but a dash-shorthand for Hit would read as two different formatting conventions sitting side by side in the same row — using "to" for both keeps them visually and cognitively parallel.

Ordering is ascending for both (matches `TimingConfig`'s own min→max naming): Hit is `onPointLifeDeltaMin` → `onPointLifeDeltaMax` (`+2` then `+3`); Miss is `missLifeDeltaMin` → `missLifeDeltaMax` (`-5`, the more negative bound, then `-3`, the less negative one) — this is architecture's own example ordering (v3 §4.3) and is worth keeping exactly, since "worse outcome first" reads naturally as "how bad can it get, at best how bad."

### 4.2 Implementation — small helper, no new widget

```dart
String _formatLifeDeltaRange(double min, double max) =>
    '${_formatSignedLifeDelta(min)} to ${_formatSignedLifeDelta(max)}%';

// Legend row:
_LegendPill(label: 'Hit ${_formatLifeDeltaRange(TimingConfig.onPointLifeDeltaMin, TimingConfig.onPointLifeDeltaMax)}'),
_LegendPill(label: 'Miss ${_formatLifeDeltaRange(TimingConfig.missLifeDeltaMin, TimingConfig.missLifeDeltaMax)}'),
```

Full rendered text: `"Hit +2 to +3%"` (13 chars) and `"Miss -5 to -3%"` (14 chars). `_LegendPill`'s existing chrome (paper fill, 1.5dp ink border, radius 999, 11sp/600 text, `horizontal: 10, vertical: 4` padding) is unchanged — at this font size and pill padding, both strings fit on a single line with comfortable margin inside the pill row's available width on every supported phone size (checked against the narrowest realistic target, ~320–360dp logical width); no wrapping risk, no need to shrink font or padding to accommodate the longer strings.

---

## 5. Run/Deaths chips with real data (item 1 — v3 §3.2)

**No visual change to the chip shell.** `_Chip` stays exactly as built — `paper` fill, 2dp ink border, radius 999, label + bold value, `horizontal: 10, vertical: 4` padding. Only the values become provider-backed (`runState.deathCount + 1` for Run, `runState.deathCount` for Deaths — architecture's own §3.2 mapping, not a new design decision).

**No fixed minimum width needed, and here's why it's not required:** the chips row is `Row(mainAxisAlignment: MainAxisAlignment.spaceBetween)` with exactly two children and nothing between them. `spaceBetween` pins the first child to the row's start edge and the last child to its end edge *regardless of either child's own width* — so as death counts grow from single to multi-digit ("Deaths 0" → "Deaths 128"), each chip simply grows slightly in place at its own pinned edge; the row doesn't reflow or visually "jump," it's just each chip's own content getting a touch wider, snapping instantly on rebuild exactly like the life bar's width already does elsewhere in this build (no animation, consistent with the rest of this pass). At any death count a player will realistically reach in a session, the combined width of both chips plus the 16dp side padding stays far under typical phone widths — genuinely not a risk worth adding width-clamping code for.

---

## 6. Files/changes summary (design-relevant only — full list is v3 §8)

| File | What this doc adds beyond v3's architecture-level description |
|---|---|
| `lib/features/run/play_screen.dart` | Exact flight timeline/anchors (§1); numplate `TapSurface` wrap with `28h/24v` padding, no new numplate chrome (§2); `_DeathPlaceholder` widget + exact copy/layout (§3); legend pill range string format + helper (§4). Old static `Positioned(top:0, _FlashPill(...))` removed — replaced by the flight layer's arrival state, never both. |
| `lib/core/theme.dart` | No changes — every color used above (`ink`, `paper`, `green`, `red`, `coral`, `coralDark`) already exists. No new tokens needed for this pass. |
| `lib/core/widgets/sticker_button.dart` | Not used for "Play again" — deliberately not reused here (§3.2). |

---

## 7. "Done when"

On a real device: a tap on the bottom button *or* the padded region around the numplate scores identically. A single pill launches from the button, travels ~260ms with an ease-out curve, dwells fully visible for 110ms above the "Tap at"/numplate cluster (never overlapping either), then fades out over 90ms in place — total 460ms, never a hard cut. A second tap mid-flight instantly relaunches the pill from the button showing the new result; nothing queues, nothing blends. The numplate itself never changes appearance on press. Tapping through the death placeholder shows "You died," the reused `_Chip` "Deaths" pill with the real persisted count, and an ink-colored underlined "Play again" text link that calls `startNewCycle()` — no card chrome, no share, no per-death copy. The legend pills read "Hit +2 to +3%" / "Miss -5 to -3%" without wrapping. The Run/Deaths chips show live values with the existing chip shell, unchanged, and don't visually jump around as digit counts grow.

---

## 8. Flags / concerns for `flutter-developer` and `founder`

1. **§1.6 (overlay hit-testing) is the one genuinely load-bearing catch in this doc.** If the flight layer's `Positioned`/pill subtree isn't wrapped so it never intercepts pointer events, a pill drifting over the numplate mid-flight would silently break the second tap surface from item 3 — worth a specific test pass, not just a visual check.
2. **§1.5's spam-tap flicker is expected, not a bug** — flagging it explicitly so `tester` doesn't file it as a regression. If, after seeing it on-device, it reads as genuinely annoying under realistic (non-spam) play, the fix is shortening the dwell/fade-out, not changing the snap-away restart logic itself.
3. **460ms vs. architecture's ~400–450ms starting estimate** — a deliberate, small (10ms) overshoot to fund a fade-out instead of a hard cut (§1.2). Flagging it since it's a number this doc changed from the architecture doc's suggestion, per the hand-off boundary in v3 §7.4 ("designer tunes").
4. **No numplate press-affordance** (§2.1) is a real design call, not an oversight — if on-device testing shows players genuinely don't discover the numplate is tappable, the fix should be copy/onboarding (e.g. a teaching-card mention), not a second animated element, since the latter re-opens the Gate-1 ban this pass deliberately keeps closed everywhere except the one pill.
5. **Everything in §3 (death placeholder) is intentionally unfinished-looking.** If it comes back from review as "make it feel more designed," that's a Days 6–11 outcome-card conversation, not a note to act on here — restated because this project's own culture is to flag scope pressure explicitly rather than quietly absorb it.
