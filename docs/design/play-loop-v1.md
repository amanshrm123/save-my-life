# Stay Alive — Play Loop & In-Run States Visual & UX Spec v1

**Scope:** mockup Section 2 "Play loop & in-run states" only (`docs/mockups/timingtap_screen_library_v3-4.html`, section id `#b`, screens 2.1–2.8).
**Consumes:** `docs/architecture/v2.md` (single-`Notifier` `RunController`/`RunState`, `RunPhase` enum, `SS:CC` display format, 3-tier scoring, final-band sudden-death rules, single `PlayLoopScreen` hosting the whole phase machine).
**Extends:** `docs/design/onboarding-v1.md` — same app, same visual language. This doc **reuses** onboarding's color tokens, Fredoka type scale, sticker-button pattern, and spacing constants rather than re-deriving them, and only documents what's **new** to this feature.
**Consumed by:** `flutter-developer` (build from this doc) and a later `game-ux-designer` verification pass.

Design spec, not code — no Dart. Flutter mechanisms named below (e.g. "zero-blur shadow") describe an effect to reach for, not literal syntax.

---

## 0. Recap: reused from onboarding-v1.md (do not re-derive)

- **Color tokens:** `bg #c8ecd9`, `ink #1f2a2e`, `paper #fffdf7`, `coral #ff7a59`/`coral-d #e5613f`, `green #2fbf71`/`green-d #1f9c58`, `red #f0483e`, `gold #ffc23c`/`gold-d #e5a516`, `mute #7b8a86`, `blue #4a9fd8`, plus the two extra grays `body-mute #4a5f5a` and `dot-inactive #a7c4b8`.
- **Scale decision:** mockup CSS px values are used directly as dp; the phone-frame thumbnail is not a scale cue.
- **Sticker-button pattern:** ink border (2.5dp) + hard, zero-blur, ink-colored offset shadow + border-radius; built as a custom decorated container, not `ElevatedButton`.
- **Press-feedback juice:** press-in/spring-out animation + light haptic on every sticker-button tap (onboarding §4.4) — carries forward to every button in this feature.
- **Screen shell:** `SafeArea`, 20dp-ish horizontal padding as a baseline (this feature's HUD uses a tighter **14dp** horizontal inset for the gameplay chrome — see §1.3, a deliberate, mockup-driven deviation from onboarding's 20dp).

New to this doc: a **4th gray**, HUD chrome components (chip, icon-button, life bar, pill, numplate, flash), a taller two-line sticker-button variant, a modal/overlay pattern (first one in the app), and a state-driven color-reskin system for the whole HUD.

---

## 1. New design tokens introduced by this feature

### 1.1 The 4th gray

The mockup's life-meta caption text (`"Life 47%"` etc.) uses yet another hardcoded gray, distinct from all three grays already catalogued in onboarding-v1.md §0:

| gray | hex | used for |
|---|---|---|
| `mute` (reused) | `#7b8a86` | "Target 16:00" reminder text (non-final-band) |
| `body-mute` (reused) | `#4a5f5a` | countdown caption, pause modal body copy |
| **`hud-mute` (new)** | **`#3f5651`** | life-bar meta caption ("Life 47%") baseline color |

Keep this distinct from the other two — don't collapse into `mute`.

### 1.2 One un-tokenized hardcoded color — flagged

The final-band STOP button's label text-shadow is `0 1.5px 0 #b8362e` — a literal hex **not present in `:root`**, unlike its siblings (`coral-d`, `green-d`, `gold-d` are all real tokens). This reads as the "red-dark" companion color the palette forgot to promote. **Recommendation:** add a `redD = #b8362e` token to the theme now, for the same reason every other sticker-button fill has a `-d` shadow-text partner — don't leave this one as a magic inline hex.

### 1.3 HUD layout constants

- Gameplay screens use a **14dp** horizontal inset for the top chrome and bottom action area (`.topbar`, `.lifewrap`, bottom pill+button block all use `padding: …14px`), tighter than onboarding's 20dp — this is a genuine, deliberate difference in the mockup (gameplay chrome is denser/more functional; onboarding is airier/more brand-forward). Keep both values distinct; don't unify them.
- Center focus area (between the life bar and the bottom action block) is a flexible middle region — its *content* differs by phase (see §2), but it always centers its content both axes.

### 1.4 HUD chrome components

| component | size/shape | border | fill | shadow | text |
|---|---|---|---|---|---|
| **Chip** (`Run 12`, `Deaths 3`) | pill, `padding 3×9dp` | 2dp ink | paper | none | 9dp/600 label + **9dp/700** (bold) nested number |
| **Icon button** (pause trigger, ⏸) | 28dp circle | 2dp ink | paper | none | 12dp centered glyph |
| **Life bar track** | 12dp tall pill | 2dp ink | paper | none | — |
| **Life bar fill** | inset 1.5dp within track | — | color-state driven, see §3.4 | none | — |
| **Life-meta caption** | text row below bar, `margin-top 5dp` | — | — | — | 9dp/600, color `hud-mute` baseline (state-driven overrides, §3.4) |
| **Legend pill** (Hit/Miss/etc.) | pill, `padding 2×8dp` | 2dp ink | paper | none | 9dp/600 |
| **Numplate** (the live/frozen stopwatch readout) | rounded rect, **`padding 14×30dp`** (gameplay-actual value — see note) | 2.5dp ink, color state-driven | paper (running) / solid color-fill (stopped) | 4dp offset, color state-driven | digits **52dp/700**, line-height 1 |
| **Flash pill** (PERFECT/HIT/MISS) | pill, `padding 5×15dp` | 2.5dp ink | green (good) / red (miss) | 4dp offset ink | 14dp/700, white |

**Numplate note:** the base mockup CSS class defaults to `padding 9×22dp` / `40dp` digits, but **every concrete gameplay instance (2.4, 2.5, 2.6, 2.7) overrides this to `14×30dp` padding and `52dp` digits.** Treat the override as the real spec for this feature — the smaller base-class numbers are never actually used in Section 2 and should not be implemented as the default.

### 1.5 The two-line, taller "big sticker button" variant

Both the bottom-docked STOP button and the center "STOP AT" plate are a **new, taller sticker-button variant** distinct from onboarding's 44dp `.cta`:

| | height | radius | border | shadow offset | fill | label type stack |
|---|---|---|---|---|---|---|
| **Bottom STOP button** | 78dp | 22dp | 2.5dp ink | **6dp** down, ink | coral (default) / **red** in final band | main label 15dp/700 (white; note: 15dp, not onboarding's 14dp `.cta` — a real, distinct size) + small subtext 9dp/500 below, no shadow on subtext |
| **Center "STOP AT" plate** | 100dp (taller — two stacked lines) | 22dp | 2.5dp ink | **6dp** down, **gold-d** (not ink — a deliberate one-off deviation from the standard "shadow is always ink" rule) | gold, ink text (no white text-shadow) | overline "STOP AT" 11dp/600, opacity .85, letter-spacing .06em, block + big target number 38dp/700 below it |

Both are visually related (same border/radius family, same "sticker shelf" language) but distinct enough to warrant two separate widgets rather than one parametrized button:
- **Bottom STOP** → extend the existing `StickerButton` from v1 with: a taller height variant, an optional small-caption second line, and a color-variant prop (coral/red) — it's the same *kind* of thing as onboarding's `.cta`, just bigger and two-line.
- **Center "STOP AT" plate** → build as its own widget (`target_arm_button.dart`, per architecture's file layout) since its shadow color deviates from the ink-shadow rule and its internal layout (overline + big number) is unique to this button. It can still reuse a shared "hard offset shadow" decoration helper if one exists from `StickerButton`, just parametrized to accept a non-ink shadow color.

### 1.6 Modal / overlay pattern (first one in the app — set the convention here)

| element | value |
|---|---|
| Scrim | full-screen, ink `#1f2a2e` at **55% opacity** (`rgba(31,42,46,.55)`), covers the entire screen including the HUD underneath |
| Modal container | background = **`bg` (`#c8ecd9`)`, not `paper`** — deliberate: the pause card is "the app itself coming forward," not a generic white card |
| Modal border | **3dp** ink (thicker than the standard 2.5dp — bigger sticker card gets a bigger border) |
| Modal radius | 22dp |
| Modal shadow | **8dp** offset ink (bigger than any button's shadow — reinforces this is the biggest sticker element in the app so far) |
| Modal padding | 18dp, content centered, 10dp gap rhythm |
| Modal headline | 16dp/700 (note: **not** 17dp — distinct from onboarding's `h3.t`, a real, separate value) |
| Modal body copy | 11dp/600, color `body-mute` (`#4a5f5a`), line-height **1.4** (not onboarding's 1.45 — again, a real, distinct value, don't reuse the `.d` numbers verbatim here) |
| Primary action | reuses onboarding's plain green `.cta` (44dp) |
| Secondary actions | **new** `.ghostbtn` token, introduced here for its first real use: 40dp height, 14dp radius, 2.5dp ink border, paper fill, ink text, 4dp offset ink shadow, 13dp/700 label |

---

## 2. Per-screen / per-phase specs

Architecture's file layout makes this concrete: **screens 2.2–2.8 are not separate routes.** They are visual states of one `PlayLoopScreen`, driven by `RunPhase`. The only real `Navigator` transitions in this feature are **Home → PlayLoopScreen** and **PlayLoopScreen(phase == ended) → PlaceholderOutcomeScreen**. Pause (2.8) is an overlay `Stack` layer on the same screen, not a pushed route. Spec accordingly below — per-phase "screens" are described as visual states of one host, not standalone pages.

### 2.1 Screen 2.1 (Splash + 5s loader) — **NOT implemented per-run**

Architecture v2 §Flag 4 explicitly overrides this mockup screen: no per-run splash/loader. Entering Play goes straight to the countdown (2.2). **Flagging this clearly so a later verification pass doesn't treat 2.1's absence as a bug** — the cold-launch splash from onboarding-v1.md is the only splash in the app; it is never re-shown per run.

### 2.2 Countdown

```
┌────────────────────────────┐
│  Hey Aman, get ready…      │  15/700, ink; name span coral
│                            │
│          ╭────╮            │  96dp circle, 3dp ink border,
│          │  3 │            │  gold fill, ink digit 50/700,
│          ╰────╯            │  6dp-offset ink shadow, margin-top 6dp
│                            │
│  First target drops when   │  11.5/600, body-mute (reuse .d role)
│   it hits zero.            │
└────────────────────────────┘
```

Copy (verbatim): **"Hey `<name>`, get ready…"**, fallback **"Get ready…"** (drop the name-and-comma prefix entirely, don't leave a dangling comma) when `PlayerProfile.isAnonymous` — reuse that existing v1 getter directly, don't re-derive anonymity logic here.

Behavior: number ticks 3→2→1 automatically (no player input), then transitions to Armed the instant it hits zero (`countdownStepMs = 700` per architecture's `RunConfig`). No error/empty state — this is a pure timer.

### 2.3 Armed

```
┌────────────────────────────┐
│ [Run 12] [Deaths 3] (⏸)    │  topbar, 14dp inset — see §3.6 re: pause icon
│ [██████████░░░░░░░] Life 47%│  lifebar 12dp, green fill
│                            │
│      ╭──────────────╮      │
│      │   STOP AT     │      │  100dp gold plate, gold-d shadow
│      │     16:00     │      │
│      ╰──────────────╯      │
│                            │
│  [Perfect +3%][Hit +2%][Miss −5%]│  3-pill legend row — see §3.2
│      ╭──────────────╮      │
│      │   STOP        │      │  78dp coral STOP, opacity .45 (disabled)
│      │tap "Stop at"  │      │  small: "tap "Stop at" first to start"
│      │ first to start│      │
│      ╰──────────────╯      │
└────────────────────────────┘
```

The center focus area shows **only** the gold "STOP AT `<target>`" plate; the bottom STOP button is present but visually disabled (opacity 0.45, matching the same disabled convention onboarding used for its "Start playing" button — reuse that exact treatment, don't invent a new disabled look). Tapping the center plate is the **only** way to start a run (`startRunning()`); guarded against double-tap per architecture §9 rule 4.

### 2.4 Running

```
┌────────────────────────────┐
│ [Run 12] [Deaths 3] (⏸)    │
│ [██████████░░░░░░░] Life 47%│  unchanged from Armed
│                            │
│        Target 16:00        │  10/600, mute — small quiet reminder
│         Running…           │  9/700 uppercase, green-d
│      ╭──────────────╮      │
│      │    11:47      │      │  numplate: paper fill, green border+shadow,
│      ╰──────────────╯      │  green-d digits
│                            │
│  [Perfect +3%][Hit +2%][Miss −5%]│
│      ╭──────────────╮      │
│      │   STOP        │      │  78dp coral STOP, now fully live
│      │"stop as close │      │
│      │ to 16:00..."  │      │
│      ╰──────────────╯      │
└────────────────────────────┘
```

The gold center plate is **gone entirely** (not just hidden/disabled) the instant the tap that starts the clock registers — replaced by the small "Target `<t>`" reminder + the live numplate. **Rule for the "Running" numplate look, generalizes across every non-final-band running state:** paper background, colored (green) border + shadow, colored (green-d) digit text — an **outlined** treatment. Digits race visibly at 60fps via the screen's own `Ticker`/`ValueNotifier` (architecture §1 — not through Riverpod).

### 2.5 Stopped — good (Perfect or Hit)

```
┌────────────────────────────┐
│ [Run 12] [Deaths 3] (⏸)    │
│ [███████████░░░░░░] Life 53% ▲│  fill green, ▲ in green
│                            │
│        Target 16:00        │
│         Stopped            │  9/700 uppercase, green-d
│      ╭──────────────╮      │
│      │  16:00 (white)│      │  numplate: SOLID green fill, white digits
│      ╰──────────────╯      │
│        [PERFECT +3%]        │  green flash pill
│  [Perfect +3%][Hit +2%][Miss −5%]│
│      ╭──────────────╮      │
│      │   STOP        │      │  see §3.5 — recommend dimming here
│      ╰──────────────╯      │
└────────────────────────────┘
```

**Rule for the "Stopped" numplate look, generalizes across every stopped state:** solid color-fill background (matching the tier's polarity), **white** digit text — a **filled** treatment, the visual inverse of "Running." This Running=outlined / Stopped=filled pairing is a clean, consistent rule worth building as a single parametrized widget rather than two.

**Perfect vs. Hit — resolving the mockup's gap (architecture flag 1):** the mockup's `.flash` CSS has exactly **two** modifier classes, `.good` and `.miss` — there is no third "great/perfect" visual variant in the CSS. So: **Perfect and Hit share the identical "good" visual treatment** (green solid numplate, green flash pill) and differ **only** in the flash pill's label text ("PERFECT +3%" vs "HIT +2%") and the (invisible) life-delta magnitude. Don't build a visually distinct third "extra green" state — there isn't one in the source, and inventing one would be scope creep, not fidelity.

Life-meta gains a **▲** (up arrow, green) appended after "Life N%" — present only during this Stopped dwell, see §3.4 for exactly when it appears/clears.

### 2.6 Stopped — miss

```
┌────────────────────────────┐
│ [Run 12] [Deaths 3] (⏸)    │
│ [█████████░░░░░░░░] Life 43% ▼│  fill CORAL (not red!), ▼ in red
│                            │
│        Target 16:00        │
│         Stopped            │  9/700 uppercase, red — no gap readout, see below
│      ╭──────────────╮      │
│      │  16:14 (white)│      │  numplate: SOLID red fill, white digits
│      ╰──────────────╯      │
│         [MISS −5%]          │  red flash pill
│  [Perfect +3%][Hit +2%][Miss −5%]│
│      ╭──────────────╮      │
│      │   STOP        │      │
│      ╰──────────────╯      │
└────────────────────────────┘
```

**Important, easy-to-miss detail:** the life-bar **fill** on a miss is **coral** (`#ff7a59`), matching onboarding's coral token — **not** `red` (`#f0483e`). Red is reserved exclusively for the final-band critical state (2.7). The **▼ arrow glyph itself is red**, even while the bar fill under it is coral — replicate this exactly as shown; it's a real (if slightly inconsistent-looking) detail in the source, not a typo to "fix."

**Status label — restored to the `SS:CC` reading (re-resolved):** the mockup's literal caption "Stopped · off by 0.14" reconciles exactly under `SS:CC` (seconds.hundredths) — `0.14` is the absolute error in seconds, to 2 decimal places, i.e. `|stopElapsed − target|` formatted the same way the clock itself is, minus the leading whole-second/colon grouping. The status label reads **"Stopped · off by `<gap>`"**, red, 9dp/700 uppercase — restoring the literal mockup caption now that the display format that explains it is back.

### 2.7 Final band — the sudden-death reskin

```
┌────────────────────────────┐
│ [Run 12] [Deaths 3] (⏸)    │  chips stay NEUTRAL — see note below
│ [█░░░░░░░░░░░░░░░░] 4% · next miss is fatal│  fill RED, combined red text
│                            │
│     Aman, last chance      │  11/700, red — NEW urgent line
│    Target 16:00 (·75 op)   │  10/600, red @ 75% opacity
│         Running…           │  9/700 uppercase, RED (was green-d)
│      ╭──────────────╮      │
│      │  15:58 (red)  │      │  numplate: paper fill, RED border+shadow,
│      ╰──────────────╯      │  RED digits — outlined treatment (running rule)
│                            │
│      [Nail it → Survive]    │  single pill, replaces the 3-pill legend
│      ╭──────────────╮      │
│      │   STOP (red) │      │  78dp, fill goes RED, ink border unchanged,
│      │"one clean    │      │  text-shadow uses the new redD token
│      │ stop saves.."│      │
│      ╰──────────────╯      │
└────────────────────────────┘
```

**Exactly what reskins vs. what stays neutral (per the coordinator's direct question):**

| element | reskins to red? | detail |
|---|---|---|
| Top chips (Run/Deaths) | **No** — stay paper/ink neutral | verified directly from the mockup markup; don't over-reskin the whole screen |
| Life bar fill | **Yes** | solid red, persists continuously while in the final band (not a transient flash tint — see §3.4) |
| Life-meta text | **Yes**, and reformatted | becomes one combined red string **"`<n>`% · next miss is fatal"**, replacing the normal "Life N%[ ▲/▼]" template entirely — not just a color override of the same template |
| New urgent line | **Yes (new element)** | **"`<name>`, last chance"**, 11dp/700, red — appears *above* the "Target" reminder, a line that doesn't exist in the non-final-band running states |
| "Target `<t>`" reminder | **Yes**, plus new opacity | red text at 75% opacity (vs. plain mute-gray, full opacity, in the normal running state) |
| "Running…" status label | **Yes** | red (was green-d) |
| Numplate | **Yes** | border+shadow+digit color → red, but **stays the outlined/paper-fill treatment** (it's still "Running," just red — see the Running=outlined rule in §2.4) |
| Legend pills | **Replaced**, not recolored | the 3-pill Hit/Perfect/Miss row is swapped for a **single** pill: **"Nail it → Survive"** |
| Bottom STOP button | **Yes** | fill → red, **ink border stays ink** (not reskinned), label text-shadow → the new `redD` token |

**Anonymous fallback for "`<name>`, last chance" — a gap the mockup doesn't show, filled here:** following the same `isAnonymous` pattern as the countdown greeting, drop the name entirely rather than showing an awkward empty comma: **"Last chance"** for anonymous players.

**A genuine mockup gap — the missing "final-band Stopped" frame:** the mockup shows final-band *Running* (2.7) but never shows what the screen looks like the instant a final-band attempt is *stopped* (survive or death, before the outcome hand-off). Architecture confirms this moment is terminal either way (no more incremental life %, no re-arm). Recommendation, since one is needed for a coherent build:
- **Non-miss (survive):** reuse the "Stopped — good" numplate/flash visual language (solid green fill, white digits) but the flash pill should read **"SURVIVED"**, not a percentage label — no life delta is actually applied here, so a "+3%"/"+2%" label would be misleading.
- **Miss (death):** reuse the "Stopped — miss" visual language (solid red fill, white digits) with a flash reading **"MISS"** (or omit the flash pill and cut straight to the outcome hand-off — either is defensible; recommend keeping the brief flash for consistency with every other stop in the loop, using the same `flashDwellMs` dwell before navigating to `PlaceholderOutcomeScreen`).

### 2.8 Pause

```
┌────────────────────────────┐
│ [Run 12]           (⏸)     │  Deaths chip dropped here — see §3.6
│ [██████████░░░░░░░]        │  life bar shown, frozen; no meta row
│                            │
│  ░░░░░░░░ scrim 55% ░░░░░░ │
│   ┌──────────────────┐    │
│   │      Paused        │    │  16/700 headline
│   │ Your run is safe.  │    │  11/600 body-mute, line-height 1.4
│   │ Take your time.    │    │
│   │ [   Resume   ]      │    │  .cta green, 44dp
│   │ [ Restart run ]     │    │  .ghostbtn, 40dp
│   │ [ Quit to home ]    │    │  .ghostbtn, 40dp
│   └──────────────────┘    │
└────────────────────────────┘
```

Copy (verbatim): headline **"Paused"**, body **"Your run is safe. Take your time."**, buttons **"Resume"** / **"Restart run"** / **"Quit to home"**. Button order (primary reversible action first, most destructive/exit action last) is deliberate — keep it.

States: shown / hidden only — this is a binary overlay, not a phase with its own error/loading states. `RunState.phaseBeforePause` (architecture §5) restores the correct underlying phase on Resume.

---

## 3. Cross-phase behavior & resolved ambiguities

### 3.1 The HUD is a phase machine, not a page stack

Only two real `Navigator` transitions exist in this feature (Home→Play, Play(ended)→Outcome — reuse `fadeSlideRoute` from v1 core for both, per architecture §7). Everything else — Countdown→Armed→Running→Stopped→(re-Armed | FinalBandArmed)→...→ended, plus Pause — is an in-place visual state change within one `PlayLoopScreen`. Spec transitions between these states as quick in-place cross-fades (§4), not route animations.

### 3.2 Legend pills — resolved to 3 tiers (architecture flag 1)

The mockup only ever shows the 2-pill layout ("Hit +2% / Miss −5%"), but architecture concluded there are genuinely 3 scoring tiers. **Recommendation: show all 3 pills** — "Perfect +3%" / "Hit +2%" / "Miss −5%" — in a single centered row, same pill styling as the mock's 2-pill version, reusing the existing 10dp gap (tightened to ~8dp if needed to fit on a ~360dp-wide phone). This is more informative than the mock's literal 2-pill row (a skilled player benefits from seeing the Perfect band exists) and the pills are small enough that 3 fit comfortably. If a screen is narrow enough that 3 pills would truncate text, wrap to two rows rather than shrinking/truncating labels. In the final band, this row is fully replaced by the single "Nail it → Survive" pill (§2.7) — never show 3 tier-pills and the final-band pill together.

### 3.3 Numplate: Running = outlined, Stopped = filled (a generalizable rule)

Confirmed by inspecting every instance in Section 2 (2.4 outlined-green, 2.5 filled-green, 2.6 filled-red, 2.7 outlined-red): whenever the phase is a *Running* variant (`running` or `finalBandRunning`), the numplate is paper-background with a colored border/shadow/digit-text. Whenever the phase is *Stopped* (evaluating a just-taken attempt), the numplate becomes a solid color fill with white digits. Build this as one parametrized numplate widget (fill-vs-outline mode + tint color), not four bespoke ones.

### 3.4 Life bar color-state rule (the coordinator's specific ask, resolved precisely)

The mock only shows 5 isolated snapshots, so the exact rule has to be inferred rather than read literally. Recommended rule, consistent with every shown frame:

1. **Baseline / default:** green fill, plain **"Life N%"** caption, no arrow — used in Armed and Running.
2. **Transient tier-tint (Stopped dwell only):** for the duration of the post-stop flash dwell (`flashDwellMs`), the fill and caption reflect the *just-evaluated* tier — green fill + **▲** (green) if good (Perfect/Hit), **coral** fill + **▼** (red) if Miss. This clears back to the baseline the instant the screen returns to Armed for the next target — it is **not** a persistent tint tied to the absolute life percentage.
3. **Critical override (persistent, not transient):** whenever `life ≤ finalBandThresholdPercent` (5%, per `RunConfig`), the fill is **red** and the caption switches to the combined **"`<n>`% · next miss is fatal"** string, replacing the arrow-based template entirely. This persists continuously for as long as the run remains in the final band (`finalBandArmed`/`finalBandRunning`) — unlike the coral miss-tint, it does not clear after one dwell period, because the underlying danger hasn't passed.

Rule 3 always wins over rule 2 (a final-band miss doesn't get a coral flash first — it's already red and heading to a terminal outcome).

### 3.5 STOP button dimming — a flagged inconsistency, with a recommendation

The mock dims the bottom STOP button (opacity .45) only in Armed (2.3), but shows it at **full opacity** during the Stopped dwell (2.5/2.6) even though the phase guard makes it a no-op then (`registerStop()` only acts during `running`/`finalBandRunning`, per architecture §9 rule 3). This reads as the mockup reusing the Running frame's button markup wholesale for the Stopped screenshots, not a deliberate "looks live but isn't" choice. **Recommendation: dim the STOP button (opacity .45) during the Stopped dwell too**, for consistency with the disabled-look already established in Armed — a tappable-looking-but-inert button is a worse experience than a consistently-applied disabled affordance, and this costs nothing extra to implement (same opacity toggle, driven off `phase`).

### 3.6 Topbar pause-trigger — a genuine mockup inconsistency, resolved via the architecture's own file layout

Screens 2.3–2.7 (five separate frames) consistently show a **2-chip** topbar (Run, Deaths) with **no pause-trigger control anywhere** — there's no way to actually invoke pause from what's drawn. Screen 2.8 (Pause) shows a **different** topbar: Run chip + a pause icon button, with the Deaths chip dropped. Neither frame alone is a complete, coherent "how do I pause" answer.

Architecture's own module layout resolves this for us: `run_chips.dart` is documented as "**Run/Deaths chips + pause icon button**" — a single widget housing all three elements together. **Recommendation: the persistent gameplay topbar is Run chip + Deaths chip + a small pause icon button, all three, present throughout Armed/Running/Stopped/FinalBand** — reconciling both halves of the mock rather than picking one literal frame over the other. Treat 2.8's simplified "Run + icon only" topbar as an illustrative simplification for that one screenshot, not a literal instruction to drop the Deaths chip while paused.

### 3.7 Android back-button / back-gesture semantics — not specified by the mock, filled here

Neither the mockup nor architecture v2 states what hardware/gesture back should do during Play. Recommendation, consistent with "your run is safe" being the pause copy's whole point:
- Back while actively **Armed/Running/FinalBand\*** → open the pause overlay (same as tapping the topbar's pause icon), rather than silently exiting the screen or the app. A live precision-timing input shouldn't be one accidental back-swipe from losing the run.
- Back while the **pause overlay is showing** → equivalent to tapping **"Resume"** (dismiss the overlay), not "Quit to home." Quitting should always be an explicit, deliberate tap on "Quit to home," never a back-gesture default.

---

## 4. Animation / juice recommendations

This feature's core loop lives or dies on how good the STOP moment feels — it's the single highest-value juice target in the whole app so far. Timing-critical rule first: **none of the following visual/animation work may add latency to the actual input capture** — `registerStop()`'s first line reads `clock.elapsed` synchronously (architecture G2); every animation described below is purely cosmetic and runs *after* that read, never gating it.

1. **Countdown ticks (3→2→1):** each number change gets a quick scale-and-fade pop (scale ~1.15→1.0, ~200–250ms), plus a soft tick haptic per step. The moment it hits zero, cut to Armed immediately (no extra delay layered on top of `countdownStepMs`).
2. **Countdown → Armed:** quick cross-fade (~200–250ms) — a real layout change (full countdown UI → full HUD), but should feel instantaneous, not like a page turn.
3. **Armed → Running (the ARM tap):** the gold plate should feel like it visibly *converts into* the small "Target" reminder + numplate, not jump-cut. Recommend a fast (~150–200ms) cross-fade/scale-down of the plate paired with a fade/scale-in of the reminder+numplate. Keep this fast — the stopwatch is already running under the hood the instant the tap lands, so a slow visual transition would make the display feel laggy relative to the (correctly, immediately) ticking clock.
4. **Running → Stopped (the payoff — the biggest juice beat in the app):** on tap, the numplate should snap from outlined to filled with a quick scale-pulse (scale to ~1.06–1.08 then settle back to 1.0 over ~150–200ms, `Curves.easeOutBack`), synchronized with the flash pill popping in (scale/fade-in, ~200ms) below it. Pair with **tier-differentiated haptics**: Perfect/Hit get a satisfying positive tap (light-to-medium impact); Miss gets a sharper, distinct negative buzz — the haptic itself should telegraph good-vs-bad before the player even reads the flash text.
5. **Life bar fill changes:** animate the width change (~300–400ms, `Curves.easeOut`), don't snap — the meter should visibly drain or refill rather than teleport. Color transitions (green↔coral↔red) should crossfade over the same duration, not hard-cut.
6. **Stopped → re-Armed (next target):** after `flashDwellMs` (~600ms default), cross-fade back to the Armed gold plate + cleared flash/arrow. Quick (~200ms), not jarring.
7. **Entering the final band:** the whole HUD reskin (§2.7/§3.4) should transition together over ~250–300ms, paired with a distinct, slightly heavier haptic pulse marking "this is now sudden death" — a good moment for a single, deliberate warning buzz rather than the routine per-stop haptic.
8. **Pause overlay entrance/exit:** scrim fades in ~150–200ms while the modal scales in from ~0.92→1.0 with a slight overshoot (`Curves.easeOutBack`) — a fitting "sticker card popping forward" treatment, reversed on Resume. This is the first modal in the app, so this sets the house style for every future one.

---

## 5. Platform conventions — additions specific to this feature

Reuse onboarding-v1.md §5's keep/break split wholesale; additions specific to Play Loop:

- **Keep standard:** minimum touch target sizing — the 78dp STOP button and 100dp ARM plate both comfortably clear touch-target minimums; don't shrink either for visual tightness even though they're visually bigger than onboarding's buttons.
- **Deliberately custom (not a platform convention, and shouldn't be treated as a bug):** the raw `Listener`-based STOP input (architecture G2) bypasses the normal gesture-arena/ripple-feedback path most Flutter buttons use. This is intentional for latency reasons — do not "fix" it by wrapping STOP in a standard `GestureDetector`/`InkWell` for a nicer ripple; the precision requirement overrides the usual tactile-feedback convention here. Compensate for the lack of a built-in ripple with the explicit press-animation described in §4 point 4 instead.
- **New:** back-button/back-gesture semantics during Play (§3.7) — treat as this feature's convention, since neither v1 nor the mock specifies it.
- **Accessibility:** the life bar and countdown are both meaningfully conveyed by color (green/coral/red, gold circle) — ensure the life percentage and phase are also exposed as text (they already are, per the mock's own captions) so screen readers aren't relying on color alone. The flash pills (PERFECT/HIT/MISS) should be announced via semantics live-region equivalent so a screen-reader user gets the outcome of each stop, not just sighted players.

---

## 6. Responsive behavior across phone sizes

Reuse onboarding-v1.md §6's conventions (percentage/padding-driven sizing, wide-viewport cap ~430–480dp, scroll fallback for short/scaled devices) as the baseline. One new consideration specific to this feature:

- **Numplate digit-width stability — restored to the `SS:CC` reading, target range `2.00s`–`6.00s` (re-resolved):** under the `SS:CC` reinterpretation with the short 2.00–6.00s target range, the seconds portion is a single digit for nearly the entire target range, but a live count-up can still cross the 1-digit→2-digit boundary (e.g. `9:99`→`10:00`) if a player waits well past target before stopping. Use **monospace/tabular-figure digit rendering** for the numplate so digit-count changes don't cause a visually jittery resize mid-run, and size the numplate's container to comfortably accommodate at least 2-digit seconds without needing to reflow. Don't artificially zero-pad the seconds digit purely for width stability (e.g. force "03:47") — that's a cosmetic call the mock doesn't make either way; tabular figures alone solve the jitter problem without changing the reading.
- The 3-pill legend row (§3.2) is the one new element most likely to get tight on a ~360dp-wide phone — spec'd wrap-to-2-rows fallback in §3.2 covers this.

---

## 7. Widget reuse map (for flutter-developer planning)

| element | reuse existing v1 widget? | notes |
|---|---|---|
| Bottom STOP button | **Extend** `StickerButton` | new taller-height + two-line-label + color-variant (coral/red) props |
| Center "STOP AT" plate | **New widget** (`target_arm_button.dart`) | shares the "hard offset shadow" decoration concept, but non-ink shadow color + unique two-line layout don't fit the generic button cleanly |
| Pause "Resume" button | **Reuse** onboarding's plain green `.cta` StickerButton as-is | no changes needed |
| Pause "Restart run" / "Quit to home" | **New** `.ghostbtn` variant | first real usage of this CSS class in the app; add it as a StickerButton variant (paper fill, no white text) alongside the existing green/coral variants |
| Route transitions (Home→Play, Play→Outcome) | **Reuse** `fadeSlideRoute` from v1 core | per architecture §7 |
| Chips, life bar, pills, numplate, flash | **All new** — no onboarding precedent | first appearance of this whole HUD chrome family |

---

## 8. Consolidated list of resolved ambiguities / mockup gaps (for the verification pass)

Same rigor as the onboarding pass — flagging everything inferred rather than literally shown, so a future `game-ux-designer` verification doesn't mistake an inference for a miss:

1. **2.1 (per-run splash) is intentionally not built** — architecture override, not an implementation gap.
2. **3-tier legend pill layout** (§3.2) — mock only shows 2 pills; extrapolated to 3.
3. **Hit's flash appearance** (§2.5) — mock only shows Perfect+Miss concretely; resolved as sharing Perfect's "good" visual, distinct label only.
4. **Missing final-band "Stopped" frame** (§2.7) — genuinely absent from the mock; filled with a SURVIVED/MISS flash convention, no percentage labels.
5. **Anonymous fallback for "`<name>`, last chance"** (§2.7) — not shown; filled as "Last chance," following the countdown's established pattern.
6. **Topbar pause-icon inconsistency** (§3.6) — 2.3–2.7 show no pause trigger; 2.8 drops the Deaths chip. Resolved via architecture's `run_chips.dart` file-layout hint to a persistent 3-element topbar.
7. **STOP button not dimmed during Stopped dwell in the mock** (§3.5) — logically inert then per the phase guard; recommended dimming for consistency, deviating slightly from the literal mock frames.
8. **Life-bar coral-vs-red color rule** (§3.4) — only 5 isolated snapshots exist; the transient-tint-vs-persistent-critical-override rule is an inference, not a literal readout.
9. **Numplate digit-width jitter** (§6) — not shown in any static mock frame; flagged as an implementation consideration under the `SS:CC` format, given STOP timing is player-controlled and not capped at the target.
10. **Hardcoded `#b8362e`** (§1.2) — not a real token in `:root`; recommend promoting to `redD`.
11. **Android back-button semantics during Play** (§3.7) — unspecified by mock or architecture; filled with a pause-on-back / resume-on-back-while-paused convention.
12. **"Stopped · off by X" gap readout — restored** (§2.6): briefly dropped when the display was `MM:SS` (no sub-second value to justify it), reinstated now that `SS:CC` is the final decision — the literal mockup caption is used as originally specified.

None of these block a correct build — they're exactly the kind of gaps this doc exists to close before `flutter-developer` has to guess mid-implementation.
