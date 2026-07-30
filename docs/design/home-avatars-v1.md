# Stay Alive — Home Tagline, Avatar System & Stat-Tile Rework Visual & UX Spec v1

**Scope:** three Home-screen changes signed off by product-architect: (1) shared tagline extraction, (2) new avatar system (Home card + `/avatar-picker` screen), (3) Home's 3-stat-tile row rework.
**Consumes:** the architect's decision doc (binding scope — see commit description; not re-litigated here except where flagged).
**Source mockup:** `timingtap_avatars_cartoon.html` (founder-attached, art direction only — not literal markup; treated as authoritative for spacing/proportions per the founder's note that its tokens already match this app's real `AppColors` 1:1).
**Extends:** `docs/design/remaining-screens-v1.md` §5 (Home & Progression) — this doc supersedes §5.1's stat-tile row and adds the avatar system as new Home content; everything else in §5 (streak card, week bar, Settings-gear icon, Play button, streak-advanced/broken states) is untouched and still current.
**Consumed by:** `flutter-developer` and a later `game-ux-designer` verification pass.

Design spec, not code — no Dart.

---

## 1. Tagline

Confirmed: **`kAppTagline = "One tap. From dust to forever."`** (30 chars). No visual change from either call site's existing slot — it drops into `home_screen.dart`'s existing `AppTypography.body` `Text` (replacing the literal `"One tap. A thousand ways to go."` string, `home_screen.dart:189`) and `splash_screen.dart`'s existing 320dp-clamped `ConstrainedBox` (`splash_screen.dart:130`) with **no layout change** — same style, same wrap/clamp behavior, both already sized generously for this string. `docs/design/remaining-screens-v1.md` §5.1's ASCII mock and `docs/design/onboarding-v1.md` §2.1/§2.5's quoted copy get their literal tagline strings updated to match in the same commit (both docs already point at `AppTypography.body`/wordmark styling that doesn't change). `docs/mockups/timingtap_screen_library_v3-4.html` is a frozen artifact — leave its baked-in old string alone, per architect.

Nothing else in this section needs spec — it's a pure string/constant change with a pre-verified layout fit.

---

## 2. Home layout — `HomeAvatarCard` + revised stat row

### 2.1 Where it sits

Replaces the current `const Spacer()` (`home_screen.dart` ~line 223, between the stat-tile Row and the Play button) with:

```dart
Expanded(child: Center(child: HomeAvatarCard(...)))
```

This is the same structural slot the Spacer occupied — a flexible middle region between the fixed-height dashboard header/streak-card/stat-row above and the fixed 50dp Play button below. **No fixed height anywhere in the card's own layout** — every internal dimension is proportional (sized off the card's own measured width via `LayoutBuilder`/`AspectRatio`, the same "compute once, scale everything" discipline as the outcome-story-card's `k` factor in `outcome-story-cards-v1.md` §2.2, just simpler here since there's no export/rasterization requirement). This is the load-bearing fix for the architect-flagged "short screens don't overflow" risk: on a short device the `Expanded` simply gives the card less vertical room and its `AspectRatio` box shrinks to fit, rather than the card asserting a fixed height that could overflow.

### 2.2 Card shape and sticker treatment — call: match `StatTile`, not `StickerButton`

**Decision: 2.5dp ink border / 4dp hard offset shadow / 14dp radius — identical to `StatTile`'s sticker treatment, not `StickerButton`'s heavier 5dp.** Reasoning: the avatar card is not a primary tappable *action* the way the Play button is (tapping it navigates to a picker, a secondary/discovery action, closer in weight to the stat tiles it sits directly above) — matching `StatTile`'s existing weight keeps the whole dashboard's "paper card" family visually consistent (streak card 5dp / stat tiles 4dp / avatar card 4dp), rather than introducing a fourth distinct shadow weight on a single screen that already juggles three. Fill: `AppColors.paper`.

```dart
Container(
  decoration: BoxDecoration(
    color: AppColors.paper,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppColors.ink, width: 2.5),
    boxShadow: [BoxShadow(color: AppColors.ink, offset: Offset(0, 4), blurRadius: 0)],
  ),
)
```

### 2.3 Card dimensions

- Card box: `AspectRatio(aspectRatio: 0.82)` (matching the mockup's avatar-card ratio, §5 below reuses the same ratio for picker tiles — one shared constant, don't diverge), width-constrained by a `ConstrainedBox(maxWidth: 168)` inside the `Center` so the card doesn't stretch edge-to-edge on wide phones/tablets (consistent with this app's existing "cap width on wide viewports" convention from onboarding §6). On a typical ~360dp phone this yields roughly a 150–168dp-wide, ~185–205dp-tall card — comfortably inside the `Expanded` slot's typical available height on all but the shortest supported devices; where it doesn't fit, `AspectRatio` simply shrinks under the `Expanded`'s actual constraint (no overflow possible by construction).
- Internal padding: 12dp all sides (matches `_StreakCard`'s 12dp).
- Figure size within the card: the `AvatarFigure` painter fills the remaining space below the microlabel, sized via `Expanded` + `FittedBox(fit: BoxFit.contain)` inside the card's `Column` — never a fixed px figure size, so it scales with the card's own responsive box.

### 2.4 Card internal layout

```
┌──────────────────────┐   card: paper, 2.5dp ink border,
│  BEST LIFE            │   14dp radius, 4dp shadow, 12dp pad
│                       │
│      (figure,          │   AvatarFigure, FittedBox-contained,
│       fills remaining   │   fillPercent = snap.bestLifePercent
│       space)            │   (or 100/green + "READY" zero-state)
│                       │
└──────────────────────┘
```

`Column`, `crossAxisAlignment: CrossAxisAlignment.start` for the microlabel (left-aligned, matching `_StreakCard`'s "DAILY STREAK" left alignment), then `Expanded(child: FittedBox(child: AvatarFigure(...)))` for the figure, centered horizontally within the card.

Whole card is tappable (`GestureDetector`, `HitTestBehavior.opaque`, plain platform tap feedback — same "navigational, not primary action" precedent as `StatTile`, not sticker-button press-juice) → pushes `/avatar-picker`.

### 2.5 Microlabel typography

Exactly `_StreakCard`'s "DAILY STREAK" caption style, reused verbatim (not a new style):

```dart
TextStyle(
  fontFamily: 'Fredoka',
  fontSize: 9,
  fontWeight: FontWeight.w700,
  color: AppColors.mute,
  letterSpacing: 0.04 * 9,
)
```

Text: **"BEST LIFE"** (normal state) or **"READY"** (zero-state, `bestLifePercent == 0` on fresh install — see §3.4 for the fill-color pairing). Both render in the same style/position; only the string and the figure's fill state change.

### 2.6 "Pick your look" hint (avatar_id == -1, never picked)

- Placement: a small pill directly **above** the card, inside the same `Center`/`Expanded` region — `Column` of `[hint pill, SizedBox(height: 6), card]` so the hint reads as "belongs to" the card below it, not as an independent dashboard element.
- Treatment: coral **chip** (not bare text) — reuses `NoteChip`'s shape/padding convention but with coral colors instead of the existing positive/error variants: bg `AppColors.coral` at reduced opacity is inconsistent with `NoteChip`'s existing solid-bg pattern, so instead use a **third `NoteChip` variant**: bg `AppColors.paper`, border 1.5dp `AppColors.coral`, text `AppColors.coral`, same 10dp radius/8×10 padding shape as the other two variants but bordered rather than solid-filled (since it sits on the same `bg` background as the card, a solid-coral-bg chip here would compete too hard with the coral used elsewhere as an *action* color — a bordered treatment reads as "hint," not "button"). Text: 10dp/600 (matching `NoteChip`'s existing type scale).
- Copy: **"👆 Pick your look"**.
- Disappears permanently once `avatar_id != -1` (i.e., after the first commit from the picker) — no re-show logic, no dismiss button needed since selecting *is* the dismissal.

### 2.7 Revised 3-stat-tile Row

New values per architect: Tile 1 = `snap.totalSurvives` / "Survived" / `AppColors.greenDark`; Tile 2 unchanged ("Eternal" / `goldDark`); Tile 3 = `snap.totalDeaths` / "Deaths" / **`AppColors.redDark`** (see §3.5 for the red-vs-redDark call, applied consistently here).

**Row spacing: no change needed.** The old "Best\nlife" label was two lines at 9dp/1.2 line-height ≈ 21.6dp tall; the new "Survived"/"Eternal"/"Deaths" labels are all single-line ≈ 10.8dp tall. `StatTile`'s `Column` is `mainAxisSize: MainAxisSize.min` with a fixed 2dp gap between value and label (not space-distributed), so the tile's total height simply shrinks by one label-line's worth (~10.8dp) uniformly — it doesn't unbalance the Row internally since all three tiles already share the same `MainAxisSize.min` sizing and change by the same amount. The **net effect is Home's overall content column gets ~10.8dp shorter**, which only *helps* the short-screen risk flagged for the avatar card's `Expanded` slot in §2.1 (more slack, not less). No new `SizedBox`/padding needed in the Row itself — the existing `8dp` gap between tiles stays as-is.

---

## 3. Avatar figure anatomy (`AvatarFigure` CustomPainter)

### 3.1 Canonical unit and proportions

Canonical reference box: **84 × 104** (the mockup's own SVG `viewBox`, reused directly as the painter's logical coordinate space — `Canvas.scale` to the actual paint `Size` before drawing, the same "design at a reference size, scale once" discipline as the outcome card's `k` factor). All measurements below are in this 84×104 unit space.

| element | spec |
|---|---|
| Body vessel | Rounded-bottom container path: bottom corners at `(22, 100)` / `(62, 100)`, rounded up to a flatter rounded-top around `y=60`, `x` spanning roughly `22`→`62` at the shoulders narrowing slightly toward `y=100`'s wider base — i.e. a gently tapered "vessel" silhouette, not a rectangle. Stroke: **2.5px** (see rule below), color `AppColors.ink`, fill: `paper`/white base, clipped fill rect rising from the bottom to `fillPercent` (see §3.3). |
| Neck | Small rect, centered `x≈42`, spanning `y≈52`→`60`, width ≈10, same skin tone as head, no separate stroke (reads as part of the head/body join). |
| Shirt collar | A single thin stroke line near the shoulders (`y≈58`-ish, following the vessel's shoulder curve), 1.5px, colored per-`AvatarSpec.shirt` — decorative only, not a fill region. |
| Head | Circle, **16px radius**, centered `x=42`, `y≈40` (sits atop the neck/body), fill = `AvatarSpec.skin`, stroke 2.5px ink (matching the body's stroke weight — see rule below). |
| Eyes | Two small filled dots, ink color, ≈2px radius each, positioned symmetrically at roughly `(36, 38)` / `(48, 38)` (upper-middle of the head circle). |
| Mouth | A simple short curved smile stroke below the eyes, ≈1.5px ink stroke, no fill. |
| Hair | A `Path`, drawn on top of the head circle, shape selected by `switch (spec.hair)` over the 6-value `AvatarHair` enum (§4), fill color = `AvatarSpec.hairColor`, no separate stroke on the hair shape itself (reads as a flat silhouette sitting on the head, consistent with the mockup's hair treatment). |

**Stroke-width rule:** always **2.5px** in the 84×104 unit space, matching this screen family's nearest sticker-card stroke (Home's `StatTile`/`_StreakCard`/the new `HomeAvatarCard` all use 2.5dp ink borders) — one consistent stroke weight across the whole figure (body + head), not a thinner "detail" stroke for the head. Collar/mouth strokes are intentionally thinner (1.5px) as *interior detail lines*, distinct from the figure's outer silhouette stroke — don't conflate the two roles.

### 3.2 Fill-color bands

Confirmed, architect's thresholds adopted as-is: **`>=60` → `AppColors.green`, `>=20` → `AppColors.coral`, else → the danger-red token (§3.5)** — matching the mockup's 100%/45%/4% three-sample demonstration exactly (100 lands in green, 45 lands in coral, 4 lands in the danger band). No adjustment needed; these round thresholds read clearly at a glance, which is the entire point of the figure-as-life-meter idea.

### 3.3 Fill mechanic

The body vessel's interior is clipped to its own silhouette path; a solid-color rect is drawn bottom-up to `fillPercent` height (`0`–`100%` of the vessel's own internal vertical extent, not the full 84×104 canvas) using `Canvas.clipPath` + a plain filled `Rect`. **Must animate**, not snap, whenever `fillPercent` changes while the card is visible (e.g. immediately after committing a new personal-best `bestLifePercent` mid-session) — reuse this app's established progress-bar animation convention (`AnimatedContainer`-equivalent height/rect tween, ~300–350ms `Curves.easeOut`, same family as `LifeBar`'s 350ms tween) rather than a hard-cut fill change. On first paint (card mount), animate in from 0 → the resolved `fillPercent` for a small "filling up" entrance beat — a nice-to-have consistent with this app's general "every progress-adjacent element should animate its resting state in" convention (onboarding splash, rewarded-ad bar), not a hard requirement.

### 3.4 Zero-state fill (fresh install, `bestLifePercent == 0`)

Per architect: render `fillPercent = 100` (green) with microlabel **"READY"**, never a near-empty red body as a first impression. This is purely a *display* override on the Home card and does not touch `AvatarFigure`'s general contract — the painter itself always just draws whatever `fillPercent`/color band it's given; `HomeAvatarCard` is responsible for computing "is this the zero-state" and substituting `(100, "READY")` for `(0, "BEST LIFE")` before passing props down. The picker screen's preview tiles (§5) are unaffected by this rule — they always show each catalog entry at a fixed demo fill (recommend 100%, i.e. always green, since the picker is about *choosing a look*, not reporting the player's actual life stat).

### 3.5 Red vs. redDark — resolved

**Call: use `AppColors.redDark` for both the Deaths tile's value text (§2.7) and the avatar vessel's danger fill band — same token, not two different ones.**

Reasoning:
- The accessibility flag is specifically about **text-on-`paper`** contrast at a bold/small size (StatTile's 17dp/700 value) — `redDark` (#B8362E) is the already-established accessible alternative in the palette for exactly this role (it already exists specifically as *"the final-band STOP button's label text-shadow"* per its doc comment in `app_theme.dart`, i.e. already proven as a legible dark-red-on-light-surface token elsewhere in the app). Using it for the Deaths tile value is a direct, low-risk application of an already-vetted token to an already-flagged contrast problem — no reason to leave a known-borderline color in a text role when the fix already exists in the palette.
- For the avatar's danger fill band, the fill is a **large solid color region**, not text — `AppColors.red`'s contrast concern (text-on-paper legibility) doesn't apply the same way to a big filled shape, where `red`'s slightly higher saturation actually reads as more "alarming/dangerous" at a glance, which is the whole communicative point of the danger band. That said, **there's no real cost to using `redDark` here too**: it's still clearly a red, still clearly reads as "danger," and using one token instead of two for "this app's one shared 'danger' signal" is simpler to reason about and keeps the Deaths-tile-value and the avatar's danger-band visually and semantically *the same* red across the dashboard — reinforcing rather than fragmenting the "red = bad/dying/dead" association a player builds up over many runs. Splitting them (accessible `redDark` for text, punchier `red` for the big shape) is defensible too, but isn't worth the inconsistency given `redDark` alone is plenty saturated to read as urgent at this fill size.
- **Net: `AppColors.red` is not used anywhere in this new work.** It remains defined and still used elsewhere (outcome cards, error note chip, Play Loop critical band) — this call doesn't deprecate the token app-wide, just avoids introducing a new borderline-contrast usage of it.

---

## 4. Avatar catalog — 12 `AvatarSpec` entries

Skin tones (6, cycled by index — new hex constants, catalog content not theme tokens):

| index | name | hex |
|---|---|---|
| 0 | Porcelain | `#FFE0C4` |
| 1 | Fair | `#F5C99B` |
| 2 | Tan | `#D9A066` |
| 3 | Deep tan | `#B87A45` |
| 4 | Brown | `#8B5A2B` |
| 5 | Deep brown | `#5C3A1E` |

Hair colors (6):

| index | name | hex |
|---|---|---|
| 0 | Jet black | `#2B2420` |
| 1 | Chestnut | `#5A3825` |
| 2 | Auburn | `#8B4A2B` |
| 3 | Honey blonde | `#D9A94F` |
| 4 | Platinum | `#E8DCC8` |
| 5 | Slate gray | `#8A8F94` |

Shirt colors — male (6):

| index | hex |
|---|---|
| 0 | `#4A9FD8` (blue) |
| 1 | `#5FA867` (leaf green) |
| 2 | `#C97B4A` (rust) |
| 3 | `#7B6FC9` (indigo) |
| 4 | `#3F5651` (deep teal) |
| 5 | `#B84A5C` (brick) |

Shirt colors — female (6):

| index | hex |
|---|---|
| 0 | `#E58BA0` (rose) |
| 1 | `#8AC9C4` (aqua) |
| 2 | `#D9A5D0` (orchid) |
| 3 | `#E5B95C` (mustard) |
| 4 | `#6FA88A` (sage) |
| 5 | `#C97BA0` (mauve) |

### 4.1 The 12 specs

Each `AvatarSpec.id` = `gender*6 + variant`; `skin`/`hairColor` cycle by variant index into the 6-value palettes above (variant index doubles as the palette index for simplicity — a clean, deterministic mapping, not a hand-picked one); `shirt` is that gender's own 6-value palette at the same variant index.

**Male (id 0–5):**

| id | variant | hair (`AvatarHair`) | skin | hairColor | shirt |
|---|---|---|---|---|---|
| 0 | 0 | `sweptBack` | Porcelain `#FFE0C4` | Jet black `#2B2420` | `#4A9FD8` |
| 1 | 1 | `sidePart` | Fair `#F5C99B` | Chestnut `#5A3825` | `#5FA867` |
| 2 | 2 | `spiky` | Tan `#D9A066` | Auburn `#8B4A2B` | `#C97B4A` |
| 3 | 3 | `curlyRound` | Deep tan `#B87A45` | Honey blonde `#D9A94F` | `#7B6FC9` |
| 4 | 4 | `wavySide` | Brown `#8B5A2B` | Platinum `#E8DCC8` | `#3F5651` |
| 5 | 5 | `buzzcut` | Deep brown `#5C3A1E` | Slate gray `#8A8F94` | `#B84A5C` |

**Female (id 6–11, variant = id − 6):**

| id | variant | hair (`AvatarHair`) | skin | hairColor | shirt |
|---|---|---|---|---|---|
| 6 | 0 | `longFlowingSplit` | Porcelain `#FFE0C4` | Jet black `#2B2420` | `#E58BA0` |
| 7 | 1 | `bobWithPart` | Fair `#F5C99B` | Chestnut `#5A3825` | `#8AC9C4` |
| 8 | 2 | `curlyWithBow` | Tan `#D9A066` | Auburn `#8B4A2B` | `#D9A5D0` |
| 9 | 3 | `pigtails` | Deep tan `#B87A45` | Honey blonde `#D9A94F` | `#E5B95C` |
| 10 | 4 | `longStraightCenter` | Brown `#8B5A2B` | Platinum `#E8DCC8` | `#6FA88A` |
| 11 | 5 | `shortBobCurlUnder` | Deep brown `#5C3A1E` | Slate gray `#8A8F94` | `#C97BA0` |

`AvatarHair` enum (12 total distinct names across both genders — one enum, not two, since the painter's `switch` just needs 12 distinct shape cases regardless of gender):
`sweptBack, sidePart, spiky, curlyRound, wavySide, buzzcut, longFlowingSplit, bobWithPart, curlyWithBow, pigtails, longStraightCenter, shortBobCurlUnder`.

`AvatarCatalog.byId(0)` is the documented fallback (architect's `.fallback` = id 0 = `sweptBack`/Porcelain/Jet-black/blue-shirt male).

---

## 5. Picker screen layout (`AvatarPickerScreen`)

### 5.1 Structure

```
┌────────────────────────────┐
│ ← 🧑 Choose your avatar      │  ScreenHeader(emoji: '🧑', title: 'Choose your avatar')
├────────────────────────────┤     reused verbatim, 16/700, back chevron included
│  ╭──────────╮╭──────────╮  │
│  │  Male    ││  Female   │  │  segmented toggle, see §5.2
│  ╰──────────╯╰──────────╯  │
│                            │
│  ┌───┐ ┌───┐ ┌───┐          │  GridView.count(crossAxisCount: 3),
│  │ 0 │ │ 1 │ │ 2 │          │  16dp horizontal screen padding,
│  └───┘ └───┘ └───┘          │  12dp cross-axis / main-axis gap,
│  ┌───┐ ┌───┐ ┌───┐          │  each tile AspectRatio 0.82 (same
│  │ 3 │ │ 4 │ │ 5 │          │  ratio as HomeAvatarCard §2.3)
│  └───┘ └───┘ └───┘          │
│                            │
│    [   Use this avatar   ]  │  StickerButton, 50dp, coral fill/
└────────────────────────────┘  coralDark shadow — matches Home's Play button
```

Screen padding: **16dp horizontal / 14dp vertical** — the existing "document-flow screen" convention (`remaining-screens-v1.md` §1.5, shared by Home/Stats/Settings), since this is a pushed sub-screen from Home in the same family, not a centered onboarding-style screen.

### 5.2 Segmented Male/Female toggle

No existing segmented-control precedent anywhere in this codebase (confirmed — searched; only the streak week-bar's "segments" exist, an unrelated concept) — **this is a genuinely new component**, built from the mockup's description using this app's already-established sticker language rather than inventing a new visual system:

- Container: full-width pill row, two equal-flex segments, **2.5dp ink border** around the *whole* pill (not per-segment), **3dp hard offset shadow** (a size between `StatTile`'s 4dp and nothing — the mockup specifies 3dp for this exact component, and since it's a toggle rather than a card or a primary CTA, sitting at the lighter end of this app's existing shadow-weight spectrum is appropriate — don't round it up to 4dp "for consistency"; 3dp is what the mockup calls out and there's no existing precedent it needs to match exactly).
- Radius: pill-shaped (`height / 2`), height **40dp**.
- Inactive segment: `paper` fill, `ink` text, no border of its own (relies on the outer pill border).
- Active segment: `coral` fill, white text, **no additional inner border/shadow** — the whole pill's single ink border + 3dp shadow is the only "sticker" framing; the active segment itself is a plain filled rounded-rect sitting inside that frame (a small inset, ~2dp, so the active fill doesn't touch the outer ink border).
- Text: 13dp/700 Fredoka, centered per segment.
- Tap either segment to switch the active gender — **local `State`, not committed to any provider** until the CTA tap (see §5.4's draft-then-commit rule). Switching gender resets the local grid selection to `null`/none highlighted (don't carry a "variant 3" selection across a gender switch onto a visually different id — forces an explicit re-pick, avoiding an accidental commit of an id the player never actually looked at).

### 5.3 Grid tiles (`AvatarTile`)

- `GridView.count(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.82)`, no separate `Card`-level shadow spec beyond what's below — reuses this app's existing sticker-card treatment at the same 2.5dp/4dp weight as `StatTile`/`HomeAvatarCard` (a grid of small cards is closer in weight to stat tiles than to a single hero card, so 4dp is right here, not 3dp — don't confuse this with the segmented toggle's 3dp, they're two different components on the same screen with two different, both-intentional shadow weights).
- Each tile: `paper` bg, 2.5dp ink border, 4dp shadow, 10dp radius (slightly tighter than the 14dp home card radius, appropriate for a smaller tile), `AvatarFigure` centered inside via `FittedBox`, demo `fillPercent: 100` (§3.4) so every catalog tile always previews as a full green figure — the picker is about hairstyle/skin/shirt, not life-state.
- **Selected-state override:** coral border (2.5dp, same weight, color swapped from `ink` to `coral`) + coral box-shadow (same 4dp offset, color swapped from `ink` to `coral`) — replacing the ink treatment entirely, not layering on top of it. Plus a **checkmark badge**: 20dp circle, coral fill, white checkmark icon (14dp), positioned top-right, inset 4dp from the tile's corner, minor overlap onto the tile's own border is expected/fine (matches the mockup's badge-overlapping-the-card-corner treatment).
- Tap behavior: sets local selection state only (not committed) — see §5.4.

### 5.4 Draft-then-commit

Both the gender-toggle position and the grid selection are local `State<AvatarPickerScreen>` fields, initialized from the currently-committed `selectedAvatarProvider` value on screen open (so re-opening the picker shows the player's current avatar pre-selected and its gender tab pre-active — not always defaulting to Male/none). Nothing is written to `avatar_repository`/`kKeyAvatarId` until the CTA is tapped. On CTA tap: commit the locally-selected id to `selectedAvatarProvider` (which persists via the repository), then `Navigator.pop()`. If the player backs out via the back chevron/gesture without tapping the CTA, nothing changes — a clean cancel, no confirm-dialog needed (this is a low-stakes, freely-repeatable choice per architect, not a destructive action).

### 5.5 CTA button

`StickerButton(label: 'Use this avatar', fill: AppColors.coral, labelShadow: AppColors.coralDark, height: 50, onPressed: ...)` — identical props to Home's existing Play button (`home_screen.dart`'s `StickerButton(label: 'Play', fill: AppColors.coral, labelShadow: AppColors.coralDark, height: 50, ...)`), reused verbatim rather than inventing a new size tier. Disabled (opacity 0.45, per this app's established disabled-sticker-button convention) only in the theoretical case no tile is selected — in practice this shouldn't be reachable since the screen always pre-selects the current avatar (or id 0 as a fallback for a never-picked player, so the CTA is always enabled the first time the picker opens too).

---

## 6. Verification checklist (game-ux-designer sign-off)

A build "matches spec" when all of the following hold:

1. **Tagline:** both Home and Splash render the exact string "One tap. From dust to forever." with no visible layout change from the previous strings (no new wraps, no clipped text, no resized containers) — verify at a few Android widths (~360–430dp) and with larger system font scaling.
2. **Home avatar card:** sits in the same flexible slot the old `Spacer` occupied, between the stat-tile row and the Play button; renders at `StatTile`-weight sticker styling (2.5dp ink / 4dp shadow / 14dp radius), never overflows on a short-height test device (emulate a small phone), and its `AspectRatio`-driven box visibly shrinks (not overflows/clips) when vertical space is tight.
3. **Zero-state:** on a fresh install / all-zero stats, the card shows a **full green** figure with microlabel **"READY"**, never a near-empty/red figure — and the coral "👆 Pick your look" hint pill appears above the card. After picking any avatar once, the hint permanently disappears on subsequent Home visits.
4. **Fill bands:** manually drive `bestLifePercent` through 4%/45%/100%-equivalent values (or check via debug override) and confirm danger/coral/green bands match §3.2's thresholds exactly, using `AppColors.redDark` (not `red`) for the danger band.
5. **Stat row:** confirms "Survived" (greenDark), "Eternal" (goldDark, unchanged), "Deaths" (redDark) render correctly, single-line labels don't visually crowd or leave odd extra whitespace in the Row versus the old two-line "Best life" label.
6. **Avatar figure fidelity:** for a sampling of at least 4–6 of the 12 catalog entries, confirm the painted figure is visibly, correctly distinct per entry — different hair silhouette, different skin tone, different hair color, different shirt-collar color — matching this doc's §4 table (not pixel-identical to the mockup's SVG, since it's a CustomPainter reinterpretation, but recognizably the same design intent: body vessel shape, head circle, dot eyes, hair-on-top).
7. **Picker screen:** `ScreenHeader` renders with back chevron + "🧑 Choose your avatar"; segmented Male/Female toggle switches the grid's 6 tiles correctly and resets any prior selection when switched; selected tile shows coral border + coral shadow + top-right checkmark badge (not the default ink treatment); "Use this avatar" CTA is visually identical to Home's Play button (same fill/shadow/height); tapping it commits the selection and pops back to Home, where the Home card now reflects the new avatar (and the fill-percent zero-state/normal logic, unaffected by the avatar's identity, still applies correctly).
8. **Draft-then-commit:** switching gender tabs or tapping different tiles inside the picker never changes what Home shows until the CTA is actually tapped; backing out without tapping the CTA leaves Home's previously-committed avatar untouched.
9. **Persistence:** avatar selection survives an app restart (verifies `kKeyAvatarId` round-trips through `SharedPreferences` correctly, id 0–11 mapping to the right gender/variant per §4's table).
10. **No regressions:** the streak card, week bar, Settings gear icon, and Play button are all pixel-identical to their pre-existing appearance — this change touches only the avatar-card slot and the stat-tile row's values/colors, nothing else in Home's layout.
