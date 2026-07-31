# Stay Alive — Play Loop & In-Run States Visual & UX Spec v3

**Scope:** a revision of `docs/design/play-loop-v1.md` §2.3–§2.7 (per-phase screen specs) and §3.2 (legend pills), plus a reference (not a revision — nothing there changed) to `docs/design/play-loop-v2.md` §3 (the merged `PrimaryActionButton`). Driven entirely by `docs/architecture/v6.md`'s binary-scoring/`M:SS.CC`-clock reversal and its §12 "game-ux-designer" flag list, which this doc answers item by item (§4–§10 below map 1:1 to v6 §12 flags 1–8).
**Consumes:** `docs/architecture/v6.md` in full — its Decisions table (§0), the life-value table (§4.5), and its explicit layout-risk section (§8.4) are load-bearing inputs here and are not re-derived.
**Extends:** `play-loop-v1.md` (unchanged parts, esp. countdown §2.2, pause §2.8, cross-phase rules §3.1/§3.3/§3.5–§3.7, juice §4, platform conventions §5, responsive baseline §6) and `play-loop-v2.md` (unchanged parts, esp. the avatar-life-meter HUD row §1, the merged-button geometry §3.1–§3.2). **This doc documents only what v6 changed.** Anything not mentioned below is unchanged and should be read at its source.
**Also touches:** `docs/design/home-avatars-v1.md` §3.2/§3.5 — a small, non-code correction to that doc's recorded thresholds (§10 below); the actual code (`avatar_fill_band.dart`) is flutter-developer's change, not this doc's.
**Consumed by:** `flutter-developer` (build from this doc + v1/v2 for unchanged parts) and a later `game-ux-designer` verification pass (§11) — per CLAUDE.md rule 6, the built screens must match this doc exactly before the work is considered done.

Design spec, not code — no Dart files touched by this doc.

---

## 0. Recap: reused, not re-derived

- **Color tokens** (all already real `AppColors` members, hex-verified against `app_theme.dart`): `ink #1f2a2e`, `paper #fffdf7`, `coral #ff7a59`/`coralDark #e5613f`, `green #2fbf71`/`greenDark #1f9c58`, `red #f0483e`, `redDark #b8362e` (promoted from v1's flagged magic hex to a real token, already shipped), `gold #ffc23c`/`goldDark #e5a516`, `mute #7b8a86`, `bodyMute #4a5f5a`, `hudMute #3f5651`.
- **v2's merged-button geometry, unchanged by this pass:** height `(screenHeight/3).clamp(150, 260)`, max width 300dp, radius 28dp, border 2.5dp ink, shadow ink-only `Offset(0,6)`/`Offset(0,2)` pressed, inner `FittedBox(scaleDown)` kept as a safety net (not the primary sizing mechanism — see §4).
- **v2's avatar-life-meter HUD row, unchanged by this pass:** 72dp row, `LifeAvatar` 58×72 box via `FittedBox(contain)`, Run chip reading `"Run #12"`, pause icon 28dp, life caption's three copy/style variants (baseline / transient arrow / critical "N% · next miss is fatal"). Only the color-band **thresholds** feeding this row's fill change (§7) — nothing about its layout, copy, or animation wiring does.
- **v1's numplate outline/filled rule, unchanged:** Running = paper bg + colored border/shadow/digits; Stopped = solid color fill + white digits. Tabular figures (`FontFeature.tabularFigures()`) stay mandatory on the plate — non-negotiable now that there are more digits, not fewer.
- **Do NOT touch (explicit scope boundary, carried from the brief, not re-litigated here):** the life-caption's transient-tint-vs-persistent-critical-override *rule* (v1 §3.4/v2 §1.4, structurally unchanged), the pause overlay (v1 §2.8), the countdown screen (v1 §2.2), final-band urgency copy ("last chance"/"Last chance"), and anything Perfect-shaped — it's deleted, there is nothing left to spec.

---

## 1. What changed, in one paragraph

Two mechanical changes ripple through five places: (1) `formatClock` grows from 4 glyphs (`4:70`) to 7 (`0:04.70`), forcing explicit re-sizing at the two large-digit render sites instead of trusting `FittedBox` to absorb it invisibly; (2) the scoring/copy reversal (binary Hit/Miss, `TAP` verb, two legend pills, bare `HIT` pill, only-ever-drains life) changes text content and the avatar's color-band thresholds but touches no geometry beyond what (1) already covers. Everything below is one of those two things, or a direct knock-on of them (the Home avatar card and picker tiles sharing the rebased color function).

---

## 2. Revised §2.3–§2.7 — current merged wireframes

These four ASCII blocks supersede v1's originals. Each merges v1's baseline + v2's avatar-row/merged-button redesign + this doc's v6 changes into one current picture, so `flutter-developer` isn't reconstructing one screen from three documents. Inline `←v3` marks what this doc changes; everything else is v1/v2 carried forward unchanged.

### 2.3 Armed

```
┌────────────────────────────────────────────┐
│ ┌────┐                                      │
│ │ 🧍 │  [Run #12]                   ( ⏸ )   │  72dp avatar row (v2, unchanged)
│ │58x72│                                      │
│ └────┘  Life 50%                            │  life caption (v2, unchanged copy)
│                                              │
│         Tap below when you're ready.        │  center teaching line (v2, unchanged)
│                                              │
│         [Hit: safe]  [Miss: -10%]           │  ←v3 — 2 pills, new copy (§3)
│      ╭────────────────────────╮             │
│      │        TAP AT          │             │  ←v3 — was "STOP AT"
│      │       0:02.40          │             │  ←v3 — 44dp (was 56dp), 7 glyphs (§4)
│      ╰────────────────────────╯             │  gold, ink shadow (v2, unchanged)
└────────────────────────────────────────────┘
```

### 2.4 Running

```
┌────────────────────────────────────────────┐
│ ┌────┐                                      │
│ │ 🧍 │  [Run #12]                   ( ⏸ )   │  unchanged from Armed
│ └────┘  Life 50%                            │
│                                              │
│        Target 0:02.40                       │  ←v3 — M:SS.CC reading (unchanged style/size)
│         Running…                            │  unchanged (9dp/700 green-d)
│      ╭──────────────╮                       │
│      │   0:01.87     │                      │  ←v3 — 40dp digits (was 52dp), outlined green
│      ╰──────────────╯                       │
│                                              │
│         [Hit: safe]  [Miss: -10%]           │  ←v3
│      ╭────────────────────────╮             │
│      │         TAP             │            │  ←v3 — 34dp white, was "STOP"
│      │  "tap on the number"    │            │  ←v3 — was "stop as close to …"
│      ╰────────────────────────╯             │
└────────────────────────────────────────────┘
```

### 2.5 Stopped — Hit (the only "good" tier now — Perfect is gone)

```
┌────────────────────────────────────────────┐
│ ┌────┐                                      │
│ │ 🧍 │  [Run #12]                   ( ⏸ )   │  fill unchanged (no delta on Hit)
│ └────┘  Life 50%                            │  no arrow — hitDelta=0, nothing moved (erratum fix)
│                                              │
│        Target 0:02.40                       │
│         Stopped                             │  unchanged (green-d)
│      ╭──────────────╮                       │
│      │   0:02.40 (white)│                   │  filled green, 40dp digits ←v3
│      ╰──────────────╯                       │
│           [ HIT ]                           │  ←v3 — bare, no "+2%", min-width 90dp (§6)
│         [Hit: safe]  [Miss: -10%]           │
│      ╭────────────────────────╮             │
│      │  TAP (dimmed .45)       │            │  dimmed dwellDimmed look, unchanged (v1 §3.5)
│      ╰────────────────────────╯             │
└────────────────────────────────────────────┘
```

### 2.6 Stopped — Miss

```
┌────────────────────────────────────────────┐
│ ┌────┐                                      │
│ │ 🧍 │  [Run #12]                   ( ⏸ )   │  fill now genuinely lower — first real drain
│ └────┘  Life 40% ▼                          │  (e.g. 50→40; unchanged transient-arrow rule)
│                                              │
│        Target 0:02.40                       │
│         Stopped · off by 0.42               │  unchanged (SS.CC delta readout, red, untouched)
│      ╭──────────────╮                       │
│      │   0:02.82 (white)│                   │  filled red, 40dp digits ←v3
│      ╰──────────────╯                       │
│        [ MISS -10% ]                        │  ←v3 — interpolated, was "-5%"; wider than HIT (§6)
│         [Hit: safe]  [Miss: -10%]           │
│      ╭────────────────────────╮             │
│      │  TAP (dimmed .45)       │            │
│      ╰────────────────────────╯             │
└────────────────────────────────────────────┘
```

### 2.7 Final band (`finalBandArmed`/`finalBandRunning`)

```
┌────────────────────────────────────────────┐
│ ┌────┐                                      │
│ │ 🧍 │  [Run #12]                   ( ⏸ )   │  avatar fill: redDark (10% is in the redDark band
│ └────┘  10% · next miss is fatal            │  both before AND after the §7 rebase — see §7)
│                                              │
│     Aman, last chance                       │  unchanged copy (untouched, §0)
│    Target 0:02.40 (·75 op)                  │  unchanged style, new format
│         Running…  (red)                     │
│      ╭──────────────╮                       │
│      │   0:01.95 (red)│                     │  outlined red, 40dp digits ←v3
│      ╰──────────────╯                       │
│      [Nail it → Survive]                    │  unchanged single pill
│      ╭────────────────────────╮             │
│      │         TAP  (red)      │             │  ←v3 — was "STOP"
│      │  "one clean stop saves you" │        │  unchanged sub-label (v6 D12)
│      ╰────────────────────────╯             │
└────────────────────────────────────────────┘
```

Terminal final-band Stopped frame (v1's filled-in "missing frame", §2.7): flash pill still reads **`SURVIVED`** (non-miss) or **`MISS`** (miss, fatal) with no percentage — unchanged text, but now also gets the §6 min-width treatment for consistency (see §6).

---

## 3. §3.2 Legend pills — two, not three

Two pills, centered, in the existing `Wrap(alignment: center, spacing: 8, runSpacing: 6)`:

| pill | string | source |
|---|---|---|
| 1 | **`Hit: safe`** | literal — no interpolation, there's no number (`hitDelta == 0`) |
| 2 | **`Miss: -10%`** | interpolated from `config.missDelta`, never hardcoded |

**Optical balance — checked, no fix needed.** `"Hit: safe"` is 9 characters, `"Miss: -10%"` is 10 — at the pill's 9dp/600 label size the two pills' natural (padding-driven) widths differ by roughly 5–6dp, which is imperceptible in a centered `Wrap`. **Decision: no min-width, no spacing change.** This is a deliberately different call from §6's flying pill: that case had a genuine ~2× width spread (`HIT` vs `MISS -10%`) that reads as a jump; this case doesn't, and adding a mechanism to fix a problem that doesn't exist here would be scope creep. Keep the existing `8dp`/`6dp` spacing values exactly as shipped.

Two things that do **not** apply anymore, called out so they aren't cargo-culted forward from v1: v1 §3.2's "wrap-to-2-rows on narrow phones" fallback language and its 3-pill fit reasoning are moot at 2 pills (they will never wrap on any supported width) — the `Wrap` widget itself stays for defensive safety (per v6 D14), but the reasoning about *why* no longer needs restating. The final-band single "Nail it → Survive" pill fully replacing this row is unchanged.

**Copy correction, not a visual change:** `legend_pills.dart`'s doc comment currently says the 3-pill layout was "extrapolated beyond the mock's literal 2-pill layout" (v1 §3.2's own wording) — that sentence is now backwards (the mock's 2-pill layout is canonical again) and must be rewritten, not left as stale history. Flagging for the reviewer per v6 §6.3; not a pixel change for me to verify, but worth the built code matching this doc's intent rather than a leftover comment implying 3 pills were ever a correction *toward* something.

---

## 4. The 7-glyph readout — exact sizes (v6 §12 flags 1–2)

### 4.1 Uniform sizing — affirmed, not overridden

**One `Text` widget, one `TextStyle`, the full `formatClock(target)` string rendered as a single run.** The always-`0` minutes digit is **not** de-emphasized (no smaller/muted "0:" prefix, no split `TextSpan`s). Reasoning: a differential-size prefix only pays for itself if the de-emphasized part is genuinely low-information relative to the rest — here it isn't clearly so (a "0:" that quietly becomes "1:" the one time a target ever crosses a minute boundary needs to *not* look like a typo when it does), and splitting the string into two styled spans breaks `FontFeature.tabularFigures()`'s per-glyph width guarantee at the seam between the two spans, reintroducing exactly the jitter risk tabular figures exist to prevent. Confirms v6's own recommendation.

**Don't do:** wrap `"0"` or `"0:"` in its own smaller/muted `TextSpan`. Ship the whole string as one `Text`, one style, at the sizes below.

### 4.2 Sizing method

Both render sites currently rely on an enclosing `FittedBox(scaleDown)` to avoid overflow, but neither declares a size chosen *for* 7 glyphs — they inherited sizes tuned for 4. The brief is explicit: pick real numbers, keep the `FittedBox`es as a safety net for extreme cases (large system text-scale, sub-320dp devices), not as the everyday sizing mechanism.

Working assumption for the budget below (Fredoka Bold, tabular figures): digit ≈ `0.62em` wide, `:` ≈ `0.35em`, `.` ≈ `0.30em`. This is an estimate, not a measured font metric — flagged explicitly so the verification pass (§11) checks the *actual* rendered width against these numbers rather than assuming they're exact; the sizes below are chosen with enough margin that a moderate error in this assumption doesn't change the outcome.

`"0:04.70"` = 5 digits + 1 colon + 1 period → `5×0.62 + 0.35 + 0.30 = 3.75em`.

**Available width at a 320dp-wide phone**, HUD's 14dp horizontal inset each side (v1 §1.3): `320 − 28 = 292dp`.

### 4.3 `stopwatch_plate.dart` — the tighter constraint

| property | v1/v2 (4-glyph era) | **v3 (7-glyph)** |
|---|---|---|
| digit font size | 52dp | **40dp** |
| horizontal padding | `EdgeInsets.symmetric(horizontal: 30)` | **`horizontal: 18`** |
| vertical padding | 14dp | unchanged (14dp) |
| border / shadow / radius | 2.5dp ink / 4dp offset / 20dp | unchanged |

Budget check at 320dp: `3.75em × 40dp = 150dp` text + `2×18 = 36dp` padding + `2×2.5 = 5dp` border = **191dp**, against a 292dp ceiling — **101dp of margin (~35%)**. For comparison, leaving the old values in place (`52dp`/`30dp`) computes to `195 + 60 + 5 = 260dp`, an **11% margin** that a moderate system text-scale bump (this widget has no `FittedBox` of its own — it's the outer `_CenterContent` `FittedBox` that would have to catch it, shrinking the *whole* center column, not just the plate) would eat entirely. The new values are chosen specifically so this widget stops being the thing that forces that outer shrink.

**Don't do:** leave the digits at 52dp and "fix" this by shrinking only the horizontal padding. The padding-only fix alone (30→18dp saves 24dp) still leaves less margin than dropping the font size too; do both.

### 4.4 `primary_action_button.dart` (`armStart`/`dwellDimmed` target)

| property | v1/v2 (4-glyph era) | **v3 (7-glyph)** |
|---|---|---|
| target number font size | 56dp | **44dp** |
| micro-label ("TAP AT") | 11dp/600, unchanged | unchanged |
| gap (label → number) | 4dp | unchanged |

This site has more headroom than the plate (no fixed internal padding on the button's content `Column` — it's centered inside the button box up to the 300dp cap, so ~287dp is available at 320dp): `3.75em × 44dp = 165dp` against ~287dp, **122dp margin (~74%)**. Kept meaningfully larger than the plate's 40dp anyway (44 > 40) to preserve the pre-existing size hierarchy (56 was already bigger than the plate's 52) — this is the number the player commits to memory before tapping, and should still read as the single biggest number on screen.

**Don't do:** size the button's target number *smaller* than the plate's live digits — that would invert an established hierarchy (target-to-remember > live-count-up) for no reason connected to the actual overflow risk, which is asymmetric in the button's favor.

### 4.5 A boundary worth documenting so a future retune doesn't silently break this

Both budgets above are computed for the *current* target range (`targetMaxMs = 4900`, always single-digit minutes). `formatClock` is correct for any duration (v6 §2.2's rollover table), and the auto-miss-capped live count-up tops out around `~6.08s` at defaults — still 7 glyphs, still inside budget. **If `targetMaxMs` is ever raised into a range where minutes can reach two digits** (e.g. a hypothetical multi-minute target — nothing currently planned, v6 §13 flag 6 only discusses restoring a 6.00s ceiling, still single-digit minutes), the glyph count grows to 8 and these exact dp values must be re-audited, not assumed to still fit. Flagging now so this doesn't get silently inherited as "already solved" by a future pass.

---

## 5. `TAP` verb — optical weight (v6 §12 flag 4)

`"STOP"` (4 letters) → `"TAP"` (3 letters), same 34dp/700 white treatment, same 1.5dp `coralDark`/`redDark` text-shadow, same box. **Confirmed: no compensating size bump.** A sticker-button label's visual weight in this app's language comes from font-size/weight/color/shadow — not from how much of the button's width it spans — and every look here is a centered `Column` inside a `FittedBox`-wrapped, already-centered button interior, so a shorter word simply reads as a shorter word in the middle of a big colored box, the same way a single big glyph ("3", countdown circle) already does elsewhere in this feature without looking sparse. **Don't do:** bump `TAP`'s font size above 34dp to "fill" the horizontal space `STOP` used to occupy — that would make it inconsistent with `stopFinal`'s identical 34dp treatment and isn't solving a real problem (nothing here is measured by horizontal fill; the button isn't a justified/stretched label).

Micro-label: `"STOP AT"` (7 chars incl. space) → `"TAP AT"` (6 chars incl. space) — trivially shorter, no size or layout change, 11dp/600/0.06em letter-spacing/`ink@85%` all unchanged.

`stopNormal` sub-label: `"stop as close to <target> as you can"` → `"tap on the number"` (v6 D13) — shorter string, same 10dp/500 white style, no wrap risk introduced (it was already fitting a longer string). `stopFinal`'s sub-label (`"one clean stop saves you"`) is untouched, per the brief.

---

## 6. Flying pill — bare `HIT`, min-width needed (v6 §12 flag 5)

**A min-width is needed.** Estimated natural (content-driven) pill widths at the existing 14dp/700 label size, 15h/5v padding, 2.5dp border:

| label | chars | est. natural width |
|---|---|---|
| `HIT` | 3 | ≈ 62dp |
| `MISS` (final band) | 4 | ≈ 71dp |
| `SURVIVED` (final band) | 8 | ≈ 108dp |
| `MISS -10%` (normal) | 9 | ≈ 111dp |

That's roughly a 79% spread top-to-bottom, and specifically a **~2× jump** between `HIT` and `MISS -10%` — the exact pair that appears, in the same fixed screen position, on the very next attempt after each other. At 60fps in a fixed HUD slot, that reads as the pill glitching/resizing, not as a designed difference.

**Fix: `constraints: BoxConstraints(minWidth: 90)` on the pill's `Container`, applied uniformly to all four label variants** (`HIT`, `MISS -10%`, `SURVIVED`, `MISS`) — not conditionally to only the two v6-touched cases. This is a layout-only property; it doesn't touch `SURVIVED`/`MISS`'s copy, color, entrance tween, or semantics, all of which the brief keeps unchanged. Effect: `HIT` (≈62dp) and the final-band `MISS` (≈71dp) both get stretched to the 90dp floor; `MISS -10%` (≈111dp) and `SURVIVED` (≈108dp) already exceed it and render at their natural width, unaffected. New spread: 90dp–111dp (~23%) — reads as "the bad ones are a bit bigger," which is a fine, intentional-looking signal, not the ~2× jump.

**Don't do:** add the `minWidth` constraint without also setting `alignment: Alignment.center` on the same `Container`. A `Container` only centers its child within *extra* space introduced by a constraint if `alignment` is explicitly set — omitting it here is a real, easy mistake that would leave `HIT`'s text hugging the left edge of a now-wider pill instead of staying centered.

---

## 7. Avatar life-meter — color rebase across the 6-value staircase (v6 §12 flag 6)

### 7.1 The rebase, applied to the reachable values

`avatarFillColorForPercent`: `>=60/>=20` → **`>=40/>=20`** (green/coral/redDark unchanged as the three colors — only the boundary between green and coral moves). Applied to the only life values a run can ever produce (50, 40, 30, 20, 10, 0):

| life% | old band (`>=60`) | new band (`>=40`) |
|---|---|---|
| 50 | coral | **green** |
| 40 | coral | **green** |
| 30 | coral | coral |
| 20 | coral | coral |
| 10 | redDark | redDark |
| 0 | redDark | redDark |

Two values per band, evenly split — this reads correctly across the drain: a run crosses exactly **two** color boundaries in its worst case (green→coral between the 40 and 30 misses, coral→redDark between the 20 and 10 misses), never more, and the final-band-to-death step (10→0) stays inside the same redDark band — appropriately, since by the time a run is in the final band it's already visually "at the edge"; the last miss shouldn't need a color change to read as fatal, the fatal-caption text and the numplate's own red reskin already carry that.

**Drain animation — confirmed, no change needed.** `AvatarFigure`'s existing `TweenAnimationBuilder` (320ms, `Curves.easeOut`, fill-height only; color is driven off the *target* value, never the in-flight tween value, so the color never sweeps through an intermediate band mid-animation) already satisfies "animate the drain, don't snap." Nothing about this rebase requires touching that widget's animation code — it's a pure two-constant change in `avatar_fill_band.dart`.

### 7.2 Cross-surface check — Home avatar card and picker tiles (explicitly asked for, not just the in-run gauge)

- **Picker preview tiles (`AvatarTile`):** fixed demo `fillPercent: 100` (home-avatars-v1.md §3.4). 100 is `>=40` under both the old and new thresholds — **always green, no visual change from this rebase.** Confirmed, not just assumed.
- **Home avatar card (`HomeAvatarCard`):** fed by `bestLifePercent`. Fresh install (`bestLifePercent == 0`) hits the documented zero-state override (`fillPercent: 100`, green, "READY") regardless of thresholds — unaffected. **After the first completed run**, `bestLifePercent` becomes `50` and — per v6 §7.2/§4.1 — **stays 50 forever** under this scoring model (life can only ever start there, never rise, so `peakLifePercent` is a constant) until the separately-scoped Phase 2 repoints it. This is where the rebase has a real, visible, worth-flagging side effect: **under the old `>=60` threshold, that permanently-frozen 50% avatar would render coral forever; under this rebase's `>=40` threshold, it renders green forever.** Both are static — the actual bug (a frozen progression signal) is Phase 2's to fix, not this pass's — but this pass changes *which* static color ships in the interim. A permanently-green "everything's fine" avatar is arguably a slightly more optimistic-reading placeholder than a permanently-coral one for a game about attrition, which is worth a one-line founder-facing note rather than silently shipping as an unremarked side effect: **flagging it here, not fixing it** — fixing it is Phase 2 (v6 §7.2/§13 flag 5), already out of this pass's scope, and this doc doesn't reopen that.

**Don't do:** treat "the Home card's color happened to change too" as an unplanned regression needing a separate fix in this pass — it's a direct, correct, and now-documented consequence of using one shared function across three surfaces (exactly why v6 §7.1 asked for the cross-surface check in the first place).

---

## 8. The bar starts half-empty — confirmed as intentional tension, not a glitch (v6 §12 flag 7)

**Confirmed, and backed by an existing behavior, not just an assertion.** `AvatarFigure`'s `TweenAnimationBuilder` always tweens from a hardcoded `begin: 0`, regardless of the target `fillPercent` — this is a property of the shared widget, unrelated to and untouched by this pass. Because `PlayLoopScreen`'s provider is `autoDispose` (v6 §10.6 — a fresh mount every Home↔Play cycle), `LifeAvatar` genuinely mounts from scratch at the start of every run. **The practical consequence: the very first frame of Armed does not show a static half-full avatar — it visibly fills up from empty to 50% (green) over the existing 320ms tween, the instant the countdown ends.** That reads as a small, deliberate "you're already starting fragile, and here's the meter proving it" entrance beat, not a frozen/broken bar — the opposite of the risk the flag raised. No new animation, timer, or widget change is needed to get this; it already happens as a side effect of code that predates this pass. Worth stating plainly in the build so nobody "fixes" it into a hard-cut fill later, mistaking it for unintended jank.

Within a run, the same mechanism correctly does **not** replay this fill-from-zero: `LifeAvatar` isn't re-keyed per attempt (only `OutcomeFlash` uses `ValueKey(attemptIndex)`), so a mid-run drain (e.g. 50→40 on a miss) tweens smoothly from the prior value, not from 0 — confirmed correct, no change needed.

---

## 9. Verification checklist (game-ux-designer sign-off, per CLAUDE.md rule 6)

1. `formatClock` renders as one `Text`/one style everywhere it's shown large (plate, button target) — no split-styled minutes prefix.
2. `stopwatch_plate.dart`: digits render at 40dp, horizontal padding 18dp (not the old 52dp/30dp), on both a 320dp-wide test device and a standard (~360–390dp) device — confirm the outer `_CenterContent` `FittedBox` reports scale `1.0` (no shrink) on the standard device, and shrinks only under an artificially extreme text-scale/short-height test, not at rest.
3. `primary_action_button.dart`'s `armStart`/`dwellDimmed` target renders at 44dp; visually bigger than the plate's 40dp digits (hierarchy preserved).
4. Legend row: exactly two pills, `Hit: safe` / `Miss: -10%`, centered, unchanged spacing — no visible gap/imbalance.
5. All four `PrimaryActionLook`s say `TAP`/`TAP AT`, never `STOP`/`STOP AT`; `stopNormal`'s sub-label reads "tap on the number"; `stopFinal`'s sub-label is untouched.
6. Flying pill: `HIT` and the final-band `MISS` both render at the 90dp floor width (don't look "squeezed," text is centered, not left-hugging); `MISS -10%`/`SURVIVED` render at their natural (wider) width; the size difference between adjacent-in-time pills no longer reads as a jump/glitch.
7. Avatar fill: green at 50/40, coral at 30/20, redDark at 10/0, confirmed both on the in-run `LifeAvatar` and on the Home avatar card after at least one completed run (expect it green, per §7.2 — not a bug if so). Picker tiles stay green regardless (fixed demo fill).
8. Fresh-run first frame: avatar visibly animates from empty up to 50% (not a static half-full bar on entry).
9. Nothing Perfect-shaped survives anywhere in this feature's visible copy (no third legend pill, no `PERFECT` flash variant).

---

## 10. `docs/design/home-avatars-v1.md` — thresholds record corrected

That doc's §3.2 ("Confirmed, architect's thresholds adopted as-is: `>=60`…") and its §3.5 cross-reference recorded the pre-v6 thresholds as settled/architect-confirmed. Per v6 §7.1/§12 flag 8, that record is now stale. Updated directly in `docs/design/home-avatars-v1.md` (this pass) with a superseding callout pointing at this doc and architecture v6 §7.1, plus the corrected `>=40`/`>=20` values — **no code in that doc's own scope changes** (the actual `avatar_fill_band.dart` two-constant edit is flutter-developer's, tracked in v6 §8.3, not here). The mockup's three demonstration samples (100/45/4) still land in the same three bands under the new thresholds (45 is `>=40`, no sample crosses the moved boundary), so nothing else in that doc needed re-verification.

---

## 11. Explicitly out of scope for this doc (confirmed, not re-derived)

Per the task boundary: the life-caption's transient-tint-vs-critical-override *rule* (only its color-band *thresholds* changed, in §7 — the rule itself, and its arrow-glyph convention, is untouched), the pause overlay, the countdown screen, final-band urgency copy, and anything Perfect-shaped (deleted, nothing to spec). None of these appear as changes anywhere above; if a build diff touches any of them, that's outside this doc's authorization.

---

## 12. Memory-safety note (CLAUDE.md rule 7)

Structurally inert, consistent with architecture v6 §10's own review: every change in this doc is either a numeric literal (font size, padding, min-width) or a copy string. No new `Timer`, `AnimationController`, `Ticker`, listener, or persisted key is introduced by anything specified here. The one animation-adjacent finding (§8) is a *read* of existing, already-shipped `TweenAnimationBuilder` behavior, not a new one — it requires zero new code. The flying-pill min-width (§6) is a static `BoxConstraints` value on an already-`TweenAnimationBuilder`-driven, already-`ValueKey`-disposed widget (`OutcomeFlash`) — no new retained state. Net: this pass adds no new allocation profile beyond what v6 §10 already accounted for (the `formatClock` hot-path discipline, unchanged and not touched here).
