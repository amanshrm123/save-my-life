# Stay Alive — Play Loop & In-Run States Visual & UX Spec v2

**Scope:** a revision of `docs/design/play-loop-v1.md`, driven by the product-architect's decision doc responding to 7 pieces of founder feedback (Run count copy, Deaths chip removal, merged center+bottom action button, auto-miss timeout, avatar life-meter replacing the horizontal life bar). **This doc documents only what changed.** Anything not mentioned here — countdown mechanics, the Running/Stopped numplate outline-vs-filled rule, legend pills, the pause overlay, juice/haptics timing, platform conventions, responsive baseline — is unchanged from v1 and should be read there; this doc does not re-derive it.
**Consumes:** the architect's binding decision doc (pasted in the handoff, not duplicated here) plus two founder-confirmed judgment calls: button height stays capped at 260dp max (not literal 1/3-screen), and the avatar life-meter uses percent-band color only via the existing `avatarFillColorForPercent` (no tier-tint flash, no hard-locked red override in the final band).
**Consumed by:** `flutter-developer` (build from this doc + v1 for unchanged parts) and a later `game-ux-designer` verification pass (§5).

Design spec, not code — no Dart. Flutter mechanisms named below describe an effect to reach for, not literal syntax.

---

## Revision summary

Three structural changes to the Play Loop HUD, all in service of one goal — kill the "hunt for the right button" feeling the founder called out. **(1)** The Deaths chip is removed from the in-run HUD entirely; the topbar is now Run chip + pause icon only. **(2)** The center gold "STOP AT" plate and the bottom coral/red STOP button — previously two separate widgets the player's eye had to jump between — are merged into a single bottom-docked button with four visual "looks" (`PrimaryActionLook`): it's gold and says "STOP AT `<target>`" before a run starts, then reskins in place to coral/red and says "STOP" once it's live. The center area, freed of the plate, now shows a single teaching line pointing at the button below. **(3)** The old two-piece HUD (chips row + separate horizontal life bar) is replaced by one combined row: the player's own avatar figure (reusing Home's `AvatarFigure` painter) as a life-meter, with the Run chip/pause button/life caption arranged beside it. Net effect: fewer discrete widgets, one obvious primary action, and the avatar (already the player's emotional anchor on Home) now does double duty as the in-run life gauge. A behavioral-only change (auto-miss timeout) is also noted for the record in §4; it has no visual spec impact.

---

## 1. Top HUD row — avatar life-meter (replaces chips row + `LifeBar`)

### 1.1 What's gone

- The **Deaths chip** — removed outright, no replacement (no "Survived"/"Eternal" counter added in its place; the architect was explicit this is a deletion, not a swap).
- The old two-row chrome (chips row, 28dp, + 10dp gap + horizontal `LifeBar`, 26dp = 64dp total per v1 §1.4) — replaced wholesale by the single row below.
- v1 §3.4's "transient tier-tint" and "persistent critical override" rules **for the fill color** — gone. The avatar fill is *always* `avatarFillColorForPercent(state.lifePercent)`, full stop (confirmed judgment call). The life-**caption** text rules are unchanged (see 1.4).

### 1.2 New combined row — 72dp tall

```
┌──────────────────────────────────────────────┐
│ ┌────┐                                        │
│ │ 🧍 │   [Run #12]                    ( ⏸ )   │  row a: chip + spacer + pause
│ │58w │                                        │
│ │x72h│   73% · next miss is fatal             │  row b: life caption (unchanged copy)
│ └────┘                                        │
└──────────────────────────────────────────────┘
   58dp    10dp gap        Expanded column
```

| element | spec |
|---|---|
| Outer row | `Row`, `crossAxisAlignment: center` — the avatar (72dp) is the tallest element; the text stack beside it (chip/pause line + 5dp gap + caption line, ≈46dp) is vertically centered against it. (Judgment call: the architect's spec doesn't pin vertical alignment; center reads better against a human figure than top-aligning a short text block.) |
| Avatar figure | `SizedBox(width: 58, height: 72)` -> `FittedBox(fit: BoxFit.contain)` -> `AvatarFigure(spec: AvatarCatalog.byId(selectedAvatarProvider), fillPercent: state.lifePercent, shouldAnimate: true)`. Painter's intrinsic size is 84x104 (`home-avatars-v1.md` §3.1); `BoxFit.contain` inside the 58x72 box preserves that aspect ratio without distortion. `shouldAnimate` is always `true` here (unlike Home, this screen has no visibility-gating concern — it's always the foreground route while a run is live). |
| Avatar fill color | `avatarFillColorForPercent(state.lifePercent)` — **exactly** Home's function: green `#2fbf71` >=60, coral `#ff7a59` >=20, else `redDark` `#b8362e` **(not** the brighter `AppColors.red` `#f0483e` used elsewhere in this screen's final-band reskin — see the flag below). |
| Never-picked edge case | `AvatarCatalog.byId(-1)` already falls back to a default spec (`AvatarCatalog.fallback`) rather than throwing — no empty/error state needed here, unlike `HomeAvatarCard`'s "Pick your look" hint (this is gameplay chrome, not a nav card; a player who somehow reaches Play without picking just sees the fallback figure). |
| Gap | 10dp horizontal, avatar -> text column |
| Row a (chip + pause) | `Run` chip (see §1.3) + `Spacer()` + pause icon button, all on one line. Pause button: **unchanged** — 28dp circle, 2dp ink border, paper fill, 12dp centered pause glyph (v1 §1.4) |
| Gap (row a -> row b) | 5dp (reuses v1's existing "life-meta caption margin-top 5dp" value verbatim) |
| Row b (life caption) | Same widget/copy as v1's life-meta caption, relocated — see §1.4 |
| Net height | chips(28)+gap(10)+bar(26) = 64dp -> new row = **72dp** (+8dp total). This is absorbed for free: nothing else on screen shrinks, because the bottom button's extra height comes out of the center `Expanded` slot, not this row. |

**Flag — a real, deliberate color asymmetry, not a bug:** the avatar's low-band fill is `redDark` (`#b8362e`), while the final-band reskin elsewhere on this same screen (STOP button's `stopFinal` look, the "last chance" text, the outlined-red numplate) uses the brighter `AppColors.red` (`#f0483e`). This is intentional and confirmed — the avatar's color rule is locked to Home's shared meaning (`avatarFillColorForPercent`) so the same fill color always means the same thing across the whole app, even though it now sits next to a screen that also uses a second, brighter red for its own "sudden death" reskin. Don't try to unify these two reds; they answer different questions (life-*band* vs. final-band-*event*).

### 1.3 Run chip copy — blessed as **"Run #12"**

Render the chip's label span as **`"Run #"`** (was `"Run "`) immediately followed by the bare number span (unchanged: 9dp/700 bold, no literal `#` in the number span). Net rendered string: **`Run #12`**. The `#` reads as an ordinal/identity marker ("this is run number twelve"), not a tally — matching the architect's ask. No other change to the chip: pill shape, `padding 3x9dp`, 2dp ink border, paper fill, 9dp/600 label weight, unchanged.

### 1.4 Life caption — copy unchanged, position only moves

The three existing copy/style variants carry over **verbatim**, just relocated to row b beneath row a, inside the same flexible text column, with `maxLines: 1` + ellipsis added (new — a defensive addition since the column is now narrower, sharing width with the chip/pause line above it rather than spanning the full HUD width alone):

1. Baseline (Armed/Running): `"Life N%"`, `hud-mute` (`#3f5651`), 9dp/600.
2. Stopped dwell (transient, text only — **not** the fill anymore, see §1.1): `"Life N% "` + colored arrow, **green ▲** (good) or **red ▼** (miss).
3. Critical (persistent while in the final band, including its terminal Stopped dwell): `"N% · next miss is fatal"`, red, 9dp/700 — replaces the arrow template entirely, same as v1.

---

## 2. Center content

### 2.1 Armed-phase — now a single teaching line (replaces the gold plate)

The gold "STOP AT" plate no longer lives here — it moved to the bottom button (§3, `armStart` look). The center focus area, in the `armed` phase, shows **only**:

> **"Tap below when you're ready."**

12dp, Fredoka w600, `AppColors.mute` (`#7b8a86`), one line, centered both axes (same flexible middle slot as v1 §1.3), 29 characters. This one line's entire job is to redirect the player's eye downward the first time the plate disappears from the center — it echoes the countdown's own "get ready" language (v1 §2.2's "First target drops when it hits zero.") rather than a clinical instruction, and stays out of the way once players internalize where the action lives.

**Final-band variant (`finalBandArmed`):** this neutral line is **replaced** (not supplemented) by the same red urgency line that already exists in `_RunningContent` — **"`<name>`, last chance"** / anonymous fallback **"Last chance"** — reused verbatim, same style (11dp/700, `AppColors.red`, height 1.1), for parity between the armed and running final-band frames. Resolution note: by the time a run reaches the final band the player has already survived several targets and knows where the button is, so the higher-priority danger message outranks the "tap below" teaching line here rather than stacking both.

### 2.2 Running / Stopped — unchanged from v1

`_RunningContent` and `_StoppedContent` (numplate outline-vs-filled rule, live `ValueNotifier` counting, flash-pill treatment, final-band reskin table) are **not touched by this revision** — see v1 §2.4–§2.7 and §3.3. Reference those sections directly; nothing here supersedes them.

### 2.3 Overflow-safety note (implementation plumbing, not a visual spec change)

The whole `_CenterContent` area gets wrapped in `FittedBox(fit: BoxFit.scaleDown)` as a safety net for small/short devices or large system text-scale. This doesn't change any of the numbers above — it only guarantees they degrade by shrinking-in-place rather than overflowing, on the rare device/settings combination where the fixed-size content (teaching line, numplate, flash pill) doesn't fit the available height.

---

## 3. Merged bottom button — `PrimaryActionLook`

One widget, one screen position (bottom-docked), four visual looks driven by run phase. This single element **is** the founder's fix for "hunting for a different button" — it should read as one thing that changes what it says, never as two different buttons swapping places.

### 3.1 Shared geometry (all four looks)

| property | value | note |
|---|---|---|
| Height | `(screenHeight / 3).clamp(150, 260)` logical dp | confirmed cap — not literal uncapped 1/3-screen |
| Width | fills available width | |
| Max width | 300dp | up from the old 260dp cap on both predecessor widgets |
| Border radius | 28dp | up from 22dp |
| Border | 2.5dp ink | unchanged |
| Shadow | hard offset, **ink** (always — see 3.2), `Offset(0, 6)` at rest / `Offset(0, 2)` pressed, `blurRadius: 0` | zero-blur sticker language, unchanged |
| Inner content | wrapped in `FittedBox(scaleDown)` | so large system text-scale can't overflow the fixed clamped height |

### 3.2 The one-shadow-rule deviation

Every look uses an **ink** shadow, including `armStart` — this is a deliberate change from v1's center plate, which used a non-standard `goldDark` shadow (v1 §1.5). Now that the gold look lives in the same merged widget as the coral/red looks, all four share one shadow rule rather than carrying the plate's one-off exception forward. Don't reintroduce `goldDark` here.

### 3.3 The four looks

| `PrimaryActionLook` | Trigger phase(s) | Fill | Line 1 | Line 2 | Tap behavior |
|---|---|---|---|---|---|
| **`armStart`** | `armed`, `finalBandArmed` | gold | `"STOP AT"` — 11dp/600, letter-spacing 0.06em, `ink @ 85%` opacity | `formatClock(target)` — **56dp/700 ink** (up from the old plate's 38dp) | tap starts the run (`startRunning()`) |
| **`stopNormal`** | `running` | coral | `"STOP"` — **34dp/700 white** (up from 15dp), 1.5dp `coralDark` text-shadow | `"stop as close to <target> as you can"` — 10dp/500 white | tap stops the run (`registerStop()`) |
| **`stopFinal`** | `finalBandRunning` | red | `"STOP"` — same 34dp/700 white treatment, 1.5dp `redDark` text-shadow | `"one clean stop saves you"` — 10dp/500 white | tap stops the run (`registerStop()`) |
| **`dwellDimmed`** | `stopped` (the ~600ms `flashDwellMs` window) | gold | `"STOP AT"` (same style as `armStart`) | the just-played target, **frozen** (same 56dp style) | **not tappable** — inert |

Line 2 copy for `stopNormal`/`stopFinal` is carried over unchanged from the current `_stopSubLabel` helper's running/final-band branches — no new copy there, just relocated into this widget. That helper's `armed`-phase branch (`'tap "Stop at" first to start'`) becomes dead code once `armStart` ships, since the button no longer shows a sub-label while armed (the teaching line moved to center content, §2.1).

**Why `dwellDimmed` is no longer visually "disabled":** v1's Stopped-dwell STOP button used 0.45 opacity to signal "don't tap, this won't do anything" (v1 §3.5). That convention doesn't carry forward — `dwellDimmed` shows the *next* target at full opacity, because its job changed: it's no longer "a live-looking button that's secretly inert," it's "a preview of what's coming next." The controller-level phase guard (`registerStop()` only acting during `running`/`finalBandRunning`) is the real protection against a stray tap in this window regardless of how the button looks.

---

## 4. Auto-miss timeout — behavioral note, no visual spec change

An attempt now always auto-resolves as a Miss ≈1.18s after it becomes numerically unavoidable (`target + hitBandMs (180ms) + autoMissGraceMs (1000ms, new `RunConfig` tunable)`), reusing the **exact same** Miss visual/audio/haptic treatment already specified for a manual Miss stop (v1 §2.6, §4 point 4) — nothing new to build visually. Record for the layout math only: the live counter's maximum realistic displayed value is now bounded (~7.18s at defaults, with the 2–6s target range), so v1 §6's numplate digit-width guidance (tabular figures, room for a 2-digit-seconds boundary crossing) no longer needs defensive slack beyond that single extra digit — there's no unbounded runaway number to plan for.

---

## 5. Verification checklist (for the eventual sign-off pass)

Per this repo's workflow rule, a `game-ux-designer` pass must confirm the built screen matches this spec exactly before it's considered done. Check:

1. **Deaths chip is genuinely gone** — not hidden, not zero-valued; the topbar/HUD row contains no Deaths chip in any phase, including Pause.
2. **Avatar renders correctly** — 58x72 box, correct aspect ratio (no stretching/squashing), correct percent-band color (green/coral/redDark) matching `avatarFillColorForPercent`, `shouldAnimate: true` (fill visibly tweens on life change, doesn't snap).
3. **No tier-tint flash and no hard-locked red override on the avatar fill** — confirm the fill color never deviates from the pure percent-band function, even immediately after a Stopped dwell or deep in the final band.
4. **Run chip renders exactly `"Run #12"`** (or the current run number) — not `"Run 12"`.
5. **All four `PrimaryActionLook` states render with correct fill/text per the table in §3.3**, and each one's tap does the correct thing for its phase (`armStart`/`dwellDimmed` vs `stopNormal`/`stopFinal` — confirm `dwellDimmed` truly does nothing on tap).
6. **Armed-phase teaching line is legible** (12dp mute grey, single line, no wrap/clip) and **correctly swaps** to the red "last chance"/"`<name>`, last chance" line the instant the run enters `finalBandArmed` — and back to the neutral line on the next non-final-band Armed.
7. **No overflow at a small device height** (test at a short/compact Android height) — confirm the `FittedBox(scaleDown)` wrappers on both the center content and the button's inner text visibly shrink rather than clip/overflow.
8. **The core ask — does this feel like *one* clear action, or do the two states still feel like hunting for a different button?** Specifically: watch the transition from `armStart` (gold, "STOP AT `<target>`") to `stopNormal` (coral, "STOP") as the same widget reskinning in place, not a swap between two separate elements. If a first-time player's eye has to search for where the button "went" at any transition, that's a fail against the founder's original complaint — flag it even if every individual number above is correct.

---

## 6. What still ships from v1 (unchanged — do not re-derive)

Countdown (§2.2), Running/Stopped mechanics and the outlined/filled numplate rule (§2.4–§2.7, §3.3), legend pills including the final-band single-pill swap (§3.2), the pause overlay and its modal pattern (§1.6, §2.8), Android back-button semantics (§3.7), all animation/juice recommendations (§4), platform conventions (§5), and responsive baseline (§6) — all reused as-is from `play-loop-v1.md`.
