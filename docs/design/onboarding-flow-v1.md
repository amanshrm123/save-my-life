# First Launch & Onboarding Flow — v1

*Companion spec to `docs/architecture/v2.md` §5 "Days 12–14 — Onboarding + Home/progression" (this document covers the **onboarding** half only — screen-library §1, screens 1.1–1.5, plus the name-rejected edge state 8.1, which v2's phase plan bundles into the same days as onboarding, see §0 below). Home/Stats/streak-broken (6.1–6.3) are the other half of Days 12–14 and are explicitly **not** covered here — they need their own companion spec. Source of visual truth: `docs/design/screen-library-v3.html` id="a". Builds on the same disciplined, exact-enough-to-build-from style as `docs/design/play-screen-skeleton-v1.md` and `docs/design/play-screen-gate1-v1.md`, but unlike those two "bare debug" specs, this one is a pivot to **real visual fidelity** — actual colors, shapes, and a bundled font, not placeholder Text widgets. This is a direct response to the founder's Gate 1 playtest feedback (relayed by player-reviewer) that the bare prototype read as unfinished — onboarding is the player's very first impression and must not repeat that mistake.*

---

## 0. Scope of this document

**In scope:** 1.1 Splash, 1.2 Teach-the-tap, 1.3 Teach-the-life-bar, 1.4 Teach-the-endings, 1.5 Name capture, **and** 8.1 Name-rejected.

8.1 is included even though the task brief flagged it as possibly a separate later pass — it is not. Checking `docs/architecture/v2.md` §5, Days 12–14 explicitly bundles it in: *"`name_validator.dart` (length + profanity) **+name-rejected edge state (8.1)**"* sits in the same bullet as the onboarding build. It's the same controller, the same screen, the same PR. Deferring it would just mean flutter-developer builds `name_validator.dart`'s profanity path with no UI to show for a rejection — worse, not simpler. So: **8.1 is in scope, spec'd in §5.6 below, implemented as a state of the name-capture screen, not a separate route** (justified there).

**Explicitly out of scope for this document:** Home (6.1), Stats (6.3), streak-broken (6.2) — same architecture phase, different spec needed. Settings, notifications, ads, sound/haptics wiring — later phases per v2 §5, not touched here except to note where onboarding deliberately does *not* reach for them yet (§8).

---

## 1. The font problem, resolved

`screen-library-v3.html` loads Fredoka via a Google Fonts CDN `<link>` (`fonts.googleapis.com/css2?family=Fredoka...`). **Do not replicate this in the app.** A runtime CDN font fetch is a live network dependency, which violates the local-first architecture requirement (v2 §3.1/§3.5 — the game plays 100% offline by design). It would also mean the very first screen a player ever sees renders in a fallback system font (or blocks) if they're offline on first launch, on cellular, or the CDN hiccups — an unacceptable risk for a first impression.

**Decision: bundle Fredoka as local font assets.** Fredoka is SIL Open Font License (OFL 1.1), free to redistribute in-app with no attribution requirement (though bundling the `OFL.txt` alongside is good practice and takes one line — do it).

The mockup's CDN request is `family=Fredoka:wght@400;500;600;700` — exactly four weights, and cross-checking against the CSS, all four are actually used (400 inherited/base, 500 on subtitles, 600 on body copy, 700 on headings/buttons/badges). Bundle exactly these four:

```
assets/fonts/Fredoka-Regular.ttf     (weight 400)
assets/fonts/Fredoka-Medium.ttf      (weight 500)
assets/fonts/Fredoka-SemiBold.ttf    (weight 600)
assets/fonts/Fredoka-Bold.ttf        (weight 700)
assets/fonts/OFL.txt                 (license, bundle it, don't ship without it)
```

`pubspec.yaml` — add under the existing `flutter:` key (this repo's `pubspec.yaml` currently has no `fonts:` section, only the `assets:` list for `hit.mp3`/`miss.mp3`; add both):

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/sfx/hit.mp3
    - assets/sfx/miss.mp3
    - assets/fonts/OFL.txt
  fonts:
    - family: Fredoka
      fonts:
        - asset: assets/fonts/Fredoka-Regular.ttf
          weight: 400
        - asset: assets/fonts/Fredoka-Medium.ttf
          weight: 500
        - asset: assets/fonts/Fredoka-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Fredoka-Bold.ttf
          weight: 700
```

Then set it once, globally, in `core/theme.dart` (already exists per v2 §4 module layout): `ThemeData(fontFamily: 'Fredoka', ...)`. Individual `TextStyle`s then only need `fontWeight: FontWeight.w400/500/600/700` — Flutter resolves the matching bundled file automatically because the weights are registered under one family. No per-widget `fontFamily:` overrides needed anywhere in onboarding.

**Explicitly do not use the `google_fonts` pub package.** It's tempting because it's the "normal" way Flutter developers reach for Google Fonts, but its default behavior is to fetch the font from the network at first use and cache it — even its asset-bundling opt-in mode adds indirection this project doesn't need. Plain local `fonts:` declaration in `pubspec.yaml` is simpler, has zero ambiguity about when/whether a network call happens (never), and is the standard mechanism for any bundled font regardless of where it originated. Source the four `.ttf` files once, at build/asset-prep time (not runtime), from Fredoka's official OFL distribution and drop them in `assets/fonts/` — that one-time acquisition is not a runtime dependency and does not touch the local-first rule.

---

## 2. Visual token reference (distilled from the mockup's `:root` CSS)

Flutter-developer should not need to open the HTML file. Everything below is a direct translation.

### 2.1 Color tokens

| Token | Hex | Used for in onboarding |
|---|---|---|
| `bg` (mint) | `#C8ECD9` | Screen background, all 5 screens |
| `ink` | `#1F2A2E` | All borders, all flat drop-shadows, primary text, dot outlines |
| `paper` | `#FFFDF7` | Card/button fills where "cream," name input background |
| `paper2` | `#F2EFE6` | Unfilled dot fill, secondary surfaces (not heavily used in onboarding) |
| `coral` | `#FF7A59` | "Alive!" splash accent, primary CTA fill (Start playing), current-step dot fill |
| `coralDark` | `#E5613F` | Text-shadow under coral fills (see §2.3) |
| `green` | `#2FBF71` | Splash preload bar fill, Next/Got it CTA fill |
| `greenDark` | `#1F9C58` | Text-shadow under green fills |
| `red` | `#F0483E` | 8.1 rejected-state border/text/note background accent |
| `mute` | `#7B8A86` | Secondary/caption text, "Skip" links, counter label text |

Reference implementation: a small `const` class or `ThemeExtension` in `core/theme.dart`, e.g. `class AppColors { static const bg = Color(0xFFC8ECD9); ... }` — flat constants, not a design-tokens package. This repo's flat-module discipline (v2 §2/§4) doesn't need more than that.

### 2.2 Shape tokens

| Element | Border width | Corner radius | Shadow (flat offset, see §2.3) |
|---|---|---|---|
| Primary CTA button (`.cta` — Next / Got it / Start playing) | 2.5px ink | 14 | `Offset(0, 5)`, ink, zero blur |
| Ghost/secondary button (not used standalone in onboarding, but same family as 8.1's "Try again" if styled ghost) | 2.5px ink | 14 | `Offset(0, 4)`, ink, zero blur |
| Name input field | 2.5px ink (red in 8.1 state) | 14 | none — inputs don't get the drop-shadow treatment in the mockup |
| Progress dot | 1.5px ink | fully round (999) | none |
| Splash preload bar track | 2px ink | fully round (999) | none |

### 2.3 The flat drop-shadow, in Flutter terms

The mockup's `box-shadow: 0 Npx 0 var(--ink)` is a **hard, zero-blur, offset-only shadow** — not a blurred Material elevation. The good news: this maps almost exactly onto Flutter's own `BoxShadow` primitive, no custom `CustomPainter` or manual double-`Container`/`Stack` trick required.

```dart
Container(
  decoration: BoxDecoration(
    color: fillColor,                                   // e.g. AppColors.coral
    border: Border.all(color: AppColors.ink, width: 2.5),
    borderRadius: BorderRadius.circular(14),
    boxShadow: [
      BoxShadow(
        color: AppColors.ink,
        offset: const Offset(0, 5),   // "5" = the CSS shadow depth in px
        blurRadius: 0,                // zero blur = hard edge, matches CSS exactly
        spreadRadius: 0,
      ),
    ],
  ),
  child: ...,
)
```

`BoxShadow` with `blurRadius: 0` renders a perfectly crisp rectangle (or rounded-rect, following the same `borderRadius`) offset by `offset` — this **is** the same rendering primitive as the CSS flat shadow, not an approximation. This is explicitly **not** the same thing as Material's `elevation`/`PhysicalModel` shadow system (which always blurs and simulates ambient+direct light) — do not use `Material(elevation: ...)` anywhere in onboarding; author the shadow directly on the `BoxDecoration` as above.

Wrap this in one reusable widget — `StickerButton` — living in `core/widgets/sticker_button.dart` (new folder; `core/` already exists per v2 §4). It's genuinely shared, not premature abstraction: the same chrome (border + flat shadow + rounded fill) reappears on outcome cards (§3), settings rows (§7), and the pause modal (§2.6) per the mockup's `.cta`/`.ghostbtn`/`.row` classes — building it once in `core/` now saves re-deriving it three more times later.

**Hit target includes the shadow strip.** Don't split the tappable area from the visual footprint — wrap the *entire* `Container` (fill rect + its shadow strip beneath it) in the tap handler, so the effective tap target is the full visual footprint of the button, not just the top fill rectangle. This is a deliberate divergence from literal CSS behavior (browsers don't hit-test `box-shadow` pixels) in favor of a bigger, more forgiving thumb target — consistent with the reachability principle already established in `play-screen-skeleton-v1.md` §4.

### 2.4 Type scale

The mockup's phone mockup is rendered at 224 CSS px wide for a multi-screen gallery page — it is **not** 1:1 with a real device's logical pixels (a typical phone is 375–430dp wide, roughly 1.7–1.9× wider). So: corner radii, border widths, and shadow offsets above are literal tokens (a border is a border regardless of overall scale — keep those numbers as-is). Font sizes below are **translated, not mechanically multiplied** — recommended concrete values that preserve the mockup's hierarchy (small tagline vs. big heading vs. button label) at real-device reading distance.

| Role | Weight | Size (recommended) | Color | Used on |
|---|---|---|---|---|
| Splash wordmark ("Stay") | 700 | 34sp | ink | 1.1 |
| Splash wordmark accent ("Alive!") | 700 | 34sp | coral, text-shadow `Offset(0,2)` coralDark, blur 0 | 1.1 |
| Splash tagline | 600 | 14sp | `#3F5651` (a slightly darker mute, matches `.d` context on mint bg) | 1.1 |
| Teaching card heading (`h3.t`) | 700 | 22sp | ink | 1.2–1.4 |
| Teaching card body (`p.d`) | 600 | 15sp | `#4A5F5A`, max-width ~230dp, line-height 1.45 | 1.2–1.4 |
| CTA button label | 700 | 16sp | white (on coral/green fill) with a 1.5px flat text-shadow in the fill's `-Dark` variant (`Offset(0,1.5)`, zero blur) | 1.2–1.5 |
| Name-capture heading | 700 | 20sp | ink | 1.5 |
| Name input text | 700 | 18sp | ink (red in 8.1) | 1.5, 8.1 |
| Counter / helper text | 600 | 11sp | mute | 1.5 |
| "Skip" links | 600, underline | 12sp | mute | 1.2–1.5 |

The button label's text-shadow is the same flat-offset idea as §2.3 but applied to `Text` — implement via `Text` with a `Shadow` in its `TextStyle.shadows` list (`Shadow(color: coralDark, offset: Offset(0, 1.5), blurRadius: 0)`), not a second stacked `Text` widget.

---

## 3. Flow & navigation

### 3.1 State diagram

```
App cold start
     │
     ▼
┌───────────┐   onboardingComplete == true   ┌──────┐
│  Splash   │ ─────────────────────────────► │ Home │   (every launch after the first)
│  (1.1)    │                                 └──────┘
└───────────┘
     │  onboardingComplete == false (first launch only)
     ▼
┌────────────┐  Next   ┌────────────┐  Next   ┌────────────┐  Got it   ┌──────────────┐
│  Teach 1   │ ──────► │  Teach 2   │ ──────► │  Teach 3   │ ────────► │ Name capture │
│  (1.2)     │         │  (1.3)     │         │  (1.4)     │           │    (1.5)     │
└────────────┘         └────────────┘         └────────────┘           └──────────────┘
     │ Skip                 │ Skip                 │ Skip                   │  ▲
     └──────────────────────┴──────────────────────►│ (any teach card's Skip │  │ invalid name
                                                       jumps straight here)   │  │ (profanity)
                                                                              ▼  │
                                                              ┌───────────────────────┐
                                                              │ 8.1 Name rejected      │
                                                              │ (same screen, error    │
                                                              │  state — see §5.6)     │
                                                              └───────────────────────┘
                                                                              │
                                                     Start playing (valid) ───┤
                                                     Skip for now ───────────┤
                                                                              ▼
                                                                        ┌──────────┐
                                                                        │   Play   │  (first run,
                                                                        └──────────┘   countdown 2.1
                                                                                        straight in)
```

### 3.2 Splash: auto-advance, not tap-to-continue — and it runs on every launch, not just the first

Two decisions bundled here, both worth stating explicitly since the task calls this out as the one to resolve:

**1. Auto-advance, no tap target.** Nothing in the mockup gives Splash a button, and the section's own subtitle — *"Everything skippable except the splash"* — is meaningful only if Splash isn't a decision point at all: there's no Skip button to omit and no tap gesture to wait for. Splash is not interactive. It advances on its own once initialization is ready (or a ceiling elapses).

**2. Splash itself is not first-launch-only; the teaching cards + name capture are.** This is a deliberate reading of the mockup rather than a literal one, and it's worth stating why: a brief branded loading beat on cold start (while `main.dart`'s `Hive.initFlutter()` / box open / `Firebase.initializeApp()` / `ProfileRepository.load()` run — all already planned per v2 §4's `main.dart` init sequence) is standard on **every** cold start of **every** app, onboarding or not — it isn't onboarding content, it's app-boot chrome that happens to carry the brand. Reading "shown once" as covering literally the splash pixel-for-pixel would mean returning players get dropped straight from a black system window into Home with zero branding beat, which is worse UX than the mockup intends. So: **Splash (1.1) renders on every cold start; only the chain into 1.2–1.5 is gated by the first-launch flag** (checked the instant Splash's init work completes — see §3.3).

**Timing, exact:**
- Minimum display duration: **900ms**, even if all init work finishes instantly — avoids a single-frame flash that would look like a glitch, not a beat.
- Preload bar (the mockup's static 70%-filled bar) is **not decorative-only**: drive its `widthFactor` with a `TweenAnimationBuilder<double>(duration: 900ms, tween: Tween(0,1))` from 0→1 over the minimum window. If real init (Hive/Firebase/profile load) finishes before 900ms, the bar still runs its full visual sweep — don't cut it short, that reads as broken, not as fast. If real init runs *longer* than 900ms (slow device/cold disk), hold the bar at ~90% (don't let it visually lie at 100% while still blocking) until init actually resolves, then snap to 100% for one frame before navigating.
- Ceiling: **3000ms**. If init hasn't resolved by then, proceed anyway (best-effort) rather than stranding the player on a splash screen indefinitely — matching the reassurance-first, never-strand-the-player posture the architecture already applies to ad-failed (§8.3) and offline (§8.2).
- No error state lives on Splash itself. If something in init fails, handle it via the existing offline/ad-failed screens later in the session, not here — Splash's only job is the brand beat + routing decision.

### 3.3 First-launch gating — `onboarding_controller.dart`'s contract

Per v2 §4, settings/name/flags all extend the existing `ProfileRepository`, no second store. Add one persisted field:

```dart
// ProfileRepository (extended, not a new repository)
bool get isOnboardingComplete;         // persisted, default false
Future<void> markOnboardingComplete({String? name});   // sets true, optionally writes name
```

`onboarding_controller.dart` owns only the *in-flow* state (which teach card is showing, the name-capture text + validation result) — not the persisted flag itself, which the router reads directly from `ProfileRepository` once, right after Splash's init resolves:

```dart
enum OnboardingStep { teach1, teach2, teach3, name }
// Splash is not a step here — it's routed by app.dart/router.dart directly,
// not by OnboardingController, since it runs regardless of onboarding status.
```

Controller surface:
- `next()` — advances `teach1→teach2→teach3`. Called from teach1/teach2's "Next" button.
- `finishTeaching()` — `teach3 → name`. Called from teach3's "Got it" button (deliberately a separate method name from `next()`, even though mechanically similar, because "Got it" is a distinct semantic action worth being able to log/test separately from "Next").
- `skipToName()` — jumps straight from **any** teach step to `name`. Called by the "Skip" link on 1.2/1.3/1.4 (see §3.4 for why Skip lands on name-capture, not straight into Play).
- `submitName(String raw)` — runs `name_validator.dart` against `raw`. Valid → `ProfileRepository.markOnboardingComplete(name: raw)`, navigate to Play. Invalid (profanity match; length is pre-blocked at the input, see §5.5) → sets a local `nameError` flag the name-capture screen reads to switch into the 8.1 state (§5.6); does **not** navigate.
- `skipNaming()` — `ProfileRepository.markOnboardingComplete(name: null)`, navigate to Play. No-name fallback phrasing on outcome cards is already the extended `CardTemplate`'s job per v2 §3.4 — onboarding just needs to persist "no name," not know anything about card copy.

**Restart behavior on interruption:** if the app is killed mid-teaching (say, between 1.2 and 1.3), `isOnboardingComplete` is still `false` — the *only* moment it flips to `true` is inside `markOnboardingComplete`, called exclusively from `submitName` (valid) or `skipNaming`. So next launch, onboarding **restarts from `teach1`**, not from wherever it was interrupted. This is a deliberate simplification, not an oversight: persisting a mid-flow resume position for a ~10–15 second flow is exactly the kind of speculative complexity the flat-module/no-speculative-abstraction rule (v2 §2/§4) would reject — the cost of occasionally re-showing three short cards to someone who force-quit mid-onboarding is near zero.

**This flow runs at most once, structurally, not just by convention:** the router checks `isOnboardingComplete` a single time per app session, immediately after Splash. There is no menu path, deep link, or settings toggle that re-enters `OnboardingStep.teach1` et al. in this pass (re-running onboarding on demand, e.g. from Settings, is a plausible nice-to-have but is explicitly not built here — see §8).

### 3.4 Why "Skip" lands on Name capture, not straight into Play

The mockup's screenshots for 1.2–1.4 show only `Next`/`Got it` + dots — no visible Skip element — yet the section subtitle explicitly promises *"Everything skippable except the splash."* Resolving that gap is a real design decision, made here: **add a small "Skip" text link, top-right of each teaching card**, styled identically to 1.5's existing bare-text "Skip for now" (`background: none`, no border, `mute` color, underlined, 12sp/600) so it doesn't compete visually with the primary `Next`/`Got it` button or introduce a second button-chrome style.

Tapping Skip on **any** of 1.2/1.3/1.4 calls `skipToName()` — it jumps past the remaining teaching cards, but **stops at Name capture, not straight through to Play.** Reasoning: the teaching content (how to tap, the life bar, the endings) is disposable — a player who already gets the loop shouldn't be forced to sit through it. The player's *name* is not disposable in the same way — it's a genuinely valuable, low-cost 5-second ask that pays off every single outcome card for the rest of the session (v2 §3.4's whole reason `name_validator.dart` exists). Skipping *teaching* and skipping *naming* are separable decisions, and the mockup itself treats them as separable — 1.5 has its own, independent "Skip for now" link. So: one Skip semantic for teaching-content (→ name capture), one separate Skip semantic for naming (→ Play). Nothing here forces a player through two skips against their will — a player who wants past everything taps Skip once (lands on name capture) then Skip for now once more (lands in Play) — two taps total, not buried.

### 3.5 Card-to-card transition

Implement the 3 teaching cards as a `PageView` (`PageController`) with the dot row (§5.4) synced to `PageController.page`. `Next`/`Got it` call `pageController.animateToPage(n, duration: 250ms, curve: Curves.easeOut)` — Flutter's built-in default-ish transition, not a custom-tuned `AnimationController`, consistent with the Gate 1 doc's "don't reach for curve-tuning time" discipline. Swiping between cards works "for free" with `PageView` and is harmless to allow (backward swipe especially) — but `Next`/`Got it`/`Skip` remain the primary, always-visible path; nothing requires the player to discover swipe. The `PageView` contains **only** the 3 teach cards — Splash and Name-capture are separate routes/widgets outside it, so a stray swipe can never carry a player past "Got it" into name capture or back out into Splash.

---

## 4. Reusable widgets to build once (in `core/widgets/`)

New folder, three small files — justified because all three widgets are reused well beyond onboarding (outcome cards, settings rows, pause modal all share this chrome per the mockup's CSS classes):

| Widget | File | Backs |
|---|---|---|
| `StickerButton` | `core/widgets/sticker_button.dart` | `.cta`/`.ghostbtn` — border + flat shadow + fill, per §2.3. Params: `label`, `fillColor`, `onPressed`, `shadowDepth` (default 5, pass 4 for ghost-style), `borderColor` (default ink, red for 8.1's variant if reused there instead of a fresh style). |
| `DotProgress` | `core/widgets/dot_progress.dart` | `.dots`/`.dots i.on` — see §5.4. |
| `TeachCard` | `features/onboarding/widgets/teach_card_layout.dart` (onboarding-specific, not shared) | The icon/heading/body/dots/button column shared by 1.2–1.4. Lives inside `onboarding/` since nothing outside onboarding reuses this exact composition — correctly scoped local, unlike the two above. |

---

## 5. Screen-by-screen spec

### 5.1 Component hierarchy — shared shell

All 5 screens share one shell:

```
Scaffold(backgroundColor: AppColors.bg)
 └── SafeArea
      └── Center / Column   (per-screen body below)
```

No `AppBar` on any of the 5 screens — matches the mockup (no top chrome on any of 1.1–1.5) and matches the existing precedent in `play-screen-skeleton-v1.md` of reclaiming vertical space when there's no navigation need.

### 5.2 1.1 Splash

```
┌───────────────────────────┐
│                           │
│                           │
│           💓              │  ← heartbeat mark (static icon, see §8 — no pulse animation this pass)
│                           │
│     Stay                  │
│     Alive!  (coral)       │
│                           │
│  One tap. A thousand      │
│  ways to go.              │
│                           │
│   [████████░░] 70→100%    │  ← preload bar, animates per §3.2
│                           │
└───────────────────────────┘
```
- Column, `MainAxisAlignment.center`, `mainAxisSize.min`, centered horizontally.
- Icon → wordmark (8dp gap) → tagline (10dp gap) → preload bar (14dp gap above it, matching the mockup's `margin-top:14px`).
- Preload bar: `Container` track (paper fill, 2px ink border, radius 999, height ~10dp) with an inner `Padding(1.5dp)` wrapping a `FractionallySizedBox` fill (green, radius 999) — same shape recipe as the play screen's life bar (`play-screen-gate1-v1.md` §2), reused here for visual consistency between the two green bars a player will see close together in time.
- No button, no Skip, no back gesture (disable system back on this route if trivial to do; not worth extra plumbing if not).

### 5.3 1.2 / 1.3 / 1.4 Teaching cards — shared layout, per-card content

```
┌───────────────────────────┐
│                    Skip   │  ← top-right text link, all 3 cards
│                           │
│           👆              │  ← per-card icon
│                           │
│   Tap on the number       │  ← heading, 22sp/700
│                           │
│  A target time appears.   │  ← body, 15sp/600, centered,
│  Tap the instant it hits. │     max-width ~230dp
│                           │
│        ● ○ ○              │  ← dot row, current card filled
│                           │
│  ┌─────────────────────┐  │
│  │        Next          │  │  ← StickerButton, green fill
│  └─────────────────────┘  │
└───────────────────────────┘
```

| Card | Icon | Heading | Body | Button label | Dot position |
|---|---|---|---|---|---|
| 1.2 Teach-the-tap | 👆 | "Tap on the number" | "A target time appears. Tap the instant it hits." | Next (green) | 1 of 3 |
| 1.3 Teach-the-life-bar | ❤️ | "Mind your life" | "Nail it, gain life. Miss, lose it. Hit 0% and you're gone." | Next (green) | 2 of 3 |
| 1.4 Teach-the-endings | see note below | "Three ways it ends" | "Die, survive a last save, or go Eternal. All shareable." | Got it (green) | 3 of 3 |

**Note on 1.4's icon:** the mockup's HTML source has an empty icon glyph for every "big" icon slot in this section (an encoding/extraction artifact, not an intentional blank) — so exact icon choices for 1.2/1.3/1.5 above are a reasonable reconstruction, not literal extraction, and flutter-developer should treat them as a starting recommendation rather than a locked spec. Flutter renders emoji via the OS's system font automatically (no bundling, no network — this doesn't reopen the font-CDN problem in §1). For 1.4 specifically, consider swapping the single emoji for **three small mini-badges** — reusing the exact `.badge` death/eternal/survive pill styling from the outcome-card screens (screen-library §3.1–3.3: red "You died," gold "Eternal Human," green "Survived") laid out in a small row instead of one big emoji. This is a nice-to-have upgrade, not required: it costs one more small widget but concretely foreshadows the exact colors/labels the player will see on their first real outcome card a few minutes later, which is a stronger "teach" than a generic emoji. Flutter-developer's call which to ship first; the three-badge version is the better version if there's time.

Card body copy, icon, and button label are the **only** things that vary between 1.2/1.3/1.4 — everything else (heading position, dot row, button width/style, Skip link) is identical across all three, which is exactly why `TeachCard` (§4) should be one parameterized widget, not three near-duplicate screens.

### 5.4 Dot progress indicator (`.dots` / `.dots i.on`)

- 3 dots, fixed count (matches the fixed 3-card teaching sequence — no dynamic count needed).
- Each dot: `Container`, 8dp diameter, `BorderRadius.circular(999)`, `1.5px` ink border.
- Unfilled dot fill: `paper2` (`#F2EFE6`). Filled/current dot fill: `coral`.
- Row, 6dp gaps between dots, centered horizontally, positioned above the CTA button with the same vertical rhythm as the mockup (dots sit between body copy and button, not beside the button).
- Drive from the `PageView`'s current page index directly (`DotProgress(activeIndex: pageController.page?.round() ?? 0, count: 3)`) — no separate state needed, this is a pure function of the controller's `next()`/`skipToName()` calls having already fired.

### 5.5 1.5 Name capture

```
┌───────────────────────────┐
│                           │
│                           │
│  What should we call you? │  ← heading, 20sp/700
│                           │
│  Goes on your cards.       │  ← subtext, matches p.d style
│                           │
│  ┌─────────────────────┐  │
│  │        Aman           │  │  ← TextField, centered text, 18sp/700
│  └─────────────────────┘  │
│  On your cards      4/12  │  ← helper row: left = static hint,
│                           │     right = live counter
│  ┌─────────────────────┐  │
│  │    Start playing      │  │  ← StickerButton, coral fill
│  └─────────────────────┘  │
│      Skip for now          │  ← bare text link, mute, underlined
└───────────────────────────┘
```

- `TextField` (not `TextFormField` — no form-wide validation needed, this is one field): centered text, `maxLength: 12` set directly on the field (Flutter enforces this at the input level — the 13th keystroke simply never lands, matching v2 §3.4's "length cap"). Hide the default Flutter maxLength counter widget (`counterText: ''`) and render the custom `"4/12"` counter in the helper row instead, matching the mockup's placement (left = static "On your cards" hint, right = live count) rather than Flutter's default centered-below-field counter.
- Counter text stays `mute`-colored at all times in this pass — no red/warning color change as the count approaches 12, since the hard `maxLength` already makes overflow physically impossible; a color warning would be signaling a problem that structurally can't occur. (If a future pass wants a "getting close" nudge at 10–11/12 purely for polish, that's a cheap addition later, not needed now.)
- Autofocus: yes — the player's very next action after landing here should be typing, no extra tap needed to focus the field.
- Keyboard: default text keyboard, `textCapitalization: TextCapitalization.words` (names), `textInputAction: TextInputAction.done` (submitting via keyboard "done" should behave the same as tapping "Start playing").
- **Submit path:** tapping "Start playing" (or keyboard done) calls `onboardingController.submitName(text)`. Empty input is valid (treated the same as "Skip for now" — an empty name submitted via the primary button still means "no name," don't force the player to find the separate Skip link just because they left it blank and hit the big button instead).
- **Skip for now:** bare-text link (see §2.4 styling), calls `onboardingController.skipNaming()` directly — bypasses validation entirely (an intentionally-skipped name can't be "invalid").

### 5.6 8.1 Name rejected — implemented as a state of 1.5, not a separate route

**Decision, stated explicitly:** the mockup renders 8.1 as its own full phone screenshot with a different heading ("Pick another name" vs. "What should we call you?"), but building it as a full route/navigation push for what is fundamentally one field's inline validation error would be both worse UX (a jarring full-screen transition for a typo-adjacent mistake) and more code than needed (a second route + back-navigation handling for one error state). **Implement 8.1 as an `error` boolean/state on the same 1.5 widget**, toggled by `submitName`'s validation result:

```
┌───────────────────────────┐
│                           │
│                           │
│   Pick another name        │  ← heading swaps text (from "What should
│                           │     we call you?"), stays 20sp/700
│  ┌─────────────────────┐  │
│  │      (their text)     │  │  ← same TextField, border/text turn red,
│  └─────────────────────┘  │     text is NOT cleared or masked —
│                           │     mockup's "****" is a documentation
│  ⚠ That word isn't        │     mask for this doc's own screenshot,
│    allowed - it shows      │     not real product behavior; showing
│    on shared cards          │     the player's actual (rejected) text
│                           │     is correct so they can see what to edit
│  ┌─────────────────────┐  │
│  │      Try again         │  │  ← same StickerButton slot, label swaps
│  └─────────────────────┘  │     from "Start playing" → "Try again"
│      Skip for now          │  ← unchanged, still available — a
│                           │     rejected name should never trap
│                           │     someone who'd rather just skip
└───────────────────────────┘
```
- Trigger: only the **profanity-list** path (v2 §3.4's bundled `profanity.txt` check inside `name_validator.dart`) reaches this state. The length cap never does, because it's physically prevented at the `TextField` level (§5.5) — there is no "too long" submission to reject.
- Field state on error: border color → `red`, input text color → `red`, `note`-style banner appears below the field (`#FDE3E3` background, red text, per the mockup's `.note` treatment) with copy matching the mockup exactly: *"That word isn't allowed — it shows on shared cards."*
- **Text is retained, not cleared**, and the field keeps focus with the existing text selected (select-all) so the very next keystroke replaces it — a player rejected for one word shouldn't have to retype an entire name from scratch, and select-all makes "replace the bad part" the path of least resistance without forcing them to manually delete first.
- Re-typing anything (any `onChanged` fire) immediately clears the error state back to the normal 1.5 appearance — don't require another explicit dismiss/retry tap just to stop showing a stale error while they're already fixing it. "Try again" is for re-submitting once they believe it's fixed, not for dismissing the message.
- "Skip for now" remains visible and functional in this state — a rejected name must never be a dead end; the player can always bail to no-name instead of being forced to find an acceptable string.

---

## 6. Key states summary (for tester)

| Screen | Loading | Empty | Error | Success |
|---|---|---|---|---|
| 1.1 Splash | Bar sweeping 0→90%+ while init runs (§3.2) | n/a | n/a (no error surface here, see §3.2) | Bar hits 100%, routes to teach1 (first launch) or Home (return visit) |
| 1.2–1.4 Teach cards | n/a (static content, no async) | n/a | n/a | Next/Got it/Skip all advance the `PageView`/controller state |
| 1.5 Name capture | n/a | Empty field is a valid, submittable state (§5.5) | 8.1 state (§5.6), profanity match only | Valid submit or Skip → `markOnboardingComplete`, route to Play |

---

## 7. Responsive behavior

Same discipline as `play-screen-skeleton-v1.md` §5: proportional sizing (`Expanded`/`MediaQuery`-relative), not fixed pixel heights, across all 5 screens — five short screens with generous whitespace are exactly the layout most likely to look fine on a small phone and break (overflow, or absurd empty space) on a large one if built with fixed heights. Concretely:
- Teaching-card body text `max-width` (~230dp) should be expressed as a fraction of screen width with a cap, not a hardcoded dp value, so it doesn't clip on the smallest supported phone width.
- The name-capture screen's helper row (`On your cards` / `4/12`) must not wrap awkwardly at narrow widths — test at the smallest target width in the device matrix.
- Portrait-only, matching the existing precedent (no landscape handling required, no tablet-specific layout — same reasoning as prior specs: out of scope until much later, if ever).
- Text scale: at minimum, verify none of the 5 screens clip or overlap at `textScaleFactor` 1.3 (Android's larger accessibility text size step) — cheap to check now, expensive to retrofit later. A full accessibility audit is a QA-phase (Days 24–27) concern, not this one, but this one check is free.

---

## 8. Explicitly NOT in this pass — and why

| Left out | Why |
|---|---|
| Heartbeat mark **pulsing/animating** | The name "heartbeat mark" strongly implies a subtle pulse, but the mockup is a static image and can't confirm intended motion. Ship a **static** icon this pass; a gentle pulse (`AnimationController` + scale tween) is exactly the kind of juice the Days 21–23 cross-feature polish pass (v2 §5) is for — don't build it early just because it's tempting on the one screen with a name suggestive of motion. |
| Sound cues on Next/Got it/Start playing taps | `sound_service.dart` already exists (from the Gate 1 doc) and reusing `hit.mp3` as a generic confirm click is cheap, but v2 §5 explicitly groups **all** audio/haptic wiring into the Days 21–23 polish pass ("the audio/haptic layer that settings toggles read"). Building it piecemeal now, ahead of the settings toggles that are supposed to gate it (Days 15–17), means either wiring sound with nothing to turn it off yet, or building it twice. Skip it here. |
| Haptic feedback on button press | Same reasoning as above — depends on the not-yet-built settings/haptics toggle. |
| Re-entering onboarding on demand (e.g., a "replay tutorial" row in Settings) | Plausible future nice-to-have; no such entry point is spec'd or built here. `OnboardingController`'s steps are only ever reached via the first-launch gate in this pass. |
| 6.4-style "gotta find them all" mechanics on the teaching content, per-card animated illustrations, richer per-card art | Not in the mockup for this section at all; templated icon + text only, matching v2 §6's "rich per-death animations… templated text + few static art variants" scope guard applied here by analogy. |
| Name-capture "getting close to the cap" counter color warning (10–11/12) | Structurally unnecessary since `maxLength` makes overflow impossible (§5.5) — a cheap future polish nudge, not a requirement. |
| Full accessibility audit (screen-reader label pass, RTL, high-contrast mode) | One cheap text-scale check is included now (§7); the full pass belongs to the Days 24–27 full-surface QA phase per v2 §5. |
| Home/Stats/streak-broken (6.1–6.3) | Same architecture days-range, deliberately a separate spec — see §0. |

---

## 9. Summary of files/changes (for flutter-developer)

| File | Purpose |
|---|---|
| `assets/fonts/Fredoka-{Regular,Medium,SemiBold,Bold}.ttf`, `assets/fonts/OFL.txt` | Bundled font, §1 |
| `pubspec.yaml` | `fonts:` section added, font assets + `OFL.txt` registered, §1 |
| `lib/core/theme.dart` | `ThemeData(fontFamily: 'Fredoka')`, `AppColors` constants (§2.1), extended (file already exists per v2 §4) |
| `lib/core/widgets/sticker_button.dart` | `StickerButton` — border + flat `BoxShadow` + fill, §2.3/§4 |
| `lib/core/widgets/dot_progress.dart` | `DotProgress` — 3-dot indicator, §5.4 |
| `lib/features/onboarding/onboarding_controller.dart` | `OnboardingStep` enum, `next()`/`finishTeaching()`/`skipToName()`/`submitName()`/`skipNaming()`, §3.3 |
| `lib/features/onboarding/onboarding_flow.dart` | Routes/hosts 1.2–1.5 (`PageView` for teach cards + name-capture widget), §3.5 |
| `lib/features/onboarding/widgets/teach_card_layout.dart` | Shared `TeachCard` widget parameterized per §5.3's table |
| `lib/features/onboarding/name_validator.dart` | Length cap (enforced via `TextField.maxLength`, not inside the validator) + profanity check against `assets/profanity.txt`; powers both 1.5's submit path and the 8.1 error state, §5.5/§5.6 |
| `lib/features/persistence/profile_repository.dart` | `+isOnboardingComplete`, `+markOnboardingComplete({name})`, §3.3 |
| Splash screen (new widget, hosted wherever `router.dart` puts the boot route) | §3.2 — runs every launch, routes to teach1 or Home based on the flag |

**"Done when" for this spec:** on a fresh install, first launch shows Splash (branded, bar sweeps, ~900ms–3000ms) then chains straight into Teach 1→2→3→Name capture with working Next/Got it/Skip at every step, lands in Play with a name (or no name) correctly persisted; a rejected profanity submission shows the 8.1 error state inline without navigating away and without losing the "Skip for now" escape hatch; force-quitting mid-onboarding and relaunching restarts cleanly from Teach 1; and a second, later launch skips straight from Splash to Home with no onboarding content shown again.
