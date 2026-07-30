# Stay Alive — Remaining Screens Visual & UX Spec v1

**Scope:** mockup sections 3–8 (`docs/mockups/timingtap_screen_library_v3-4.html`, ids `#c`–`#h`): Outcome Cards, Sharing, Ads, Home & Progression, Settings, Edge & Error states.
**Consumes:** `docs/architecture/v3.md` — read fully; several mockup screens are deliberately **not built** or **reworded** per its scope calls (fake ad service, no photo-permission prompt, no card collection, no offline screen, dropped percentile). Follow architecture's scope, not the raw mockup, wherever they conflict.
**Extends:** `docs/design/onboarding-v1.md` and `docs/design/play-loop-v1.md` — same app, same visual language, same sticker-button/hard-shadow pattern. Reuses those tokens; only new ones are defined here.
**Consumed by:** `flutter-developer` and a later `game-ux-designer` verification pass.

Design spec, not code — no Dart.

---

## 0. What's in this doc vs. explicitly not spec'd

| mockup screen | in this doc? | why |
|---|---|---|
| 3.1–3.4 Outcome cards | **Yes** | §2 |
| 4.1 Share sheet | **No visual spec — not built.** | Native OS share sheet (architecture §4); we invoke it, we don't render it. See §3.1. |
| 4.2 Confirm toast | **Yes, reworded** | §3.2 |
| 4.3 Photo permission | **No — dropped** | Architecture §1 item 2 |
| 5.1–5.4 Ads | **Yes** | §4 |
| 6.1–6.4 Home/streak/stats | **Yes** | §5 |
| 6.5 Collection | **No — out of scope** | Architecture §1 item 7; mockup's own "post-v1 candidate" |
| 7.1–7.3 Settings | **Yes, 7.1+7.2 unified** | §6 |
| 8.1 Name rejected | **Already spec'd** | Onboarding-v1.md §1.6 — reused verbatim by Settings' edit-name dialog, §6.4 |
| 8.2 Offline | **No — deferred, unreachable** | Architecture §1 item 8 |
| 8.3 Ad failed | **Yes, under Ads** | §4.5 |
| 8.4 Notification opt-in | **Yes** | §7 |

---

## 1. New design tokens introduced by this batch

### 1.1 Two more grays (now five total across the app — do not collapse any of them)

| gray | hex | used for |
|---|---|---|
| `mute` (reused) | `#7b8a86` | — |
| `body-mute` (reused) | `#4a5f5a` | — |
| `dot-inactive` (reused) | `#a7c4b8` | — |
| `hud-mute` (reused) | `#3f5651` | now also reused for the share-sheet app labels (moot, not built) — no new usage that matters here |
| **`note-text` (new)** | **`#5c6f6a`** | the positive/neutral "note" chip's text color (streak-broken hint) |

### 1.2 Outcome-card colors

| token | hex | used for |
|---|---|---|
| `card-survive-bg` (new) | `#e3f7ee` | Survived cardbox background — a distinct pale mint, **not** `paper` and **not** `bg`, a genuine 4th light surface color |
| `eternal-no` (new) | `#8a5a00` | Eternal cardbox's catalog line color; also its `stayalive.app` mark color (both override the default) |
| `eternal-way` (new) | `#6b4600` | Eternal cardbox's flavor-line body text color |
| `eternal-name` (new) | `#b5500e` | Eternal cardbox's colored-name-span color (the gold-bg analog of `coral` used on paper/mint cards) |

**Contrast rule, consistent with Play Loop's gold ARM plate:** the Eternal card fills the whole box solid gold, so every text color on it is a dark, low-saturation brown/amber rather than white or ink — same "light bg → dark text" logic already established for the gold ARM plate in Play Loop. Not a new rule, just a second application of it.

### 1.3 Note-chip colors (two variants, don't conflate)

| variant | bg | text | used for |
|---|---|---|---|
| Positive/neutral (new) | `#dbeee4` | `note-text` `#5c6f6a` | streak-broken hint (6.3) |
| Error (already described qualitatively in onboarding-v1.md §1.6 — hex pinned here) | `#fde3e3` | `red` `#f0483e` | name-rejected inline note (8.1) — reused as-is by Settings' edit-name dialog |

### 1.4 Ad-chrome colors (deliberately off-palette — see §4.1)

| token | hex | used for |
|---|---|---|
| `ad-bg` | `#2a3540` | full-bleed dark background on both real ad screens (5.1, 5.3) |
| `ad-subtext` | `#aeb9c4` | ad creative's gray-blue subtext line |
| `ad-install-fill` | `#4ad991` | ad "Install" CTA fill + rewarded progress-bar fill |
| `ad-install-text` | `#0c2a1c` | ad "Install" CTA's dark text |
| `ad-foot-text` | `#7c8894` | the bottom "closes in Ns" / "Ns left" caption |
| `ad-chip-bg` | `rgba(255,255,255,0.16)` | the "AD"/"REWARDED AD" label pill and the close-X circle |

None of these are reused anywhere else in the app — they exist specifically to make ad screens look like **someone else's UI**, not ours (see §4.1's rationale).

### 1.5 Three more horizontal-inset conventions (now four total — a running tally)

| convention | horizontal inset | used by |
|---|---|---|
| Onboarding centered screens | 20dp | onboarding-v1.md §1.3 |
| Play Loop HUD | 14dp | play-loop-v1.md §1.3 |
| **Outcome card (`.card-screen`)** (new) | **14dp, but both directions equally** (not horizontal-only like the HUD) | §2 |
| **Document-flow screens (`.pad`/`.scrhead`)** (new) | **16dp horizontal, 14dp vertical** | Home, Stats, Settings — §5, §6 |

Four genuinely different values across the app so far. Keep them all distinct per screen family; don't quietly unify them into "the app's padding."

### 1.6 Component tokens carried over unchanged (reference, not redefined)

Sticker-button pattern, `StickerButton` height/radius/shadow-offset variants (44/40/50/78/100dp seen so far), the modal/overlay pattern (scrim + `bg`-colored card + 3dp border + 8dp shadow) from Play Loop §1.6, and `redDark #b8362e` all get **reused as-is** in this batch (§6.4's reset-confirm modal, §5's big Play button). No redefinition needed.

---

## 2. Outcome Cards (mockup §3, screens 3.1–3.4)

One screen, `OutcomeCardScreen(summary: RunSummary)`, three color/content variants + one rendering mode (anonymous). The whole card body sits in a `RepaintBoundary` (architecture §3) for sharing — visually this just means the card must be a clean, self-contained composition with no overlays bleeding across its edges, which the mockup's structure already is.

### 2.1 Shared structure (all four screens)

```
┌────────────────────────────┐
│         [ badge ]           │  centered, pill, 2.5dp ink border,
│                            │  3dp offset ink shadow, 11/700
│  ╭──────────────────────╮  │
│  │ Death #37 of 1000     │  │  "no" — catalog line, 10/700, tier-colored
│  │                       │  │
│  │        (flex gap)     │  │  cardbox is flex-column, this gap is
│  │                       │  │  the "way" line's margin-top:auto —
│  │  Aman blinked at the  │  │  it and everything after it are pinned
│  │  exact wrong moment.  │  │  toward the BOTTOM of the box
│  │  Survived 4 deaths    │  │  "sub" — 10/500, mute
│  │  first. Peaked at 58%.│  │
│  │  STAYALIVE.APP        │  │  "mark" — 9/700, uppercase, letter-spacing .04em
│  ╰──────────────────────╯  │  cardbox: 2.5dp ink border, 18dp radius,
│                            │  5dp offset ink shadow, tier-colored fill
│  [ Share → ]  [  Again  ]  │  actions row, 2 equal-flex buttons,
└────────────────────────────┘  40dp height, 12dp radius, 4dp shadow, gap 8dp
```

Screen padding (`.card-screen`): **14dp on all four sides** — a third distinct padding value, see §1.5. Card layout is `Column`, top-anchored badge, then the cardbox `Expanded`, then the actions row pinned to the bottom.

**Cardbox internal anchoring (a real, non-obvious layout detail):** the catalog line ("no") sits at the top; the flavor line ("way"), the stat sub-line ("sub"), and the `stayalive.app` mark are anchored as a group toward the **bottom** of the box, with the empty space living *above* them (i.e., between "no" and "way"), not evenly distributed. Build this with a flexible spacer between the catalog line and the flavor-line group, not a plain top-to-bottom stack with fixed gaps — a run with a short catalog line and a long flavor line should still keep the flavor-line group bottom-anchored, matching the mock's `margin-top: auto` behavior exactly.

### 2.2 Per-tier table

| | badge | badge colors | cardbox fill | catalog line ("no") | catalog color | flavor color | share button |
|---|---|---|---|---|---|---|---|
| **3.1 Death** | "💀 You died" | red bg / white text | `paper` | "Death #`{catalogNo}` of 1000" | `red` | ink (name span `coral`) | red fill, white text, "Share →" |
| **3.2 Survived** | "🛟 Survived" | green bg / white text | `card-survive-bg` (`#e3f7ee`) | "Last-second save" (fixed, not dynamic) | `green-d` | ink (name span `green-d`) | green fill, white text, "Share →" |
| **3.3 Eternal** | "✨ Eternal Human" | gold bg / ink text | solid `gold` | "Perfect start · `{perfectCount}`/`{eternalCount}`" — **no percentile** (see §2.4) | `eternal-no` | `eternal-way` (name span `eternal-name`) | gold fill, ink text, **"Flex it →"** (label differs!) |
| **3.4 No-name fallback** | same as 3.1 | same as 3.1 | same as 3.1 | same as 3.1 | same as 3.1 | ink, **no colored name span at all** — the sentence just starts "Blinked at the exact wrong moment." | same as 3.1 |

"Again" is always the second action: paper fill, ink text, `.btn.ghost` treatment, all four variants.

**3.4 is not a fourth content pool** — it's the death pool's `anonymous` template rendering (architecture §3's `DeathFlavor{named, anonymous}` pair), reachable for *any* tier when `RunSummary.playerName` is empty, not just death. Spec the anonymous-rendering behavior once, generically, for all three tiers — don't special-case it as death-only.

### 2.3 The "way" / "sub" line split — reconciled per tier (a real ambiguity, resolved)

Architecture's card layout description says the flavor line is pooled content and the "sub" line is "built from `RunSummary`" — true for Death and Survived, but **not literally true for Eternal**, where the mock's sub-line ("Three perfect taps from cold. Almost nobody does this.") is qualitative flavor copy with no numbers in it, not a stat readout. This is a real inconsistency between the architecture's general description and the mockup's literal Eternal content.

**Resolution:** since Eternal's only "stat" (perfect count) is already stated in the catalog line ("Perfect start · 3/3"), there's nothing left to report as a sub-line stat. **Recommend: for Eternal only, treat "way" and "sub" as a paired pooled-flavor entry** (both fields live in `eternal_lines.dart`, both swap together per pick), rather than trying to derive a stat sub-line from `RunSummary`. Death and Survived keep the architecture's literal reading (way = pooled, sub = `RunSummary`-derived):

| tier | "way" source | "sub" source |
|---|---|---|
| Death | pooled (`death_lines.dart`) | `RunSummary`: "Survived `{lifetimeDeaths}` deaths first. Peaked at `{peakLifePercent}`%." |
| Survived | pooled (`survived_lines.dart`) | `RunSummary`: "Down to `{minLifePercent}`% — one perfect press back from the edge." (fixed template regardless of whether the save was Perfect- or Hit-tier — a minor simplification, flagged, not blocking) |
| Eternal | pooled, **paired with its own sub-line in the same pool entry** | *(not `RunSummary`-derived — see above)* |

### 2.4 Eternal percentile drop (architecture §3, confirmed)

Mockup's catalog line reads "Perfect start · 3/3 · top 0.3%" — the "· top 0.3%" fragment is dropped per architecture (no backend population exists to make it true). Catalog line becomes **"Perfect start · `{perfectCount}`/`{eternalCount}`"**. Keep the qualitative flex sub-line ("Almost nobody does this" or whichever pooled equivalent) — that's not a numeric claim, it's fine to keep.

### 2.5 Illustrative numbers, once more (same convention as "Aman"/"16:00")

"Death #247 of 1000," "Peaked at 61%," "Survived 3 deaths first," "63%" (later, in Home/Stats) are all mockup example values, not literal targets — the death pool is genuinely seeded at 50 entries (catalog numbers 1–50) while still honestly labeled "of 1000" (architecture §1 item 4), and start-life is being reconsidered (architecture §6 flag) so peak/min percentages in real play will differ from the mockup's illustrative numbers. Don't hardcode any of the mockup's specific numbers as defaults.

---

## 3. Sharing (mockup §4)

### 3.1 4.1 Share sheet — not visually built

Architecture §4 is explicit: the native OS share sheet (via `share_plus`) supplies the target list (Stories/WhatsApp/Copy/More on Android) — the app does **not** render the mockup's custom bottom-sheet UI at all. **Do not implement 4.1's visual** (the dimmed card + custom `sharesheet`/`shareapps` grid, the Instagram-gradient icon, the WhatsApp-green icon, etc.) — none of it is reachable in the real app; it's illustrative only, same category as onboarding's fake status bar. This is the sharing-feature equivalent of Play Loop's "2.1 splash not built per-run" call — flagging clearly so a verification pass doesn't look for it.

What the app *does* control going into the native sheet: the rendered card PNG (the `RepaintBoundary` capture) and the share text ("…stayalive.app"). No further visual spec needed for those — they're just the outcome card itself, already spec'd in §2.

**A gap worth noting:** the mockup's sheet headline ("Share your death") is tier-specific but only shown for the death case. If any in-app pre-share copy is ever surfaced (it currently isn't — the native sheet has its own chrome we don't control), the analogous copy for the other tiers would be "Share your save" (Survived) and "Flex your Eternal Human" (Eternal, matching the "Flex it →" button voice) — noted for completeness, not required since there's no in-app sheet to put it on.

### 3.2 4.2 Confirm toast — rebuilt, reworded

A lightweight in-app toast/snackbar, shown after the native share sheet returns a completed result.

| element | value |
|---|---|
| Position | bottom-anchored, above the actions row, `left/right: 14dp` inset, floating over the card |
| Background | `ink` |
| Text color | white |
| Radius | 12dp |
| Padding | 9×12dp |
| Text | 11dp/600, centered |
| Copy | **"✓ Shared"** — reworded from the mockup's "✓ Saved to your camera roll" per architecture §1 item 2 (no gallery-save happens; this is share-only) |
| Duration | standard toast dwell, ~2–3s, then fades/dismisses automatically |

**A gap:** architecture's §1 item 2 also mentions a "Copied" variant, implying the toast text might vary by which native-sheet target the player picked. In practice, since the app only invokes one generic `Share.shareXFiles` call and doesn't build its own "Copy" button, there's no reliable in-app signal for *which* target the OS sheet routed to on most platforms. **Recommend: always show the single generic "Shared" copy** regardless of the target the player picked in the native sheet; treat "Copied" as unreachable in this implementation unless `share_plus`'s result type exposes target-specific info on a given platform (flagged, not blocking).

### 3.3 4.3 Photo permission — dropped entirely

Per architecture §1 item 2. Do not build. Do not reference the "Let Stay Alive save photos?" copy anywhere.

---

## 4. Ads (mockup §5, plus 8.3)

All four screens render against `FakeAdService`'s **placeholder creative** — not real ad-network content (architecture §5). Spec the placeholder itself, since that's what genuinely ships.

### 4.1 Why the ad chrome is deliberately off-palette

Every other screen in the app uses the pastel `bg`/`paper` palette and the sticker-button pattern. The two full ad screens (5.1, 5.3) instead use a **dark navy background (`#2a3540`)** and a **flat, no-border, no-shadow "Install" CTA** (`ad-install-fill`/`ad-install-text`, no ink border, no hard offset shadow at all) — a deliberate contrast, not an inconsistency to "fix." Real mobile ad networks render their own chrome, and visually distancing it from the house UI helps players not mistake an ad's install button for a game action. **Keep this contrast; do not reskin the ad screens into the sticker style.**

### 4.2 5.1 Interstitial

```
┌────────────────────────────┐   bg: ad-bg (#2a3540)
│ [AD]                  (✕)  │   top-left pill label, top-right close circle
│                            │   both: ad-chip-bg, white content, no border
│                            │
│        ╭────────╮          │   104dp square, 20dp radius,
│        │  🎮    │          │   gradient bg (decorative only —
│        ╰────────╯          │   not a real ad creative, see below)
│      Puzzle Quest 3         │   16/700 white
│      #1 match-3 adventure   │   11/500, ad-subtext
│      [   Install   ]        │   flat CTA: ad-install-fill bg,
│                            │   ad-install-text, radius11, 12/700,
│                            │   NO border, NO shadow
│  Next run loading… ·        │   ad-foot-text, 8/600, centered
│  closes in 4s               │
└────────────────────────────┘
```

The gradient/emoji "creative" (`.adbox`) is **entirely decorative placeholder content** representing "some third-party ad" — it doesn't need to be a specific, on-brand creative; any simple gradient-box + emoji + two lines of fake ad copy communicates "this is an ad" adequately for a stubbed `FakeAdService`. Don't invest more design effort here than the mock did.

**Close (✕) and countdown — resolved behavior:** `AdService.showInterstitial()` has no differentiated result (unlike rewarded), so tapping the close X should be **immediately effective at any time** — it doesn't need to wait for the countdown. The "closes in Ns" countdown auto-advances if the player doesn't tap close first; both paths lead to the same "continue to the next run" outcome, since nothing is being earned here (unlike rewarded, where early-dismiss forfeits the reward).

### 4.3 5.2 Rewarded offer

Standard centered `.center`-style screen (house UI, not ad chrome — this is *our* offer prompt, not the ad itself):

```
┌────────────────────────────┐
│           🎁               │
│    Unlock a card skin       │  17/700 headline
│  Watch a short ad to        │  11.5/600 body-mute
│   unlock this style.        │
│  [🟧 Sunset skin  optional] │  a .row-style chip: 28dp swatch (coral→gold
│                            │   gradient), label, "optional" mute right-aligned
│  [ ▶ Watch to unlock ]      │  .cta-shaped but BLUE fill (#4a9fd8),
│                            │   NO text-shadow (deliberate — see below)
│       No thanks             │  plain text link, 11/600 mute (NOT boxed)
└────────────────────────────┘
```

**Deliberate deviation, worth preserving:** the "Watch to unlock" CTA uses `blue` (`#4a9fd8`, defined since onboarding but unused until now) instead of coral/green, **and explicitly has no white text-shadow** — both are intentional departures from the standard `.cta` look. This gives "leads to an ad" its own recognizable color language across the app (blue = ad-gated action), distinct from every other primary action (always coral or green). Keep the blue fill and the shadow-less text exactly as shown; don't "fix" it to match the standard `.cta` treatment.

"No thanks" is a bare underlined-or-plain text link (matching onboarding's "Skip for now" convention), **not** a boxed `.ghostbtn` — don't upgrade it.

**Scope note (architecture §5, §12 flag 9):** the reward this unlocks is inert — there's no real cosmetics/skins system to apply it to. Build the screen since it's asked for, but architecture recommends the founder consider deferring this whole flow until cosmetics exist. Flagging here too since it affects whether this is worth polishing further.

### 4.4 5.3 Rewarded playing

```
┌────────────────────────────┐   bg: ad-bg
│ [REWARDED AD]               │   label pill only — NO close button, see below
│                            │
│        ╭────────╮          │
│        │  🍭    │          │   gradient box (orange/red), emoji placeholder
│        ╰────────╯          │
│      Candy Blast            │   16/700 white — no subtext line this time
│                            │
│ ▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░       │   5dp progress bar, white@15% track,
│                            │   ad-install-fill fill — MUST actually
│                            │   animate 0%→100% over the ad's duration
│                            │   (the mock's 55% is a freeze-frame, not
│                            │   a resting value — same convention as
│                            │   every other progress bar in this app)
│ Reward unlocks when the ad  │   ad-foot-text, 8/600, centered
│ finishes · 8s left          │
└────────────────────────────┘
```

**A genuine gap — no visible close affordance:** unlike 5.1 (which has a close X), 5.3's mockup shows **no close/X control at all**, yet `AdService`'s `RewardedResult` includes a `dismissedEarly` variant, implying dismissal must be possible somehow. **Recommendation: honor the mock exactly (no visible X)** and route the hardware/gesture back-button to `dismissedEarly` instead — consistent with how real rewarded-ad SDKs commonly withhold an on-screen skip control to discourage early exit, while still needing *some* dismiss path to exist. Flagged as an inference, not a literal mockup instruction.

### 4.5 5.4 Reward granted

```
┌────────────────────────────┐
│           🎉               │
│     Skin unlocked!          │  17/700 headline
│  Sunset is now on your      │  11.5/600 body-mute
│   death cards.               │
│  ╭──────────────────────╮  │  a MINI cardbox preview: same 2.5dp ink
│  │ Your cards just got   │  │  border / 18dp radius / 5dp shadow language
│  │ louder.                │  │  as §2's real cardbox, but filled with a
│  ╰──────────────────────╯  │  coral→gold gradient and showing only ONE
│                            │  line of text (14/700 white) — no badge,
│      [    Nice    ]        │  no catalog line, no sub, no mark
│                            │  .cta green, plain (not coral)
└────────────────────────────┘
```

Note the preview cardbox is illustrative-only (matches the reward being inert per §4.3's scope note) — it cannot reflect a real skin swap on the player's actual outcome cards since no cosmetics system exists to apply it to. Build the confirmation screen as shown; don't wire it to any real card-rendering state.

### 4.6 8.3 Ad failed

Standard centered `.center` screen, straightforward, no ambiguity:

```
┌────────────────────────────┐
│           📶               │
│      Ad didn't load         │  17/700
│  Couldn't fetch an ad       │  11.5/600 body-mute
│  right now. Try again       │
│  in a moment.                │
│      [   Retry   ]          │  .cta, plain green
│       Maybe later            │  .ghostbtn, boxed
└────────────────────────────┘
```

Shown in place of whichever ad screen would have appeared (interstitial or rewarded-playing), whenever `showInterstitial()`/`showRewarded()` resolves to `failedToLoad` — a state substitution, not an extra navigational layer. "Maybe later" always continues the flow (never strands the player mid-loop, per architecture §5).

---

## 5. Home & Progression (mockup §6, screens 6.1–6.4; 6.5 out of scope)

**Layout convention shift:** every screen so far (onboarding, Play Loop, outcome cards) used a centered column or a HUD `Column`. Home is the first **top-anchored, document-flow** screen — left-aligned content flowing top-to-bottom inside `.pad` (16dp horizontal / 14dp vertical, §1.5), not a centered `.center` block. Stats and Settings share this same convention.

### 5.1 6.1 Home (the dashboard state)

```
┌────────────────────────────┐
│ Stay Alive                  │  26/700/.9 line-height, left-aligned,
│                            │  "Alive" in coral — smaller & left-aligned
│ One tap. From dust to        │  vs onboarding's centered 32/700 wordmark;
│  forever.                     │  don't reuse the onboarding wordmark style verbatim
│                            │  10/600 body-mute
│ ╭──────────────────────╮   │
│ │ DAILY STREAK           │   │  paper card: 2.5dp ink border, 16dp radius,
│ │ 4 days                 │   │  12dp padding, 5dp shadow, margin-top 14dp
│ │ ▓▓▓▓░░░  (7 segments)  │   │  label 9/700 uppercase mute; count "4" big
│ ╰──────────────────────╯   │  (24/700 coral) + "days" small (11/mute);
│                            │  week-bar: 7 segments, 6dp tall, 1.5dp ink
│                            │  border, 4dp gap, filled=coral/empty=paper-2
│ [63%][ 0 ][118]              │  3 stat tiles, equal flex, gap 8dp, paper,
│ Best  Eternal Deaths          │  2.5dp border, 14dp radius, 4dp shadow;
│  life                         │  value 17/700 (gold-d for Eternal tile only)
│                            │  + label 9/600 mute below
│      (flexible space)       │
│                            │
│      [     Play     ]       │  50dp-tall StickerButton, coral, .cta
└────────────────────────────┘  variant (a NEW height, see §1.6)
```

Stat tiles (Best life / Eternal / Deaths) are **all three tappable**, each navigating to the same Stats screen (6.4) — architecture doesn't distinguish per-tile destinations, keep it simple, don't build per-tile deep-scroll behavior.

**A genuine mockup gap — no way to reach Settings from Home.** Architecture's navigation graph requires a gear icon on Home → Settings, but the mockup's 6.1 frame has **no gear icon anywhere in its markup.** **Recommendation:** add a small icon-button in the top-right corner, reusing the same 28dp circular icon-button treatment already established for Play Loop's pause trigger (paper fill, 2dp ink border, centered glyph) — consistent with the one icon-button pattern the app already has, rather than inventing a new one.

**7-segment week bar — semantics ambiguous, resolved with a recommendation.** The mock shows streak=4 against a 7-segment bar with exactly 4 filled — comfortably within range, but doesn't resolve what happens once a streak exceeds 7 days (which `best_streak` examples in Stats, e.g. "7 days," suggest is common). Neither the mockup nor architecture's `streak_bar.dart` file listing defines the wrap/reset rule. **Recommendation: `min(streakCount, 7)` filled segments, capped — no calendar-week alignment, no wrap-around animation.** Simpler to implement and reason about than real ISO-week positioning; flag for a founder decision if a literal "day of the current calendar week" semantic is wanted instead.

**Two non-identical week-bar variants — don't collapse them.** Home's mini bar (6dp tall, 1.5dp ink border) and the Streak-Advanced celebration's bar (6.2, 8dp tall, 2dp ink border) are visually similar but genuinely different sizes in the mockup CSS — build as one configurable widget with a size parameter, not by literally reusing one fixed-size instance in both places.

### 5.2 6.2 Streak advanced — a Home *state*, not a route

Per architecture §6: "Not a separate route; an overlay/celebration state on Home." But visually it is **not** an overlay-with-scrim (unlike Play Loop's Pause) — the mockup draws it as a full, plain, centered `.center` layout that **replaces** Home's dashboard body wholesale, with no scrim/dim/floating-card treatment at all. Don't reuse the Pause-overlay visual pattern here — it's the wrong convention for this state.

```
┌────────────────────────────┐
│           🔥               │
│  Day 5 — streak alive!      │  17/700
│  You came back.              │  11.5/600 body-mute
│   Keep it going.             │
│ ▓▓▓▓▓░░  (7 segments, 8dp)  │  the LARGER week-bar variant, see above
│    [  Play day 5  ]         │  coral .cta — the only action shown
└────────────────────────────┘
```

Fires once, on first Home-open of a new day when `registerPlay` returns `advanced`; the transient flag clears on display (architecture §6). "Play day `{N}`" navigates straight into Play — **no dismiss-without-playing affordance is shown in the mock.** Recommend still honoring standard back-gesture/back-button to fall through to the normal dashboard even though there's no on-screen control for it (consistent with this app's established back-button conventions elsewhere), but the primary, intended path is always through the button.

### 5.3 6.3 Streak broken — same "Home state, not overlay" pattern

```
┌────────────────────────────┐
│           💔               │
│   Your streak broke         │  17/700
│  4 days, gone. Play today   │  11.5/600 body-mute
│   to start again.            │
│ [Come back tomorrow to      │  "note" chip — POSITIVE variant
│  keep the next one alive]   │  (#dbeee4 bg / note-text), NOT the
│                            │  red error-note variant from onboarding
│  [ Start a new streak ]     │  coral .cta
└────────────────────────────┘
```

Same full-body-replacement pattern as 6.2 (not a scrim overlay). Shown at Home-open when `isBrokenAtOpen` is true and the player hasn't played today yet (architecture §6, re-evaluated on app resume so crossing midnight while backgrounded updates correctly).

### 5.4 6.4 Stats

```
┌────────────────────────────┐
│ 📊 Your stats                │  .scrhead: 16/700, icon+text, padding 10x16x0
├────────────────────────────┤
│ 📈 Best life          63%   │  each row: .row treatment (paper, 2.5dp
│ 💀 Total deaths       118   │  border, 14dp radius, 4dp shadow, 8dp
│ 🛟 Survives             9   │  margin-bottom); left = 28dp icon chip +
│ ✨ Eternal Humans        0   │  12/600 label; right = bold value (17/700
│ 🔥 Best streak    7 days     │  default, gold-d for the Eternal row only)
└────────────────────────────┘
```

**A gap shared with Settings (§6 below):** the `.scrhead` bar has no visible back affordance in the mockup — no chevron, no icon, just an emoji + title. Every "sub-screen" reached from Home (Stats, Settings) has this same gap. **Recommendation: add a standard leading back button/chevron to the `.scrhead` bar convention for every screen that uses it** — a reasonable, low-risk platform-standard addition the mockup's screenshots simply crop out; flagging once here since it applies identically to §6's Settings screens too, rather than repeating the same note three times.

---

## 6. Settings (mockup §7)

### 6.1 One screen, not two (resolving the coordinator's "your call")

Architecture's module layout lists exactly **one** `settings_screen.dart` file — no second "legal" screen file — confirming the mockup's two phone-frame screenshots (7.1, 7.2) are a paginated-reference-sheet artifact, not two real screens. **Decision: one scrollable `SettingsScreen`**, sections in this order: toggles/name (7.1's content) → a visual divider → legal/reset (7.2's content) → version footnote.

```
┌────────────────────────────┐
│ ⚙️ Settings                  │  .scrhead — same back-affordance gap as §5.4
├────────────────────────────┤
│ 🔊 Sound            [ ⚫  ]  │  .row + toggle (on)
│ 📳 Haptics          [ ⚫  ]  │  .row + toggle (on)
│ ✍️ Name              Aman   │  .row, value in coral bold — tap opens
│                            │  the edit-name dialog (§6.3)
│ 🔔 Daily reminder   [  ⚪ ]  │  .row + toggle (off)
│ ─────────────────────────  │  visual divider (not in mockup, added for
│                            │  the unified-screen structure)
│ 📄 Privacy policy        ›  │  .row, mute chevron, → url_launcher
│ 📃 Terms                 ›  │  .row, mute chevron, → url_launcher
│ ⭐ Rate the game          ›  │  .row, mute chevron, → store listing
│                            │    (hidden on web — no store to rate on)
│ 🗑 Reset progress         ›  │  .row, RED variant (border/icon/text/
│                            │  chevron all red) — see §6.2
│                            │
│      v1.0.0 · stayalive.app  │  9/600 mute, centered
└────────────────────────────┘
```

Legal/rate rows are plain tappable list tiles (standard platform list-row press feedback is sufficient — they don't need the sticker-button press/shadow juice; they're not primary actions).

### 6.2 Toggle component

38×22dp pill, 2dp ink border. **On:** `green` fill, white 16dp knob (1.5dp ink border) inset 1px from the right edge. **Off:** `paper-2` (`#f2efe6`) fill, same knob inset 1px from the left edge. **Recommend animating the knob's slide** (~150–200ms) on toggle — not shown in the static mock, but an un-animated instant-snap toggle would read as broken for this extremely standard UI control; treat this as a near-required polish item, not a pure nice-to-have.

### 6.3 Edit-name dialog — not shown anywhere in the mockup, spec'd here

No frame in the whole mockup depicts a name-edit UI (Settings just shows the current name as static-looking text). Since this is a real, needed interaction (architecture §7: tap → edit dialog, reusing `NameValidator`), recommend:
- Reuse the Play Loop pause modal's dialog convention (scrim + `bg`-colored card, 3dp border, 22dp radius, 8dp shadow) as the container.
- Reuse onboarding's name-input styling verbatim inside it (46dp height, 14dp radius, 2.5dp ink border, paper fill, 16dp/700 centered text, 12-char cap, live "n/12" counter).
- "Save" (primary, coral `.cta`) / "Cancel" (`.ghostbtn`) actions.
- On a rejected name, reuse onboarding's exact inline error treatment (red border/text, the `error-note` chip, "Try again" — onboarding-v1.md §1.6) inside the same dialog rather than navigating anywhere.

### 6.4 7.3 Reset confirm

Reuses the Play Loop pause-modal pattern exactly (scrim, `bg` card, 3dp border, 22dp radius, 8dp shadow) **plus** a leading 30dp "⚠️" emoji above the headline that Pause's modal didn't have. Primary button is **red** (`red` fill, `redDark` text-shadow — the same token pair already established for Play Loop's final-band STOP button, reused here a second time), secondary is a plain `.ghostbtn` "Cancel."

Copy: "Reset everything?" / **"Deletes your streak, stats, and collection. Can't be undone."** / "Yes, reset" / "Cancel."

**A copy nuance worth a decision:** the mockup's body copy says "collection," but the card-collection feature is out of scope this pass (§0) — there is no collection data to delete. Recommend trimming to **"Deletes your streak and stats. Can't be undone."** until collection actually exists, rather than referencing a feature that isn't there; flagged as a minor honesty-of-copy call, same spirit as the dropped percentile and the reworded share toast.

---

## 7. Remaining edge state — 8.4 Notification opt-in

```
┌────────────────────────────┐
│           🔔               │
│  Keep your streak alive?     │  17/700
│  A daily nudge so you        │  11.5/600 body-mute
│   don't lose your streak.    │
│   No spam.                   │
│  [  Remind me daily  ]       │  coral .cta
│      No thanks               │  .ghostbtn — BOXED this time
└────────────────────────────┘
```

**Worth flagging explicitly:** "No thanks" here is a proper boxed `.ghostbtn`, **not** a bare underlined text link like onboarding's "Skip for now" or the rewarded-offer's "No thanks" (§4.3). Two visually similar-sounding secondary actions, two different real treatments in the mockup — don't standardize them to look the same; build each exactly as its own screen shows it.

Shown once, in context, after streak reaches day 2 (architecture §8) — a pushed screen reached from Home (architecture's nav graph draws this with a push arrow, unlike 6.2/6.3 which are in-place Home states) — treat it as its own route, not a Home-body-replacement state.

---

## 8. Cross-cutting animation / juice recommendations (additions to onboarding/Play Loop's §4s)

1. **Every progress bar in this batch must actually animate**, not rest at the mock's freeze-frame value — same convention established for the onboarding splash and now repeated for the rewarded-ad progress bar (§4.4): animate 0%→100% over the ad's real duration.
2. **Streak-advanced (6.2) is this app's biggest "juice" moment outside the Play Loop itself** — it's the core retention reward (architecture §6). Recommend a definite celebratory beat: the 🔥 emoji doing a quick bounce/scale-in on entry, the newly-filled week-bar segment animating in (not just appearing), and a satisfying haptic. This is a recommendation, not a hard requirement, consistent with how animation sections have been framed in the prior two docs.
3. **Toggle knob slide** (§6.2) — treat as required, not optional, per the reasoning given there.
4. **Reset confirm & edit-name dialogs** should reuse Play Loop's established modal entrance (scrim fade + card scale-in with slight overshoot) for consistency — the house style for modals is already set; don't invent a third modal-entrance treatment.
5. **Outcome card entrance** (arriving from Play Loop's `ended` phase): recommend a quick fade/scale-in of the whole card, consistent with "arriving at a payoff moment" — this is the screen every run ends on, worth a beat of polish, but keep it brief so replay-loop pacing (architecture's whole "one tap, a thousand ways to go" framing) isn't slowed down.

---

## 9. Platform conventions — additions specific to this batch

- **Ad screens are the one deliberate, total break from the sticker-button/pastel house style** (§4.1) — this is correct, not a bug, and shouldn't be "fixed" toward visual consistency.
- **Legal/rate/settings list rows** use standard platform list-tile press feedback, not the heavy sticker-button press-juice — appropriate, since they're navigational, not primary actions.
- **Back affordance gap** (§5.4/§6.1): recommend adding a standard leading back chevron to every `.scrhead`-based screen (Stats, Settings) even though the mockup's screenshots don't show one — a reasonable platform-standard fill-in, not a deviation.
- **Accessibility:** stat-tile taps, toggle states, and the reset/name dialogs should all expose their state via text/semantics as they already visually do (numbers and labels are already plain text, not icon-only) — no color-only state anywhere in this batch that needs a semantics-only fix, unlike Play Loop's life bar.
- **Reuse discipline:** this batch introduces zero new fundamental component *shapes* (button, modal, row, toggle, badge, chip are all either reused verbatim or straightforward color/size variants of existing ones) — resist the urge to build bespoke one-off widgets per screen; every screen in this doc should map to a small, already-established widget vocabulary plus new copy/color data.

---

## 10. Widget reuse map

| element | reuse existing widget? | notes |
|---|---|---|
| Outcome card body | **New** (`outcome_card.dart`) | but built from already-established primitives: bordered/shadowed container (cardbox), pill (badge), two-button row (reuses the Play Loop legend-pill/button spacing conventions) |
| Actions row buttons (Share/Again/Flex it/Nice) | **New thin variant of `StickerButton`** | 40dp height, 12dp radius, 4dp shadow — a new size tier, not identical to any existing one; add as another height/radius parameter set |
| Ad "Install" CTA | **New, deliberately not `StickerButton`** | flat, no border, no shadow — see §4.1 |
| Rewarded-offer "Watch to unlock" | **`StickerButton` variant** | blue fill, no text-shadow — parametrize `showLabelTextShadow: false` (already exists, used by the ghost variant) + a new fill color |
| Toggle switch | **New** (`settings_toggle.dart` or similar) | no existing precedent in onboarding/Play Loop |
| Note chip (positive + error variants) | **New, one widget, two color params** | error variant's colors were already implied in onboarding-v1.md, now pinned exactly (§1.3) |
| Reset-confirm / edit-name dialogs | **Reuse Play Loop's modal pattern verbatim** | scrim + `bg` card + 3dp border + 8dp shadow, per §6.4/§6.3 |
| Home's Play button | **`StickerButton` height variant** | 50dp, otherwise identical to the default `.cta` |
| Stat tile / streak card / week-bar | **New** | first appearance of this "dashboard tile" family |
| `.scrhead` header bar | **New, needs a back-chevron addition** (§5.4) | shared by Stats and Settings |

---

## 11. Consolidated list of resolved ambiguities / mockup gaps

Same rigor as the prior two passes — everything here is either an inference beyond the literal mock or a mockup inconsistency, flagged so a verification pass doesn't mistake it for a miss:

1. **4.1 (share sheet) is intentionally not built** — native OS chrome, not an app screen (§3.1).
2. **Eternal's "way"/"sub" split** doesn't match the architecture's general "sub = RunSummary stat" description — resolved as a paired pooled-flavor entry for Eternal only (§2.3).
3. **Home's missing gear icon** — architecture requires Settings to be reachable from Home; the mockup's 6.1 frame has no such icon. Filled with a recommended 28dp icon-button, reusing Play Loop's pause-icon treatment (§5.1).
4. **7-segment week-bar semantics beyond 7 days** — unresolved by mock or architecture; recommended `min(streak, 7)` capping, no calendar-week alignment (§5.1).
5. **Two non-identical week-bar sizes** (Home's mini 6dp/1.5dp-border vs. Streak-Advanced's 8dp/2dp-border) — don't collapse into one fixed size (§5.1).
6. **Missing back affordance on `.scrhead` screens** (Stats, Settings) — recommended adding a standard chevron (§5.4/§9).
7. **No name-edit dialog anywhere in the mockup** — filled in by reusing onboarding's input styling + Play Loop's modal pattern (§6.3).
8. **Reset-confirm copy mentions "collection,"** which is out of scope this pass — recommended trimming the copy (§6.4).
9. **5.3's missing close/X control**, despite `dismissedEarly` implying dismissal must be possible — resolved via hardware back, no on-screen X, matching the literal mock (§4.4).
10. **4.2's "Copied" variant** is likely unreachable given a single generic `Share.shareXFiles` call — recommended always showing "Shared" (§3.2).
11. **Sharing's tier-specific pre-share headline** ("Share your death" etc.) has no analog defined for Survived/Eternal, and is moot anyway since there's no in-app sheet to display it on — noted for completeness only (§3.1).

---

## 12. Explicitly out of scope (recap, don't spec or build)

Card-collection gallery (6.5), the offline screen (8.2), the photo-permission prompt (4.3), any real ad-network creative/branding, real legal policy text, and real SFX — all per architecture §1/§0 of this doc. 8.1 (name rejected) was already fully spec'd in onboarding-v1.md and is reused here, not re-spec'd.
