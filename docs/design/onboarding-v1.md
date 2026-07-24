# Stay Alive — Onboarding Visual & UX Spec v1

**Scope:** mockup Section 1 "First launch & onboarding" only (`docs/mockups/timingtap_screen_library_v3-4.html`, section id `#a`, screens 1.1–1.5).
**Consumes:** `docs/architecture/v1.md` (Riverpod, single `OnboardingScreen` hosting a 4-page `PageView`, `PlayerProfile{name, onboardingComplete}`, Fredoka bundled as a local asset).
**Consumed by:** `flutter-developer` (build from this doc) and a later `game-ux-designer` verification pass (hold the built screens up against this doc + the mockup).

This doc is a **design spec, not code** — no Dart. Where a Flutter mechanism is named (e.g. "zero-blur `BoxShadow`"), it's describing *what effect to reach for*, not literal syntax.

---

## 0. Source-of-truth values (pulled from the mockup's `:root`)

```css
--bg:#c8ecd9;      --ink:#1f2a2e;     --paper:#fffdf7;   --paper-2:#f2efe6;
--coral:#ff7a59;   --coral-d:#e5613f; --green:#2fbf71;   --green-d:#1f9c58;
--red:#f0483e;     --gold:#ffc23c;   --gold-d:#e5a516;  --mute:#7b8a86;   --blue:#4a9fd8;
```

Two **additional grays appear in the CSS that are not the `--mute` token** — do not collapse them into one:

| token (informal name) | hex | used for |
|---|---|---|
| `mute` (var) | `#7b8a86` | helper text, char counter, disabled/secondary labels |
| `body-mute` (hardcoded, class `.d`) | `#4a5f5a` | the tagline / description paragraph under every headline |
| `dot-inactive` (hardcoded, class `.dots i`) | `#a7c4b8` | inactive page-dot fill |

All three are cool grays close in value — easy to typo-merge into one constant. Keep them distinct in the theme file.

---

## 1. Design tokens

### 1.1 Color roles used in screens 1.1–1.5

| role | hex | notes |
|---|---|---|
| Screen background | `#c8ecd9` (`--bg`) | flat, no gradient |
| Ink (borders, primary text, shadows) | `#1f2a2e` | every sticker border and every hard drop-shadow is this color |
| Paper (card/input fill) | `#fffdf7` | input background |
| Coral (primary/final CTA) | `#ff7a59` / shadow-text `#e5613f` | **only** on "Start playing" (1.5). Teach-card buttons are green, not coral. |
| Green (teach-card CTA + splash progress fill) | `#2fbf71` / shadow-text `#1f9c58` | "Next" / "Got it" buttons |
| Red (error state only) | `#f0483e` | name-rejected input border/text (screen 8.1, referenced from 1.5's error state) |
| Mute gray | `#7b8a86` | helper row text, char counter |
| Body-mute gray | `#4a5f5a` | tagline/description paragraphs |
| Dot-inactive gray | `#a7c4b8` | inactive page dots |

### 1.2 Typography

Font family: **Fredoka** (bundled local asset per architecture §7), fallback `system-ui, sans-serif`. Weights in use: 400, 500, 600, 700.

| role | size | weight | line-height | color | used in |
|---|---|---|---|---|---|
| Emoji mark (`.big`) | 38 | n/a (native glyph) | 1 | n/a | all 5 screens' central icon |
| Wordmark ("Stay / Alive!") | 32 | 700 | 0.9 | ink / coral | 1.1 only |
| Headline (`h3.t`) | 17 | 700 | 1.1 | ink | 1.2, 1.3, 1.4, 1.5 |
| Body / tagline / description (`.d`) | 11.5 | 600 | 1.45 | `#4a5f5a` | all 5 (tagline on 1.1, instructional line on 1.2–1.4, "Goes on your cards." on 1.5) |
| Button label (`.cta`) | 14 | 700 | 1 | white (on green/coral) | Next / Got it / Start playing |
| Ghost text link ("Skip for now") | 11 | 600 | 1 | `#7b8a86`, underlined | 1.5 only |
| Input text | 16 | 700 | 1 | ink, centered | 1.5 |
| Helper row / char counter | 9 | 600 | 1 | `#7b8a86` | 1.5 |

Note on the wordmark: the coral "Alive!" span carries its own hard offset text-shadow (`0 2px 0 var(--coral-d)`, zero blur) — a mini embossed/sticker-text effect, not a soft glow. Reproduce with a text shadow that has `blurRadius: 0`, not Flutter's default blurred shadow.

### 1.3 Spacing / layout constants

- Screen horizontal content padding: **20dp** each side (from `.center{padding:20px}`) — applies to all 5 screens.
- Vertical rhythm inside the centered column: **10dp** gap between stacked elements (from `.center{gap:10px}`), as a baseline — see per-screen notes for two deliberate deviations (progress bar gets 14dp above it; the name-capture helper row should hug the input tighter than 10dp, see §3.5).
- Body/description paragraph max width: mock uses 170px inside a 224px-wide thumbnail frame (~76% of frame width). **Do not hardcode a fixed px on real devices** — constrain the paragraph to roughly **75–80% of screen width, capped at ~320dp**, centered. This keeps line length readable on both a small ~360dp phone and a wide tablet/foldable without the mockup's literal pixel value meaning anything device-specific.
- **Scale decision:** treat every other mockup pixel value (font sizes, button heights, border widths, radii, shadow offsets) as **usable directly as logical pixels (dp)** on a real device — they already read as normal mobile UI sizes (17dp headline, 44dp button, etc.), so no rescaling factor is needed. The 224×466 phone frame in the HTML is just a shrunk thumbnail for fitting many screens on one reference sheet; it is not a scale cue.

### 1.4 The "sticker button" pattern

CSS trick: `border: 2.5px solid var(--ink)` + `box-shadow: 0 Npx 0 var(--ink)` (zero blur-radius, solid offset) + a border-radius. The box-shadow is a **hard-edged**, unblurred, ink-colored rectangle offset straight down by `N`px, peeking out from behind the bottom edge — it reads as a thick "shelf" the button sits on, not a soft elevation shadow.

**Flutter translation:** Flutter's shadow primitive supports `blurRadius: 0`, which produces exactly this hard, unblurred edge — so this does **not** need a layered Stack trick; a single decorated container (ink border + ink-colored zero-blur shadow offset down by N + matching border-radius) reproduces it directly, as long as the parent doesn't clip the painted shadow region and layout below the button reserves the extra `N`dp so the shelf doesn't overlap the next element.

Do **not** build these as default `ElevatedButton`s — their built-in Material elevation/shape model fights this effect. Spec them as a custom "sticker button" shape (bordered container + press-state animation, see §5) reused across the whole app, not just onboarding.

| button | height | radius | border | shadow offset | fill | text-shadow (label) |
|---|---|---|---|---|---|---|
| `.cta` (Next / Got it) | 44dp | 14dp | 2.5dp ink | 5dp down, ink | green `#2fbf71` | `0 1.5px 0 #1f9c58` |
| `.cta.coral` (Start playing) | 44dp | 14dp | 2.5dp ink | 5dp down, ink | coral `#ff7a59` | `0 1.5px 0 #e5613f` |
| disabled sticker button (Start playing, empty/invalid name) | same | same | same | **same geometry, no press interaction** | opacity **0.45** (reuse the app's existing disabled-button convention from the Play Loop's dimmed STOP button) | — |

"Skip for now" (1.5) is **not** a sticker button — it's a bare underlined text link (`background:none;border:none;text-decoration:underline`, mute gray, 11dp/600). Keep it visually flat and de-emphasized; do not "upgrade" it to a bordered ghost button — that would compete with the coral primary CTA, which is the opposite of the mock's intent (Skip is deliberately the quiet option).

### 1.5 Dot page indicator

- 3 dots, 7dp diameter circles, 6dp gap between them.
- **Every** dot — active or inactive — has a 1.5dp ink border. Only the fill color changes:
  - inactive fill: `#a7c4b8`
  - active fill: coral `#ff7a59`
- Shown only on pages 0, 1, 2 (teach cards). Rendered as nothing (zero height, not just invisible) on page 3 (name capture) — matches architecture's PageView table.
- Behavior across 1.2 → 1.3 → 1.4: dot 1 active on page 0, dot 2 active on page 1, dot 3 active on page 2. Exactly one dot active at a time; no multi-active or "filled trail" state.

### 1.6 Name input styling

- Container: 46dp height, full width (within the 20dp screen padding), 14dp radius, 2.5dp ink border, paper `#fffdf7` fill.
- Text: 16dp, weight 700, centered horizontally.
- Hard cap: **12 characters**, enforced live at the input-formatter level (matches architecture §5's `maxLength`).
- Helper row directly below the input: `justify-content: space-between`, left label **"On your cards"**, right **live counter "n/12"** (e.g. "4/12"), both 9dp/600/mute gray, with a small ~3dp extra horizontal inset relative to the input's own edges so the caption text doesn't align flush to the input's rounded corners.
- **Important divergence from the static mock:** the mock shows the input *pre-filled* with `"Aman"` and the counter frozen at `"4/12"` — that's the sheet's example persona used throughout the whole document for illustration, **not** a literal default value. The real field must start **empty**, with the counter at `"0/12"`, and no submit-disabling copy until the player types. If a placeholder/hint is wanted, use a light example like *"e.g. Aman"* in mute gray — optional, not required by the mock.
- Error state (profanity/disallowed word, surfaces inline on this same page per architecture §5, visual reference = mockup screen 8.1): border and input text switch to red `#f0483e`, headline copy becomes **"Pick another name"**, an inline note banner appears below the input reading **"That word isn't allowed — it shows on shared cards"** (red text on a light red chip background), and the primary button becomes **"Try again"**. This is a state of the *same* name-capture page, not a separate route.

---

## 2. Per-screen specs

All 5 screens share this shell: full-bleed background `#c8ecd9`, content wrapped in `SafeArea`, a single centered column (`MainAxisAlignment.center`, `CrossAxisAlignment.center`), 20dp horizontal padding, 10dp gap rhythm between elements unless noted.

> The mock's `9:41 / 100%` status-bar row visible at the top of every phone frame is mockup chrome depicting where the OS status bar sits — **do not build it**. Rely on `SafeArea` and the real platform status bar.

### 2.1 Screen 1.1 — Splash

```
┌────────────────────────────┐
│                            │
│           💓               │  38dp emoji
│                            │
│          Stay              │  32/700/0.9, ink
│         Alive!             │  32/700/0.9, coral, hard text-shadow
│                            │
│  "One tap. A thousand      │  11.5/600, #4a5f5a, centered,
│   ways to go."             │  max-width ~75-80% screen, capped ~320dp
│                            │
│    [====progress====]      │  110dp wide × 8dp tall pill track,
│                            │  2dp ink border, 1.5dp inset padding,
│                            │  green fill, margin-top 14dp above this
└────────────────────────────┘
```

Copy (verbatim): wordmark **"Stay"** / **"Alive!"**, tagline **"One tap. A thousand ways to go."**

States: **loading only** — there is no error/empty state here (a prefs-read failure defaults silently per architecture §8.7). Progress bar must actually animate 0%→100% over the splash's hold duration (see §4) — the mock's static 70% fill is a screenshot freeze-frame, not a target resting state.

### 2.2 Screen 1.2 — Teach card 1/3

```
┌────────────────────────────┐
│           👆               │
│                            │
│   Tap on the number        │  17/700 headline
│                            │
│  "A target time appears.   │  11.5/600, #4a5f5a
│   Tap the instant it hits."│
│                            │
│        ● ○ ○               │  dots: dot 1 active (coral)
│                            │
│   ┌─────────────────────┐  │
│   │        Next         │  │  .cta green, 44dp, full width−40dp
│   └─────────────────────┘  │
└────────────────────────────┘
```

Copy (verbatim): headline **"Tap on the number"**, body **"A target time appears. Tap the instant it hits."**, button **"Next"**.

### 2.3 Screen 1.3 — Teach card 2/3

Same layout as 2.2. Copy: emoji ❤️, headline **"Mind your life"**, body **"Nail it, gain life. Miss, lose it. Hit 0% and you're gone."**, dots ○ ● ○ (dot 2 active), button **"Next"**.

### 2.4 Screen 1.4 — Teach card 3/3

Same layout as 2.2/2.3. Copy: emoji 🔀, headline **"Three ways it ends"**, body **"Die, survive a last save, or go Eternal. All shareable."**, dots ○ ○ ● (dot 3 active), button label changes to **"Got it"**.

Implementation note: this is the same `.cta` green button widget as "Next" — only the label string changes based on page index (index 2 → "Got it"), same color/shadow/radius. Do not build a visually distinct button for the last card.

### 2.5 Screen 1.5 — Name capture

```
┌────────────────────────────┐
│           ✍️               │
│                            │
│  What should we call you?  │  17/700 headline
│                            │
│      "Goes on your cards."  │  11.5/600, #4a5f5a
│                            │
│   ┌─────────────────────┐  │
│   │                     │  │  46dp input, 14dp radius, 2.5dp ink border,
│   │      (empty)        │  │  paper fill, 16/700 centered text, cap 12
│   └─────────────────────┘  │
│   On your cards      0/12  │  9/600 mute, space-between row
│                            │
│   ┌─────────────────────┐  │
│   │   Start playing     │  │  .cta.coral, 44dp — DISABLED (opacity .45)
│   └─────────────────────┘  │  until name length ≥ 1 & passes live checks
│                            │
│       Skip for now         │  11/600 mute, underlined, no box
└────────────────────────────┘
```

Copy (verbatim): headline **"What should we call you?"**, body **"Goes on your cards."**, helper label **"On your cards"**, counter **"n/12"**, primary button **"Start playing"**, secondary link **"Skip for now"**.

No dots on this page (per architecture's PageView table).

**States for this screen (flutter-developer must implement all of these):**

| state | trigger | visual |
|---|---|---|
| empty | page loads / name cleared | input empty, counter "0/12", "Start playing" at opacity 0.45 and non-interactive |
| typing / valid | player types 1–12 allowed characters | counter live-updates ("n/12"); "Start playing" becomes fully opaque and tappable the moment length ≥ 1 (character-set validity can gate this too — see architecture §5 rule 3) |
| at cap | length hits 12 | input formatter blocks further characters; counter reads "12/12"; optional (nice-to-have, not required for v1) subtle color shift on the counter to signal the limit |
| submitting | "Start playing" tapped, valid name | brief tap-lock per architecture §8 rule 3 (guard against double-tap re-entrancy) — no spinner needed, this is a fast local prefs write, just make the button briefly non-interactive |
| rejected (profanity) | submit fails the disallowed-word check | border + input text → red, headline text swaps to "Pick another name", inline red note appears ("That word isn't allowed — it shows on shared cards"), button label swaps to "Try again"; recommend an ~300ms horizontal shake on the input plus a medium haptic buzz (see §4) |
| keyboard open | text field focused | see §6 — column must not clip; prefer resizing/scrolling over vertical squeeze |

---

## 3. Cross-screen behavior

### 3.1 PageView structure (consistent with architecture v1 §2)

One `PageView`, 4 pages (0=teach1, 1=teach2, 2=teach3, 3=name capture). Dots render on 0–2, nothing on 3. "Next"/"Got it" buttons on 0–2 advance one page; page 3 has no forward button of its own beyond "Start playing"/"Skip for now", which are terminal actions, not page-advance actions.

### 3.2 Swipe vs. button-tap parity

Both a manual left-swipe and tapping "Next"/"Got it" must produce the same destination page. Swiping backward (right) from any teach card is always allowed and free (no gating), consistent with dots simply reflecting whatever page is currently settled.

### 3.3 Dot indicator during transitions

Baseline (required): dot indicator snaps to the new active dot the instant the destination page is settled (whether by swipe or button tap) — instant color swap, no animation needed to meet spec.

Nice-to-have (flag as later-phase polish, not required for v1): animate the dot's fill color over ~150–200ms rather than snapping, and/or interpolate the active dot fractionally between two dots while the user is mid-drag on a manual swipe. Skip both if they add meaningful implementation time — the discrete snap is fully spec-compliant.

### 3.4 "Next"/"Got it" and "Start playing"/"Skip" never coexist

Screens 1.2–1.4 each show exactly one primary button (no secondary link). Screen 1.5 is the only screen with both a primary sticker button and a secondary text link.

### 3.5 Name-capture spacing deviation

Deviate slightly from the flat 10dp gap rhythm here: the helper row ("On your cards" / "n/12") should sit **closer** to the input than a full 10dp gap (recommend ~6–8dp) since it functions as a caption of the input, not an independent element — grouping it visually with the field it describes reads more clearly than treating it as another item in the generic vertical stack.

---

## 4. Animation / juice recommendations

This is a playful, tactile brand ("sticker" ink-outline aesthetic) — the interactions should feel snappy and slightly springy, not flat/instant, but this is a short one-time flow so keep every animation quick; nothing here should ever make the player feel like they're waiting on the app.

1. **Splash progress bar:** animate width 0%→100% over the full splash hold duration. Recommend **~1.4s** total (within architecture's flagged 1.2–1.8s range for a lightweight brand beat, since there's no real preload work happening — unlike the Play Loop's 5s loader). Curve: `Curves.easeOut` (starts brisk, settles gently) rather than linear, so the bar doesn't feel mechanical. Hold at 100% for ~150–200ms before transitioning out, so completion doesn't feel abrupt.
2. **Splash → Teach card 1:** simple fade or fade+slight-upward-slide, ~250–300ms, `Curves.easeInOut`. This is a `pushReplacement` (non-back-navigable per architecture §2), so no shared-element continuity is needed — just a clean brand-to-content handoff.
3. **Teach-card page transitions (button-triggered):** animate the `PageController` to the next page over **~300ms** with `Curves.easeInOutCubic` — snappy but settled, matching typical casual-game card-swipe pacing. Manual swipes use the `PageView`'s native drag physics untouched.
4. **Sticker button press feedback (the single most important juice moment on these 5 screens, since it's the tactile response to every tap):** on tap-down, animate the button "pressing into" its ink shelf — translate it down and shrink the visible offset-shadow gap (e.g. from 5dp to ~2dp) over a very fast **~80–100ms**; on release, spring back over **~120–150ms** with a slight overshoot (`Curves.easeOutBack`) for a satisfying pop. Pair with a light haptic tap (`selectionClick`/`lightImpact`-equivalent) on every primary sticker-button press — haptics are already a first-class, user-facing setting in this game (Settings 7.1 has a Haptics toggle default-on), so onboarding should establish that tactile identity from the very first button tap.
5. **Emoji mark entrance (nice-to-have, later-phase polish):** a small scale-in (0.85→1.0, `Curves.easeOutBack`, ~350–400ms) each time a new page's emoji settles into view. Skip or minimize on low-end devices if it risks jank — this is pure delight, not required for the loop to feel functional.
6. **Name-rejected error state:** ~300ms horizontal shake (small amplitude, ~6–8dp) on the input as the border/text flip to red, plus a medium-strength haptic buzz, to make the rejection register instantly without requiring the player to read the copy first.
7. **Char counter:** live text update, no animation required. Optional (later-phase): brief color pulse when hitting 12/12.

---

## 5. Platform conventions — what to keep, what to deliberately break

**Deliberately broken (intentional brand differentiation — this is correct, not a bug):**
- Custom "sticker" buttons instead of default `ElevatedButton` Material styling/elevation.
- Hard offset (zero-blur) shadows instead of standard blurred Material elevation shadows.
- Fredoka instead of the platform default (Roboto on Android / SF on iOS).
- A skippable, condensed 4-page onboarding rather than a longer platform-standard multi-permission-request flow — appropriate for a casual, ad-light/ad-free-during-play game where session friction before the first run should be minimal.

**Keep standard (don't "reinvent" these just because the visuals are custom):**
- `SafeArea` for status bar / notch / gesture-nav insets — never hand-draw the mock's fake status bar row.
- Standard Android back-gesture/back-button semantics on the teach cards (architecture §8 rule 10: back animates to the previous page when page > 0; page 0 falls through to normal app-exit behavior unless founder overrides).
- Minimum touch target sizing — the 44dp `.cta` height already clears the ~44–48dp target-size guideline; don't shrink it for visual tightness.
- Standard system keyboard behavior on the name input (no custom keyboard), though `TextCapitalization.words`-equivalent behavior is a reasonable nice-to-have default for a name field.
- Accessibility: provide semantic labels for the decorative emoji glyphs (they're not meaningful to screen readers as raw glyphs), and make sure the dot indicator's page position is announced semantically (e.g. "page 1 of 3"), not conveyed by color alone.
- Skip for now stays a flat underlined text link, never a bordered sticker button — see §1.4.

---

## 6. Responsive behavior across phone sizes

- All horizontal sizing is padding/percentage-driven (20dp fixed insets, buttons full-width within those insets), so width responsiveness is inherent — no fixed pixel widths to fight on different phone widths (~360dp–430dp Android range, per this project's Android-first dev target).
- Cap the centered column's overall width on very wide viewports (tablets, unfolded foldables, and the web dev target) at roughly **430–480dp**, centered, rather than letting text/buttons stretch edge-to-edge indefinitely.
- Cap the body/description paragraph width per §1.3 (≈75–80% of screen width, hard-capped ~320dp) so line length stays readable at any device width.
- **Keyboard-open state on 1.5 (required, not optional):** when the system keyboard appears, do not let the vertically-centered column simply get squeezed/clipped. Prefer the standard resize-to-avoid-keyboard behavior so the whole column shifts up, and if vertical space is still tight (small phones, or with platform font-scaling accessibility settings increased), fall back to a scrollable column so nothing is ever clipped or unreachable. This matters specifically on 1.5 since it's the only screen with a focusable text field.
- Very short-height devices / large system font scaling: wrap each screen's centered content in a scroll fallback so increased text-scale settings never overflow/clip rather than assuming the mock's tight vertical rhythm always fits.

---

## 7. Explicitly deferred (flagged, not required for this pass)

Per the "push back on scope" mandate — these are legitimate nice-to-haves noted above, restated here so they don't get silently treated as requirements by a future verification pass:
- Animated (rather than snap) dot-indicator color transitions and fractional drag-interpolation (§3.3).
- Emoji-mark scale-in entrance animation (§4.5).
- Char-counter color pulse at 12/12 (§1.6 / §4.7).
- `TextInputAction.done` wired to auto-submit "Start playing" and any hint/placeholder text in the empty input (§1.6) — reasonable defaults, not mock-mandated.

None of these block a correct, spec-compliant build of screens 1.1–1.5; they're candidates for a later polish pass.
