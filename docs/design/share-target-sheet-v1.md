# Stay Alive — Share Target Sheet Visual & UX Spec v1

**Scope:** visual/UX spec for the new `ShareTargetSheet` widget — the custom
3-tile Instagram/WhatsApp/Facebook picker that replaces the generic OS share
sheet on the Outcome Card's Share button.
**Consumes:** `docs/architecture/v5.md` in full, especially §4 (flow), §4.1
("More…" fallback), §8 (fallback/dimmed behavior), §9 (Meta App ID phasing),
§11 (memory), §12 (flags). This doc does not re-litigate any of those
decisions — it fills in the visual/interaction gaps §12 explicitly leaves for
this stage.
**Extends:** `docs/design/outcome-story-cards-v1.md` (reuses its color/type
tokens directly — no new color tokens are introduced by this doc) and
`lib/core/widgets/sticker_button.dart`'s established shadow/border/press
vocabulary.
**Does not touch:** the Outcome Card itself, the Share/Again actions row
(R2.2/R2.3 in the outcome-story-cards doc), or the existing "✓ Shared" toast's
success path — all unchanged.

Design spec, not code — no Dart.

---

## 0. What this replaces (recap)

Today: Share → `CardRenderer.renderToFile` → `ShareService.shareFile`
(generic OS share sheet) → `_ShareToast` ("✓ Shared") on success.

New: Share → `renderToFile` → probe `installedTargets()` → **`ShareTargetSheet`**
(3 tiles: Instagram, WhatsApp, Facebook, fixed order, plus a "More…" fallback
link) → tap a tile fires that platform's native intent directly, or falls
through to the existing OS-sheet path via "More…". Web (`kIsWeb`) skips this
sheet entirely and goes straight to the existing `share_plus` path — nothing
in this doc applies to the web build.

---

## 1. Icon asset decision (task item 1)

**No new Unicode/emoji glyphs are even a candidate here** — unlike the
previously-banned 🛟 (a real emoji with a tofu-rendering risk, per the
outcome-story-cards doc §5/§0), there is no Instagram/WhatsApp/Facebook logo
emoji in Unicode at all. The real choice is between generic Material icons
and bundled official brand assets.

**Rejected: Material icon fallbacks** (`Icons.camera_alt` for Instagram,
`Icons.chat`/`Icons.message` for WhatsApp, `Icons.facebook` for Facebook).
Three problems, not one:
- Inconsistent stroke weight/style across three unrelated glyph sets sitting
  in a single row — reads as mismatched, not as one coherent picker.
- Wrong (or entirely absent) brand color for two of the three — a plain
  outline camera icon does not read as "Instagram" to anyone at a glance,
  which directly undermines the whole reason the two-line label exists (to
  set the Story/Status expectation).
- This is exactly the "cheap knockoff" outcome flagged in the brief — a
  generic-icon share picker looks unfinished/unofficial next to this app's
  otherwise deliberate, consistent visual language.

**Recommendation: bundle each platform's official brand glyph as a vector
asset** (`flutter_svg`/`vector_graphics`, not raster PNG) — sourced from each
platform's own brand resource center (Meta Brand Resource Center for
Instagram's gradient camera glyph and Facebook's blue "f"; WhatsApp's Brand
Center for its green speech-bubble/phone glyph), at each brand's specified
default multi-color treatment (not a monochrome/outline substitute). Vector
over raster because these render inside a fixed 40×40dp box regardless of
device density, and a vector avoids shipping multiple PNG densities or
blurring at high `devicePixelRatio`.

**Follow-up flag (per architecture §12, restated here for this doc's own
checklist):** play-store-specialist must separately confirm official colors,
adequate clear-space within the 72×72 tile (the ≈16dp margin computed in §4
below should be checked against each brand's own specific minimum, which
varies per brand), and no implied endorsement/partnership. This spec
recommends the *asset sourcing approach*; it does not itself certify brand
compliance.

---

## 2. Sheet chrome & dimensions (task item 2)

| param | value |
|---|---|
| Presentation | `showModalBottomSheet` |
| `isScrollControlled` | `true` (sizes to content, not the 50%-screen default) |
| `backgroundColor` | `Colors.transparent` (custom shape/border painted below, not Material's own fill) |
| `barrierColor` | `AppColors.ink.withValues(alpha: 0.55)` — reuses `ResetConfirmDialog`'s exact existing scrim value, not Material's default `black45` |
| `elevation` | `0` — suppress Material's blurred elevation shadow; replaced by the hard shadow below |
| `enableDrag` / `isDismissible` | both `true` (defaults) |
| Sheet fill | `AppColors.paper` |
| Corner radius | **20dp, top corners only** (`BorderRadius.vertical(top: Radius.circular(20))`) — bottom is flush against the screen/safe-area, no radius needed there |
| Border | **2.5px `AppColors.ink`**, all four sides (the bottom edge sits at the screen edge, so a full border there is harmless — it just traces a straight line at the safe-area boundary) |
| Content max width | **400dp, centered** — mirrors `ResetConfirmDialog`'s existing `maxWidth: 320` precedent, sized up slightly to comfortably hold 3×72dp tiles with spacing on tablet-width screens |

### Shadow — adapting the sticker vocabulary to a bottom-anchored panel

The architecture doc specifies reusing the "hard, zero-blur, offset shadow"
sticker language for the sheet, but every other user of that language
(`StickerButton`) is a small floating shape whose shadow peeks out
below-and-right. A full-bleed bottom sheet has no free edge there — its
bottom and sides sit flush against the screen. The only edge that can show a
peeking shadow is the **top**.

**Decision:** a solid **5dp ink-colored band**, zero blur, visible peeking
above the paper sheet's rounded top edge — the same "ink backing plate"
effect as `StickerButton`, rotated to the sheet's one free edge instead of
mirrored to match a button's down-right convention. Implement with the same
technique `_EntranceCard._shadowInset` already uses elsewhere in this
codebase to avoid clipping a shadow at a `RepaintBoundary`/route boundary:
reserve unclipped space above the sheet's own bounds, paint an ink rounded-rect
behind, and offset the paper rounded-rect 5dp above it. This is a judgment
call this doc is making explicitly (architecture didn't specify a direction)
— flag it for game-ux-designer sign-off (§12 checklist below): confirm the
band is visible, ink-colored, unblurred, and not accidentally clipped off by
the modal route's own bounds.

---

## 3. Content layout

```
┌──────────────────────────────────┐  ink shadow band (5dp), peeking above
│┌────────────────────────────────┐│  top corners r=20, border 2.5 ink,
││                                ││  fill = paper
││        Share your card          ││  20dp top padding, headline style,
││                                ││  centered
││        (20dp gap)               ││
││                                ││
││  [IG tile] [WA tile] [FB tile]  ││  Row, mainAxisAlignment.spaceEvenly,
││                                ││  20dp horizontal content padding
││        (14dp gap)               ││
││            More…                ││  ghostLink, centered, 4dp v-padding
││                                ││
│└────────────────────────────────┘│  bottom: safe-area inset + 12dp
└──────────────────────────────────┘
```

| gap | value | rationale |
|---|---|---|
| Sheet top padding → title | 20dp | structural gap, matches sheet's own generous top inset (no drag handle — see below) |
| Title → tile row | 20dp | same "structural separation" tier as the top padding — the title precedes the sheet's primary interactive content, not sub-text, so it gets the larger gap, not the 14dp "related content" tier used below |
| Tile row → "More…" | 14dp | **reuses the existing Home-link precedent verbatim** — the outcome screen already uses `SizedBox(height: 14)` above its own de-emphasized ghost link; same relationship (primary content → de-emphasized fallback link), same number |
| "More…" own padding | `vertical: 4` | reuses the Home link's own padding literally, same reason |
| Sheet content horizontal padding | 20dp each side | |
| Bottom safe-area | `MediaQuery.padding.bottom` + 12dp | keeps the last element clear of a gesture-nav home indicator |

**No drag handle bar.** Considered (a small centered ink-tinted pill above
the title, standard Material convention) and deliberately **not** speccing
it — `enableDrag: true` already provides the swipe-to-dismiss gesture without
a visual affordance, this sheet is short enough to read as obviously
graspable without one, and this app has no existing drag-handle precedent
anywhere to extend. Flag as a nice-to-have if a future pass wants it; not
required for v1.

---

## 4. Tile anatomy (task item 2, continued)

Fixed **native dp** values — like the Share/Again buttons (design v1
Revision 2 §R2.2), these tiles live outside any `k`-scaled `RepaintBoundary`
system, so nothing here scales with device width beyond ordinary responsive
layout (see §11).

Per tile, top to bottom, in one tappable column:

| element | value |
|---|---|
| Icon box size | **72×72dp** (per architecture §4) |
| Icon box fill | `AppColors.paper2` — a subtle, brand-neutral tint against the sheet's `paper` background (the two are close enough in value that the box reads as "recessed," not a jarring color block; no new token needed) |
| Icon box border | 2.5px `AppColors.ink` |
| Icon box radius | **14dp** — matches `StickerButton`'s own default radius, the tier this codebase already uses for tappable interactive chrome (distinct from the sheet/dialog's own 20/22dp "container" radius tier) |
| Icon box shadow | rest offset **5dp**, pressed offset **2dp**, zero blur — identical constants to `StickerButton`'s defaults |
| Press animation | identical timing to `StickerButton`: 90ms tap-down (`Curves.easeOut`) / 130ms release (`Curves.easeOutBack`), shadow-offset 5→2 with matching translate compensation |
| Icon glyph size | 40×40dp, centered in the box (≈16dp clear space each side — check against each brand's own minimum clear-space guideline per §1's follow-up flag) |
| Gap: icon box → label | 6dp |
| Label line 1 (brand name) | 11dp / w700 / `AppColors.ink`, centered — e.g. "Instagram" |
| Label line 2 (surface) | **reuses `AppTypography.helper` verbatim** (9dp/w600/`AppColors.mute`), centered — e.g. "Story" |
| Gap: line 1 → line 2 | 2dp |
| Per-tile column width | ≈80dp (72dp box + small slack; both label lines fit on one line each at these sizes — "Instagram"/"WhatsApp"/"Facebook" and "Story"/"Status" don't need to wrap) |

**Order, fixed regardless of install state:** Instagram, WhatsApp, Facebook
(architecture §4). Dimmed tiles do not reorder or hide — the row is always
3 tiles, full width, per architecture §8's own "keeps layout stable, keeps
all 3 brands visible" reasoning.

**Tap target:** the whole column (icon box + both label lines) is one
tappable region, not just the 72×72 box — a larger, more forgiving hit area
than the box alone, standard mobile-thumb-reachability practice.

**Implementation recommendation (non-binding):** rather than a one-off tile
widget duplicating `StickerButton`'s press/shadow chrome, consider extending
`StickerButton` with an opt-in `child:` slot, the same additive-slot pattern
already used for `showTrailingArrow` (outcome-story-cards-v1.md Revision 2
§R2.3) — keeps exactly one press-animation implementation in the codebase.
Flutter-developer's call; not a hard requirement of this spec.

---

## 5. Disabled/dimmed state (task item — architecture §8)

**Opacity 0.45**, applied to the entire tile (icon box + both label lines) —
identical value to `StickerButton`'s established convention
(`lib/core/widgets/sticker_button.dart:177`).

**Load-bearing divergence from `StickerButton`, flag clearly for
flutter-developer:** `StickerButton`'s `enabled: false` nulls out its own tap
handler (`_interactive` gates both the opacity *and* whether `onTap` fires) —
a dimmed `StickerButton` is genuinely inert. **A dimmed share tile must NOT
be inert.** Per architecture §8's feedback table, tapping a dimmed tile must
still fire — it shows the "isn't installed" toast. So: opacity 0.45 always
means the *visual* disabled state, but the `GestureDetector`/tap handler
stays live on every tile regardless of install/App-ID state; only the
branch of logic that runs on tap differs (fire the real intent vs. show a
toast). Don't copy `StickerButton`'s `enabled` semantics wholesale here.

Dimmed applies to: app-not-installed (any of the 3), or Instagram/Facebook
specifically when `FB_APP_ID` is empty at build time (architecture §9 — both
treated identically as "not installed" from a UI perspective).

---

## 6. "More…" link (task item — placement)

Below the tile row (§3's layout table). Exact same visual treatment as the
outcome screen's existing "Home" link: `AppTypography.ghostLink` (11dp/w600/
`AppColors.mute`/underlined), `Padding(vertical: 4)`, centered. Copy is
literally "More…" (U+2026 ellipsis — a single safe codepoint, not a
multi-glyph emoji, no tofu risk).

Tap → dismiss the sheet immediately, then fall through to the existing
`ShareService`/`share_plus` flow exactly as it works today — completely
unchanged, including its existing "✓ Shared" toast (§8 below).

---

## 7. Presentation mechanics (task item 3)

- **Appear:** default `showModalBottomSheet` slide-up-from-bottom transition
  — no custom entrance animation. This is a utility picker, not a
  celebratory moment; reusing the platform-conventional motion is the right
  call here, unlike the Outcome Card's own bespoke entrance beat.
- **Scrim:** yes — `AppColors.ink` at 55% opacity (§2), dims the outcome
  card underneath while the sheet is open.
- **Dismiss paths:**
  1. Tap outside / on the scrim — standard `isDismissible: true`.
  2. Drag the sheet down — standard `enableDrag: true`.
  3. Tap a tile whose intent **launches successfully** — dismiss immediately
     after the launch call returns, no toast (architecture §8: "Direct
     intent launched OK → dismiss sheet, no toast").
  4. Tap "More…" — dismiss immediately, then hand off to `ShareService`.
- **Deliberately does NOT dismiss on:**
  - Tapping a **dimmed** tile (not installed / no App ID) — shows the "isn't
    installed" toast and keeps the sheet open, so the player can immediately
    try one of the other two platforms without re-opening Share.
  - A tile tap that **throws `ActivityNotFoundException`** — same reasoning:
    keep the sheet open, show the "Couldn't open X" toast, let the player
    retry a different tile. (This means tile taps should attempt the launch
    *before* dismissing, not dismiss optimistically — flag for
    flutter-developer/code-reviewer, since it affects where the try/catch
    sits relative to `Navigator.pop`.)

---

## 8. Toast specs (task item 4)

### 8.1 Existing "✓ Shared" — unchanged

Only reachable via the "More…" path, on a real `ShareResultStatus.success`.
Exact existing widget, unchanged: dark `AppColors.ink` pill, `borderRadius`
12dp, padding `horizontal: 12, vertical: 9`, white 11dp/w600 Fredoka text
"✓ Shared", positioned on the **outcome screen** exactly as today
(`Positioned(left: 14, right: 14, bottom: 62)`), 2400ms auto-dismiss timer.
Nothing in this spec touches this path.

### 8.2 New error toasts — same visual treatment, two placement/copy deltas

**Decision: reuse the identical `_ShareToast` visual** (same container,
colors, padding, radius, font) rather than inventing a distinct
warning/error look. Reasoning:
- This app has exactly **one** toast treatment app-wide today. Introducing a
  second color language (e.g. an amber/red warning pill) for a single new,
  low-stakes case is exactly the kind of vocabulary growth this codebase's
  other docs repeatedly flag against.
- These are mild, expected, fully recoverable states — not a crash or a
  destructive action — a louder warning color would oversell the severity.
- Keeps implementation trivial: same widget, parameterized text, no new
  color tokens.

**Deltas from the success toast:**
1. **No leading "✓ "** — plain text only, since these aren't successes.
   (No replacement glyph either — don't invent a new leading icon for this;
   plain text reads correctly against the dark pill on its own.)
2. **Placement differs by case**, because §7 keeps the sheet open for both
   error paths:
   - **Both new error variants render inside the `ShareTargetSheet`'s own
     content** (e.g. `Positioned` near the bottom of the sheet, above the
     "More…" link), not on the outcome screen underneath — the sheet is
     still open and covering that screen when these fire, so reusing the
     outcome screen's own `Positioned` slot would be invisible (a modal
     route sits above it in the stack).
   - Same 2400ms auto-dismiss timer pattern as the existing toast.

**Copy, verbatim (belongs in `lib/core/copy/app_copy.dart` per architecture
§8):**

| case | copy |
|---|---|
| `ActivityNotFoundException` | "Couldn't open Instagram" / "Couldn't open WhatsApp" / "Couldn't open Facebook" |
| Pre-checked not installed (dimmed tap) | "Instagram isn't installed" / "WhatsApp isn't installed" / "Facebook isn't installed" |

---

## 9. Loading state (task item 5)

**None needed — and none should be built.** Per architecture §4 (steps 3–4)
and §12's code-reviewer flag 3, `installedTargets()` is awaited — behind a
`mounted` guard — **before** `showModalBottomSheet` is even invoked. The
sheet therefore only ever opens once every tile's enabled/dimmed state is
already known; there is no in-sheet async gap to cover with a spinner,
skeleton, or shimmer.

This also means no new loading affordance is needed on the Share button
itself during the probe: `renderToFile` already runs before the OS share
sheet opens today, with no loading indicator, and adding the
`installedTargets()` probe to that same pre-sheet gap doesn't change that —
it's the same "brief native work happens before something appears" shape
this app already ships without a spinner. Keep consistent with that
precedent rather than introducing one here.

---

## 10. Responsive behavior across phone sizes (task item 2, continued)

Tile row uses `Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly)` —
gaps between the 3 fixed 72dp tiles scale with available width, not a fixed
gap value:

| device width | content width (device − 40dp padding) | gap per slot (4 slots: before/between×2/after) |
|---|---|---|
| ~320dp (smallest realistic Android) | 280dp | (280 − 216) / 4 ≈ 16dp |
| ~360dp (common baseline) | 320dp | (320 − 216) / 4 ≈ 26dp |
| ≥440dp (capped at 400dp max content width, §2) | 360dp | (360 − 216) / 4 = 36dp |

No overlap risk at the small end, no excessive/awkward whitespace at the
large end (the 400dp content cap keeps that bounded). No other element in
this sheet needs responsive adjustment — title, "More…" link, and sheet
padding are all fixed dp regardless of device width.

---

## 11. Verification checklist — game-ux-designer sign-off (CLAUDE.md rule 6)

Per this repo's workflow, this checklist is for the eventual pass verifying
the *built* sheet against this spec, before the feature is considered done:

1. Sheet: 20dp top-only corner radius, 2.5px ink border all sides, `paper`
   fill, 400dp max content width centered.
2. Shadow: a solid, unblurred 5dp ink band visible peeking above the
   sheet's top edge, not clipped by the modal route's own bounds.
3. Scrim: ink at 55% opacity behind the sheet (matches `ResetConfirmDialog`'s
   value, not Material default).
4. Title "Share your card" — Fredoka, `AppTypography.headline` styling,
   centered, 20dp gaps above and below.
5. Tile row: exactly 3 tiles, 72×72dp icon boxes, 14dp radius, 2.5px ink
   border, rest/pressed shadow offsets 5/2, order Instagram → WhatsApp →
   Facebook, `spaceEvenly` gaps.
6. Icons: official bundled brand vector assets, correct official colors, no
   Material-icon fallback, no tofu/placeholder glyph — flag to
   play-store-specialist for brand-compliance sign-off separately.
7. Two-line labels present and correct per tile: "Instagram"/"Story",
   "WhatsApp"/"Status", "Facebook"/"Story" — line 1 11dp/w700/ink, line 2
   matches `AppTypography.helper` exactly.
8. Dimmed tiles: exactly 0.45 opacity, **still tappable** (not inert) —
   confirm a dimmed tap produces the correct "isn't installed" toast and
   does not silently no-op.
9. Toast placement: success ("✓ Shared") appears on the outcome screen after
   the sheet is gone (More… path only); both new error toasts appear inside
   the still-open sheet, not on the underlying screen.
10. Toast copy matches §8's table exactly, per platform, per case.
11. "More…" link: `ghostLink` styling, 14dp gap above (matches Home link's
    existing gap), tapping it dismisses the sheet and preserves the
    existing OS-share-sheet + "✓ Shared" behavior unchanged.
12. Web build (`kIsWeb`): confirm the 3-tile sheet is never shown at all —
    Share goes straight to the existing `share_plus` path.
13. Responsive check: no tile overlap on the smallest supported width, no
    excessive gap sprawl at the 400dp content cap.
14. Re-tapping multiple tiles from one open sheet (dimmed → dimmed → real
    tap) doesn't trigger a visible re-render/flash of the card underneath —
    confirms the single-render invariant (architecture §11/§12 flag 2) holds
    visually, not just at the code level.
