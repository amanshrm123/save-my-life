# Stay Alive — Outcome Story Cards Visual & UX Spec v1

**Scope:** redesign of the Outcome Cards feature (previously spec'd in `docs/design/remaining-screens-v1.md` §2, shipped) to the new 9:16 "story card" format.
**Source mockup:** `docs/mockups/timingtap_card_stories.html` (a standalone reference sheet, no phone-frame chrome this time — read fresh).
**Consumes:** `docs/architecture/v4.md` in full — several visual-adjacent decisions are founder-resolved there (dark-only death, 🆘 swap, dropped catalog line, restored "Top 0.3%," the fetch/loading mechanism) and this doc builds on them rather than re-litigating them.
**Extends:** `docs/design/onboarding-v1.md`, `play-loop-v1.md`, `remaining-screens-v1.md` — reuses all existing color/type/sticker-button tokens; only genuinely new tokens are defined here.
**Supersedes:** `remaining-screens-v1.md` §2 (Outcome Cards) for visual purposes. That doc's §2 is now historical — don't build from it for this feature; this doc is the current reference. `remaining-screens-v1.md`'s other sections (Sharing mechanism, Ads, Home, Settings, etc.) are unaffected and still current.

Design spec, not code — no Dart.

---

## 0. What actually changes, visually (recap of architecture v4 §0, visual lens only)

- One unified 9:16 card silhouette, replacing the old "badge pill above a separate bordered box."
- Death is **dark/inverted only** now — not a toggle, not the light variant the mockup also shows (that light `.death` treatment is superseded; see §4.1).
- Survived's chip emoji is **🆘**, not 🛟 (founder-resolved, tofu-rendering risk — don't use 🛟 anywhere, including the icon pool).
- Eternal's chip is **"✨ Eternal · Top 0.3%"** — restored as flavor copy, not a real stat.
- No catalog number anywhere ("Death #247 of 1000" is gone for good).
- A **minimum 2-second, tier-themed branded loader** shows every time, before every card.
- **App Store + Google Play badges** are now part of the card's footer — decorative, non-tappable, but genuinely rendered on-screen *and* baked into the shared image (see §6).

---

## 1. New design tokens

### 1.1 Per-tier color table (the load-bearing reference for this whole doc)

| tier | card bg | base text | chip fill | chip text | name-span (`.nm`) | wordmark "Alive" accent |
|---|---|---|---|---|---|---|
| **Death (dark/inverted — the only Death treatment now)** | `ink` `#1F2A2E` | `paper` `#FFFDF7` | red @ 20% over ink → `rgba(240,72,62,0.2)` (new token `deathChipFillOnDark`) | **`#FF8A82`** (new token `deathChipTextOnDark`) | **`#FF8A82`** — *not* plain `red` (see §4.1's contrast fix) | `coral` (unchanged — Death keeps the universal brand coral, doesn't retheme it) |
| **Survived** | `#EAFAF1` (new token `surviveCardBg`) | `#0C3B28` (new token `surviveInk`) | `#D3F2E1` (new token `surviveChipBg`) | `greenDark` (reused) | `greenDark` (reused — same value serves both roles) | `greenDark` (reused) |
| **Eternal** | **gradient** `linear-gradient(160deg, #FFF2D4 → #FFE0A8)` (new — see §1.2, this is a real change from the current flat-gold card) | `#5A3D00` (new token `eternalInk`) | `#5A3D00` (dark brown fill — same as base ink, an intentional "badge pops dark against the light gradient" inversion) | `gold` (reused) | **`#8A5A00`** — reuses the existing `AppColors.eternalNo` token from `remaining-screens-v1.md` §1.2 (identical hex; don't create a duplicate token, just point the new `.nm` usage at the existing one) | **`#A8720C`** (new token `eternalBrandAccent` — a **4th**, distinct brown; don't reuse `eternalNo`/`eternalWay`/`eternalName` for this) |

**Note on Eternal's browns:** this tier now has **four** distinct dark-amber shades in play across the app (`eternalNo #8A5A00`, `eternalWay #6B4600`, `eternalName #B5500E` from the old card, plus this doc's new `eternalBrandAccent #A8720C`). They are all subtly different and each has one specific role. Do not consolidate them — that's exactly the kind of "collapse the similar grays" mistake flagged in every prior pass, just with ambers this time.

**Note on Death's asymmetry:** Death is the only tier whose wordmark accent stays plain `coral` in both its light-and-now-superseded and dark treatments — Survived and Eternal each retheme the "Alive" word to their own accent color. This reads as intentional (Death is the "default/home" outcome keeping the pure brand mark; Survived/Eternal are the "special" outcomes that get a fully themed brand lockup) — preserve it, don't retheme Death's wordmark to red/coral-dark to "match" the others.

### 1.2 Eternal is now a gradient, not a flat color — a real implementation change

The current shipped card (`remaining-screens-v1.md` §1.2) has `cardFill: AppColors.gold` — a solid `Color`. The new mockup's `.eternal{background:linear-gradient(160deg,#fff2d4,#ffe0a8)}` requires a **`LinearGradient`**, not a solid fill. Flutter's `BoxDecoration.gradient` (not `.color`) is the mechanism — these are mutually exclusive on the same `BoxDecoration`, so this is a real code-shape change, not just a new hex. `begin`/`end` should map CSS's `160deg` to roughly `Alignment.topLeft`-ish → `Alignment.bottomRight`-ish (160° is close to "top, slightly right" → "bottom, slightly left" — recommend `Alignment(-0.3, -1)` → `Alignment(0.3, 1)` as a reasonable approximation; exact angle fidelity isn't critical for a two-stop pastel gradient at this size).

### 1.3 Store badge tokens — none new, deliberately

`.store{border:1.5px solid currentColor}` and the badge's own text inherit whatever the tier's base text color is (paper on dark Death, `#0C3B28` on Survived, `#5A3D00` on Eternal) — **no new color tokens needed**; the badge is border+text only, both `currentColor`, matching whatever ink/paper role the surrounding card already established. This is a deliberately simple, reused-color component.

### 1.4 Loader dot colors — generalized (see §7 for why)

| tier's loader | dot color |
|---|---|
| Death (dark) | `coral` (matches the mockup's dark-loader example exactly) |
| Survived | `greenDark` (new inference — the mock only shows Death's two variants) |
| Eternal | `eternalWay`-or-similar dark amber (new inference) — recommend `#5A3D00` (`eternalInk`) for simplicity, matching the card's own base ink |

---

## 2. The 9:16 card shell

### 2.1 Shape, radius, and — the one deliberate shadow exception in this whole app

`.card`: 26dp corner radius, **no border at all**, and a **soft, blurred drop shadow** — `offset (0, 16), blurRadius 36, color ink @ 20% opacity` (`rgba(31,42,46,0.20)`).

**This is a real, deliberate departure from every other component in the app**, which uses the "sticker" pattern (2–3dp ink border + hard, zero-blur, offset-only shadow). Two options were on the table; here's the call and the reasoning:

- **Adopt the mockup's soft shadow and borderless shape for the outer 9:16 card silhouette. Do not force the sticker pattern onto it.**
- **Why:** this card's entire purpose culminates in a rasterized export shared *outside* the app — to Instagram Stories, WhatsApp, wherever — where it will sit on top of someone else's photo, video, or story background, not this app's own pastel `bg`. A hard-edged sticker shadow is styled specifically to read well against *this app's* flat background; a soft, naturalistic shadow reads as "a floating card" against arbitrary external backgrounds, which is exactly the context this artifact actually lives in most of the time. The mockup itself is a dedicated, separate reference sheet for this one shareable artifact — every other element on it (loader, chip, store badge) also skips the sticker treatment, consistently, which reads as an intentional alternate visual system for this one specific export-oriented component, not an oversight to "fix" back to house style.
- **Scope of the exception:** this applies **only** to the outer 9:16 card shell (both the loading and resolved states, since both share one silhouette per architecture §7's `outcome_card_shell.dart`). It does **not** extend to anything outside the `RepaintBoundary` — the Share/Again action buttons and the confirm toast on the surrounding screen stay exactly as they are today (sticker-styled, hard shadow, unchanged from `remaining-screens-v1.md` §2). Flag this scope boundary clearly for a future verification pass: a hard-shadowed Share button sitting directly below a soft-shadowed card is *correct*, not an inconsistency to unify.

### 2.2 Dimensions — scale the card's contents to its box, don't fix them at the mockup's literal size

The mockup shows the card at a literal 250×445 (≈9:16, off by rounding). Per this project's established convention, mockup pixels are usable directly as dp — but that convention was built for *native, at-rest interactive screens* that are always viewed at whatever size a given phone happens to be. This component is different in kind: it's captured via `AspectRatio(9/16)` + `RepaintBoundary` at `pixelRatio: 3` (architecture §6) and its entire reason for existing is to produce a correctly-proportioned rasterized image, regardless of the source device's screen size.

**Recommendation — a deliberate departure from the "mockup px = dp directly" convention used everywhere else in this app, for this component only:**
- Let the card's outer box size responsively (`AspectRatio(9/16)` inside whatever `Expanded` space the screen gives it — same structural approach the current implementation already uses).
- Compute a single scale factor once the box's actual width is known: `k = actualWidth / 250` (the mockup's reference width).
- Multiply **every** internal dimension — font sizes, paddings, gaps, the icon/chip/store sizes, the corner radius — by `k`.
- This guarantees the exported share image always looks like a faithful, correctly-proportioned rendition of the mockup's reference composition regardless of whether it was captured on a small or large phone — the thing that actually matters for a shareable artifact, more than pixel-for-pixel native-screen fidelity does.

Every dimension quoted elsewhere in this doc (27dp headline, 26/22/22 padding, etc.) is the **reference value at `k = 1.0`** (i.e., at a 250dp-wide box) — scale by `k` for the real device.

---

## 3. Anatomy — resolved card (chip+icon / headline+story / footer)

```
┌────────────────────────────┐  26dp radius, no border, soft shadow
│ 26/22 top-inset padding    │
│ [ CHIP ]            (icon) │  .top row: space-between, vertically centered
│                            │  chip: pill, 10/700/UPPERCASE/.12em tracking
│                            │  icon: 28dp emoji, top-right (see §8 — NOT
│                            │  present on Eternal in the literal mock!)
│                            │
│      Headline text.         │  27/700/1.12 — notably larger than anything
│                            │  else in this app's type scale
│  Aman did the thing in a    │  14/500/1.4/opacity .85, name-span 700
│  one-sentence story.         │  weight, tier-colored
│                            │  ^ this whole block is vertically CENTERED
│                            │    in the available middle space — re-centers
│                            │    per-run as headline/story length varies
│                            │    (expected, not a bug)
│                            │
│  One tap saves you — or     │  tagline: 12/600/1.35/opacity .75, centered,
│   ends you.                  │  max-width ~200dp (at k=1.0)
│    💓 Stay Alive             │  wordmark: 19/700 overall; heart glyph is
│                            │  SMALLER (15dp) than the text beside it —
│                            │  a different ratio than the splash's big
│                            │  hero mark, don't reuse that proportion here
│ [🍎 App Store][▶ Play]      │  two store badges, side by side, gap 6dp
└────────────────────────────┘  22dp bottom-inset padding
```

Container: `Column` — `.top` row, then an `Expanded`/flexible middle region centered both axes (headline+story), then the footer column pinned at the bottom (tagline → wordmark → store badges, each 10dp gap, centered, `text-align: center`).

---

## 4. Per-tier specifics

### 4.1 Death (dark/inverted only) — the name-span contrast fix

Build **only** the `.death.inv` treatment. The mockup's plain `.death` (light, paper bg) card is **not built** — it's superseded by architecture's founder-resolved "dark/inverted by default" call. (The underlying *structural* pattern of "light bg, dark ink text" isn't wasted, though — it's exactly what Survived and Eternal already use; only Death itself moves off it.)

**Contrast fix, adopted as specified in your brief:** the mockup's literal CSS never overrides `.nm` (name-span) for `.death.inv`, so it would inherit plain `red` (`#F0483E`) on the near-black `#1F2A2E` card — architecture measured this at roughly 3.5:1, legible but weak. **Use `#FF8A82` for the name-span instead** (the same lighter red the mockup already defines for the inverted chip's own text) — this is the one place in this doc where the built card should render a color the literal mockup CSS doesn't actually specify for that element, because the mockup's own adjacent choice (the chip text) already established the "right" lighter red to use.

Chip: pill, fill `rgba(240,72,62,0.2)` (red at 20% opacity, painted over the ink card — implement as a semi-transparent red `Color` on top of the ink background, not a pre-blended opaque color, so it stays correct if the underlying card color ever changes), text `#FF8A82`, label **"💀 You died"**.

### 4.2 Survived

Chip: fill `#D3F2E1`, text `greenDark`, label **"🆘 Survived"** — the emoji swap from 🛟 applies to the chip label text *and* the icon pool (§8); don't leave 🛟 anywhere, including as a possible icon-pool draw.

### 4.3 Eternal

Chip: dark-brown fill (`#5A3D00`) with `gold` text, label **"✨ Eternal · Top 0.3%"** (static flavor copy — not computed, not a real percentile, per architecture's explicit founder-resolved reversal of the previous card's drop). Card fill is the two-stop gradient from §1.2. Four distinct browns are in play across the different text roles (§1.1) — don't collapse them.

### 4.4 No-name fallback

Same structural treatment as its tier (most commonly Death) — the story renders its anonymous variant with **no colored name-span at all**, exactly the same generic pattern already established in `remaining-screens-v1.md` §2.2 ("3.4 is not a fourth content pool"). Nothing new to spec here; same resolution, new layout.

---

## 5. Typography reference table

| role | size | weight | line-height | letter-spacing | opacity | notes |
|---|---|---|---|---|---|---|
| Chip | 10dp | 700 | — | 0.12em | 1 | uppercase |
| Icon (top-right slot) | 28dp | — | — | — | 1 | native emoji glyph, no color |
| Headline | 27dp | 700 | 1.12 | — | 1 | the single largest text anywhere in this app's type scale so far |
| Story/tale | 14dp | 500 | 1.4 | — | 0.85 | name-span (`.nm`) is 700 weight, same size, tier-colored |
| Tagline | 12dp | 600 | 1.35 | — | 0.75 | max-width ≈200dp at k=1.0, centered |
| Wordmark text ("Stay Alive") | 19dp | 700 | — | — | 1 | |
| Wordmark heart glyph | **15dp** | — | — | — | 1 | smaller than the wordmark text — a different ratio than onboarding's splash hero mark; don't unify them |
| Store badge label line 1 ("Download on"/"Get it on") | 8dp | 600 | 1 | — | 1 | |
| Store badge label line 2 (bold store name) | 10dp | 700 | 1 | — | 1 | stacked directly below line 1, same badge |
| Store badge icon glyph | 12dp | — | — | — | 1 | see §6 — App Store's is blank in the mockup |
| Loading headline ("Loading your life card…") | 19dp | 700 | — | — | 1 | numerically matches the wordmark's 19dp — coincidental, not a shared role |
| Loading subline | 12dp | 600 | — | — | **0.6 light / 0.55 dark** | two genuinely different opacity values per variant — don't collapse to one |
| Pulsing heart (loader) | 44dp | — | — | — | animated 1↔0.7 | see §7 |

All sizes are reference values at `k = 1.0` (§2.2) — scale by the card's actual box width.

---

## 6. Store badges

```
┌──────────────────────┐
│ [🍎]  Download on     │  border: 1.5dp solid currentColor, radius 8dp,
│       App Store       │  padding 5×9dp, gap 5dp between icon and text,
└──────────────────────┘  both text lines left-aligned within the badge

┌──────────────────────┐
│ [▶]   Get it on        │
│       Google Play      │
└──────────────────────┘
```

Two badges, 6dp gap between them, centered as a row at the very bottom of the footer stack. Both are **plain, non-interactive containers — no tap handler, no ripple, no `GestureDetector` at all** (they're purely decorative; there's no risk of accidentally triggering Share/Again since those buttons live outside the card entirely, per the existing v3 screen structure). They render **on-screen at all times** on the resolved card, not only in the exported share image — "decorative only" means non-tappable, not screen-invisible; they're inside the `RepaintBoundary` specifically because they need to appear in both places identically (architecture §6.2).

**A genuine mockup gap — the App Store icon slot is empty.** The mockup's markup literally has `<span class="si"></span>` for the Apple badge (no glyph at all) versus `<span class="si">▶</span>` for Google Play (a real play-triangle character). **Recommendation: leave the Apple icon slot blank, exactly as shown** — sourcing/building a proper Apple-logo glyph or icon asset for a purely decorative badge on a platform this project doesn't even build for (per this project's own "no Apple ID, iOS blocked" status) isn't worth the effort. Ship the App Store badge with its icon slot empty, matching the mockup precisely rather than inventing a placeholder glyph.

---

## 7. Loading state — generalized to all three tiers

The mockup shows exactly two loader examples: light (using the plain `.death` palette) and dark-inverted (`.death.inv`). **Neither corresponds to any single real tier once Death goes dark-only** — the "light" example's specific palette (paper bg / ink text / red dots) isn't literally reused by any tier now (Survived and Eternal have their own distinct light palettes, not the plain paper/ink one shown). Treat the two examples together as establishing the **loader anatomy and animation timing pattern only** — then recolor per each tier's own resting palette (architecture §4: "the loader is already tier-themed... uses the final tier palette immediately"). Concretely, this doc's job is to generalize 2 shown examples into the 3 actually-needed variants:

| tier | card palette | dot color |
|---|---|---|
| Death | dark/inverted (`ink` bg, `paper` text) | `coral` (matches the mock's dark example) |
| Survived | `#EAFAF1` bg, `#0C3B28` text | `greenDark` (inferred, not shown) |
| Eternal | gradient bg, `#5A3D00` text | `eternalInk` `#5A3D00` (inferred, not shown) |

### 7.1 Layout (same for all three)

The loader overrides the resolved card's normal 3-part layout entirely — everything centers both axes:

```
┌────────────────────────────┐
│                            │
│           💓               │  44dp, pulsing (see below)
│  Loading your life card…    │  19/700
│         ● ● ●               │  3 dots, staggered bounce (see below)
│  Every ending is one of a   │  12/600, opacity .6 (light) / .55 (dark)
│   thousand. Let's see        │  max-width ≈180dp at k=1.0
│   which one you got…         │
│                            │
│        💓 Stay Alive         │  wordmark ONLY — no tagline, no store
│                            │  badges during loading (they only appear
└────────────────────────────┘  on the resolved card's footer)
```

**Copy, verbatim:** headline "Loading your life card…", subline "Every ending is one of a thousand. Let's see which one you got…".

### 7.2 Animation timing (exact, from the mockup's keyframes)

- **Heartbeat pulse:** `scale(1)→scale(1.18)→scale(1)`, opacity `1→0.7→1`, over **1s, ease-in-out, infinite loop**.
- **Dot bounce:** each dot translates `Y: 0 → -6dp → 0`, opacity `0.4 → 1 → 0.4`, over **0.9s, ease-in-out, infinite loop**, staggered with **0s / 0.15s / 0.3s** start delays across the three dots (a classic loading-dots stagger — implement as one shared `AnimationController` with three `Interval`-shifted curves, per architecture §8's "one `Ticker`, not four" memory-safety note, not three independent controllers).
- Dot size: 9dp diameter circles.
- These loop for however long the actual fetch takes, guaranteed ≥2s by the provider layer (architecture §2) — the loader has no fixed "duration" of its own; it just runs until the `AsyncValue` resolves, then unmounts (and its single `AnimationController` disposes with it).

### 7.3 Screen-level button states during loading (a gap neither mockup nor architecture's visual layer addresses)

The mockup only shows the loader *card*; it doesn't depict the surrounding screen's Share/Again action row during that phase. Architecture §6.3 requires gating Share on `hasValue`. Recommend:
- **Share:** visible but disabled — reuse this app's established disabled-button convention (opacity 0.45, non-interactive), the same treatment used for onboarding's "Start playing" and Play Loop's dimmed STOP button. Don't hide it outright; a disabled-but-visible Share reads as "not ready yet" rather than "doesn't exist."
- **Again:** stays fully enabled throughout loading — nothing about "Again" depends on the current card's content, and there's no reason to block a player from bailing to another run while one card is still fetching (the `autoDispose` family entry is simply abandoned).

---

## 8. Icon slot — a genuine, concrete mockup inconsistency

Per your brief: top-right, 28dp, on the same row as the chip. Confirmed for **Death and Survived** — both show a `.top` row with the chip on the left and a 28dp emoji on the right, `space-between`, vertically centered.

**But Eternal's mockup markup has no icon slot at all** — its `.top` row contains only the chip, nothing on the right:
```html
<div class="top"><span class="chip">✨ Eternal · Top 0.3%</span></div>
```
This directly contradicts architecture §1's data model, which defines a real `eternalIcons` pool (`['✨','👑','🏆','🌟']`) — a pool that, per the literal mockup, would have nowhere to render.

**This needs a decision; recommendation:** show the icon slot on the Eternal card too, top-right, identical 28dp treatment to Death/Survived, actually drawing from the `eternalIcons` pool architecture already built — for two reasons: (1) visual consistency across all three tiers (an asymmetric "two tiers have a top-right icon, one doesn't" reads as an oversight, not a deliberate design choice — nothing in the mockup's captions calls out Eternal's omission as intentional), and (2) otherwise `eternalIcons` is dead data with no visual purpose, which is a wasted part of the content model. If this recommendation is **not** adopted, the `.top` row layout must still handle the chip-only case gracefully — a single left-aligned chip with no reserved empty space on the right, not an awkward gap where an icon "should" be.

---

## 9. Entrance animation — confirming what carries over

Two notes, correcting and confirming pieces of the brief:

1. **There is no `_FlashPill` in the current `outcome_card.dart`** — verified directly against the shipped v3 implementation and a repository-wide search; no class by that name exists anywhere in this codebase. (`OutcomeFlash`, the PERFECT/HIT/MISS tier flash, belongs to the unrelated Play Loop feature and has no bearing on this redesign.) Nothing to reconcile here beyond the entrance-controller question below.
2. **The existing entrance treatment carries over unchanged, just retimed.** The shipped card's entrance animation — fade + scale from 0.92→1.0, ~260ms, `Curves.easeOutBack` — is still the right visual treatment for the resolved card appearing. Architecture §4 already specifies the *mechanical* fix (move `.forward()` out of `initState` into a `ref.listen` callback on the loading→data transition, guarded to fire once). Visually, nothing new is needed: the same entrance beat, now triggered when content resolves instead of at screen-mount. **No separate crossfade of the outgoing loader is needed** — `AsyncValue.when` swaps the whole subtree, and the incoming resolved card's own fade+scale-in is sufficient to read as a deliberate "reveal" rather than a jarring cut.

---

## 10. Consolidated list of resolved ambiguities / gaps

Same rigor as the prior four passes:

1. **Eternal's missing icon slot** (§8) — the mockup's own layout contradicts architecture's data model (a defined `eternalIcons` pool with nowhere to render). Recommended: add the icon slot to Eternal too, for consistency and to avoid dead content data.
2. **Loader generalization to 3 tiers** (§7) — only 2 examples shown (both effectively "Death," pre- and post- the dark-only decision); neither literally represents Survived or Eternal's real resting palette. Generalized via each tier's own §1.1 colors.
3. **Two distinct loader subline opacities** (0.6 light / 0.55 dark, §5/§7.1) — don't collapse to a single shared value.
4. **App Store badge's blank icon slot** (§6) — recommended leaving it blank, matching the mock exactly, given the platform isn't even a build target for this project.
5. **Screen-level Share/Again button states during loading** (§7.3) — not shown by the mockup (which only depicts the card, not the surrounding screen chrome) or specified by architecture's visual layer; filled in via this app's existing disabled-button convention.
6. **Card shell's soft-shadow/borderless exception** (§2.1) — a deliberate, singular departure from the house sticker pattern, scoped explicitly to the 9:16 card only, not the surrounding screen's buttons.
7. **Story/headline content length isn't visually bounded anywhere** — the fixed 9:16 box with vertically-centered, fixed-size type means very long authored copy could overflow the middle region. This is a content-authoring constraint, not a Flutter problem to solve with dynamic font-shrinking (which would fight the proportional-scale approach in §2.2) — flag to whoever authors/extends the 66 pooled entries: keep headlines to ~2 lines and stories to ~4 lines at the reference scale.
8. **The literal "N/A" fallback text is a rough edge on a shareable, social-facing artifact** — architecturally resolved (that's genuinely what renders on a failed fetch), but worth a copy pass at some point given this card can be shared to Instagram/WhatsApp exactly as shown; not blocking, just flagged as a UX-quality note since a bare "N/A" reads as broken rather than "unlucky."

---

## 11. Explicitly unchanged / out of scope for this doc

The sharing mechanism itself (native OS sheet, `CardRenderer`/`ShareService`), the ad-interstitial cadence and "Again" flow, Home/Settings/Notifications, and the Play Loop hand-off (`pushReplacement` to `OutcomeCardScreen(summary:)`) are all untouched by this redesign — see `remaining-screens-v1.md` and `play-loop-v1.md` for those, still current. This doc's scope is strictly the outcome card's own visual redesign.
