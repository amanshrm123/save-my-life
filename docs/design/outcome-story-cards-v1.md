# Stay Alive — Outcome Story Cards Visual & UX Spec v1

**Scope:** redesign of the Outcome Cards feature (previously spec'd in `docs/design/remaining-screens-v1.md` §2, shipped) to the new 9:16 "story card" format.
**Source mockup:** `docs/mockups/timingtap_card_stories.html` (a standalone reference sheet, no phone-frame chrome this time — read fresh).
**Consumes:** `docs/architecture/v4.md` in full — several visual-adjacent decisions are founder-resolved there (dark-only death, 🆘 swap, dropped catalog line, restored "Top 0.3%," the fetch/loading mechanism) and this doc builds on them rather than re-litigating them.
**Extends:** `docs/design/onboarding-v1.md`, `play-loop-v1.md`, `remaining-screens-v1.md` — reuses all existing color/type/sticker-button tokens; only genuinely new tokens are defined here.
**Supersedes:** `remaining-screens-v1.md` §2 (Outcome Cards) for visual purposes. That doc's §2 is now historical — don't build from it for this feature; this doc is the current reference. `remaining-screens-v1.md`'s other sections (Sharing mechanism, Ads, Home, Settings, etc.) are unaffected and still current.

Design spec, not code — no Dart.

---

## Revision 2 — Founder UI-only feedback pass (2026-07-30)

**Scope of this revision:** exactly four founder-requested UI changes to the already-shipped card, layered on top of the sections below rather than rewriting them. **UI-only** — no story-content/config/remote-fetch/dedup logic changes (that's a separate future pass). Where a change below alters a number or color quoted in the original sections (§1.1, §2.2, §5), **this revision is the current value; the original section is kept for context/history but is superseded on that specific point** — same layering convention as `play-loop-v2.md` uses over `play-loop-v1.md`, just embedded in this file since the scope here is much smaller than a full HUD rewrite.

Also **supersedes** `remaining-screens-v1.md`'s actions-row button numbers (its consolidated table's "40dp height, 12dp radius, 4dp shadow — a new size tier" row) — see R2.2 below for the current values.

### R2.1 Card shape — 3:4, not 9:16

**The shell's aspect ratio changes from `9/16` (0.5625, a phone-screen ratio) to `3/4` (0.75).** This is the exact founder complaint ("more of a mobile screen look, not a card") — 9:16 is literally a phone silhouette; 3:4 is a classic portrait card/poster ratio (close to standard playing-card and trading-card proportions), reads as "a card" both floating in-app and sitting on top of an arbitrary Instagram/WhatsApp background once shared. It's also a large enough departure from 9:16 to be visually obvious, not a marginal tweak — the founder's ask was for a real shape change.

**Note (Revision 3, 2026-07-30): this section's `3/4` ratio is itself superseded by Revision 3 §R3.1 below (now `4/5`). Kept here for history; don't build 3:4.**

`OutcomeCardShell.referenceWidth` **stays 250dp, unchanged.** It's only the width half of the `k = actualWidth / referenceWidth` scale factor and isn't tied to the aspect ratio at all; only `AspectRatio(aspectRatio: 3/4)` changes. At `k = 1.0` (a 250dp-wide box) the card is now **250×333.3dp**, down from 250×444.4dp.

**Content-fit check, so flutter-developer isn't guessing whether paddings need to shrink:**

- Fixed overhead at `k=1`: top/bottom padding (26+22=48dp) + top row (chip/icon, ≈32dp) + footer (tagline ≈32dp + 10dp gap + wordmark row ≈21dp + 10dp gap + store-badge row ≈31dp ≈ 104dp total) = **≈184dp** of the box is spoken for regardless of story length.
- That leaves **≈149dp** for the vertically-centered headline+story block in the new 333.3dp-tall box.
- Design v1 §10.7's own stated worst-case content bound — headline ~2 lines (27dp×1.12 ×2 ≈ 60dp) + 12dp gap + story ~4 lines (14dp×1.4×4 ≈ 78dp) — needs **≈151dp**.
- **Verdict: 3:4 fits the doc's own worst-case bound almost exactly** (≈151dp needed vs. ≈149dp available) — the existing `FittedBox(scaleDown)` safety net (§10.7) engages only fractionally (~1%, imperceptible) on the rare longest-possible combination, and not at all for the common case (1-line headline + 2-3 line story, which needs well under 100dp). **No padding/gap numbers need to shrink** — everything already scales by `k` per §2.2 and self-adjusts.
- **`CardFooter` needs no resize** — its own fixed content (tagline/wordmark/store-badges, ≈104dp at `k=1`) was already accounted for in the check above and isn't touched by this revision.
- **`OutcomeCardLoading`'s Stack layout also still clears safely**: its centered column (heart+headline+dots+subline, ≈155dp at `k=1`) plus the `Positioned`-at-bottom wordmark (≈24dp) fit inside the new 333.3dp box's padded region (≈285dp) with ≈41dp of clearance at `k=1` — tighter than the old 9:16 box's very generous slack, but not a collision risk. No changes needed to the loader's internal gaps, but there's materially less headroom now than before, so don't grow the loader's subline copy further without re-checking this.

*(This supersedes §2.2's "9:16" framing and literal 444dp reference height; §2.2's `k`-scaling *methodology* is unchanged and still the correct way to read every other dimension in this doc.)*

### R2.2 Actions-row buttons — grown to this app's own "standard" `StickerButton` size

**Note (Revision 4, 2026-08-05): this section's `44` height is itself superseded by Revision 4 §R4.1 below (now `52`, height only — `borderRadius`/`restShadowOffset`/`fontSize` stay as set here). Kept here for history; don't build height 44 for this row.**

`_ActionsRow`'s Share and Again buttons move from the compact "thin action-row variant" (`height: 40, borderRadius: 12, restShadowOffset: 4, fontSize: 13`) up to **exactly this app's own established default `StickerButton` size**, unchanged in every other respect (fill colors, `_shareButtonStyle`'s per-tier logic, the two-`Expanded`-equal-width row shape, "Again"'s paper/ink styling):

| param | old | **new** |
|---|---|---|
| `height` | 40 | **44** |
| `borderRadius` | 12 | **14** |
| `restShadowOffset` | 4 | **5** |
| `fontSize` | 13 | **14** (i.e. drop the override — falls back to `AppTypography.buttonLabel`'s own 14dp default) |

**Why these exact numbers, not an arbitrary bump:** this is the same 44/14/5/14 tier already used everywhere in the app that doesn't explicitly opt into a smaller/bigger variant — onboarding's "Start playing"/"Try again" (`name_capture_view.dart`), every `teach_card.dart` CTA, and the first (non-"thin") button in `pause_overlay.dart`/`reset_confirm_dialog.dart`/`ad_failed_view.dart`. It's a real, pre-existing size step in this codebase (not a new one), sitting between the 40dp "thin" tier and Home's 50dp hero `Play` button (which itself keeps radius/shadow/font at 14/5/14 and only bumps height further — confirming radius/shadow/font are meant to stay constant across the 44→50 step, only height moves). Landing on 44/14/5/14 here is the smallest real step up from 40/12/4/13 available anywhere in this app's existing scale, which is exactly the "grow it, keep the pattern" ask.

**Home text-link spacing:** no change needed. There's no dedicated gap widget between the actions row and the "Home" link today — the row relies on `StickerButton`'s own reserved bottom padding (`restShadowOffset`, now 5dp instead of 4dp) plus the link's own `vertical: 4` padding for breathing room. The actions row's total footprint grows by only ≈5dp, and it sits in a `Column` where the card above is the only `Expanded` child — that ≈5dp is absorbed by the card shrinking slightly, not by anything below it. Leave the `SizedBox(height: 14)` above the row and the link's `Padding(vertical: 4)` exactly as they are.

### R2.3 Share button arrow — tilted 60° counter-clockwise, via a new opt-in `StickerButton` slot

**Note (Revision 4, 2026-08-05): this section's `-pi/3` (60°) rotation is itself superseded by Revision 4 §R4.2 below (now `-pi/4`, 45°). Everything else here (the additive-slot decision, the literal "→" glyph, the 6dp gap) is unchanged and still current.**

**Decision: (a) — add a strictly-additive, opt-in slot to the shared `StickerButton`, not a one-off widget.** `StickerButton` already has this exact precedent (`showLabelTextShadow`, `fontSize` are both opt-in overrides that default to today's behavior for every other call site) — extending that same pattern is more consistent with this codebase's own conventions than duplicating ~100 lines of press-animation/shadow/disabled-opacity chrome in a parallel one-off widget just to rotate one glyph. A one-off widget would also mean two button implementations to keep visually in sync forever; the additive-slot approach has exactly one.

- New param: **`showTrailingArrow` (`bool`, default `false`)** — every other call site (14 files) is completely unaffected; default behavior (a single centered `Text(widget.label, ...)`) is unchanged.
- When `true`, the button's content becomes `Row(mainAxisSize: MainAxisSize.min)`: `Text(label, style: <existing label style>)` → `SizedBox(width: 6)` → `Transform.rotate(angle: -60° in radians (i.e. -pi/3), child: Text('→', style: <same style as label, same color/shadow>))`. Everything else (`Container` sizing, border, box-shadow, press/scale animation, disabled-opacity) is unchanged and wraps this row exactly as it wraps the plain `Text` today.
- **Glyph: keep the literal "→" character (U+2192), rotated via `Transform.rotate` — do not swap to a Material `Icon`.** Every icon-like element elsewhere in this app (💀🆘✨💓 chip/wordmark glyphs, the store badges' bare `▶`/blank icon slots) is a plain Unicode/emoji character rendered inside `Text`, never a Flutter `Icon` widget. Introducing `Icons.arrow_forward`/`Icons.north_east` here would be the first Material-icon-widget usage in an otherwise all-glyph-as-text app and would visually mismatch stroke weight/style against everything around it.
- **Rotation, stated unambiguously: `angle: -pi/3` (-60°) in `Transform.rotate`.** Flutter's `Transform.rotate` treats positive angles as clockwise; `-60°` is therefore **counter-clockwise**, which takes the rightward "→" and tilts it to point up-and-to-the-right at 60° above horizontal — steeper/more vertical than a standard ~45° north-east diagonal. This is the correct reading of "tilt it upward ~60 degrees."
- **Spacing:** fixed **6dp** between the label text and the arrow (`SizedBox(width: 6)`) — not `k`-scaled, since this button lives on the native at-rest screen chrome outside the card's `RepaintBoundary`/`k` system. 6dp matches this codebase's own existing "small inline glyph next to text" precedent (`OutcomeWordmark`'s heart-to-text gap), rather than inventing a new spacing value.
- Label strings drop their baked-in arrows: `'Share →'` → `'Share'` (+ `showTrailingArrow: true`), `'Flex it →'` → `'Flex it'` (+ `showTrailingArrow: true`). `_shareButtonStyle`'s per-tier fill/text-color logic is otherwise untouched.

### R2.4 Name-span colors — more vibrant per tier, contrast-checked against the *actual rendered* color (post 0.85-alpha blend)

Important framing: `_storyText()` already composites the name span at `alpha: 0.85` over the tier's card background (§4's own note: "the whole block including the name span" carries the tale's 0.85 opacity). Contrast must be judged on that **blended** result, not the token's raw hex against the raw background — a color that looks fine at full opacity can measure meaningfully weaker once blended toward a light background. All figures below are the blended-result contrast ratio (WCAG-style relative-luminance ratio), not the raw-token ratio.

| tier | verdict | color | rationale |
|---|---|---|---|
| **Death** | **unchanged** | `AppColors.deathChipTextOnDark` `#FF8A82` | Post-blend contrast against `ink` ≈ **5.0:1** — clears WCAG AA (4.5:1) with real margin. Already a vivid coral-pink against near-black; already reads "catchy." Nothing to fix here. |
| **Survived** | **new token** `AppColors.surviveNameSpan = Color(0xFF065C31)` (deep saturated pine/emerald) | replaces `greenDark` **for the name-span role only** — `greenDark` keeps its existing chip-text and wordmark-accent roles unchanged (same "each color has exactly one role" discipline this doc already applies to Eternal's browns) | The *current* reused `greenDark`, once you account for the 0.85-alpha blend against `surviveCardBg`, only measures **≈2.7:1** — a real, previously-unflagged legibility weak spot (below even AA-large's 3:1), not just a "not vibrant enough" complaint. `surviveNameSpan` measures **≈5.3:1** post-blend — both a fully-saturated, jewel-toned green (reads "catchy," not pastel) and safely legible. |
| **Eternal** | **new token** `AppColors.eternalNameSpan = Color(0xFF8B1E3F)` (deep ruby/garnet) | replaces `eternalNo` **for the name-span role only** — `eternalNo` is left defined and untouched (it has no other call site today, but per this doc's own "don't consolidate/repurpose a named token" precedent, it's retired from this one role rather than having its value edited in place); `eternalInk`/`eternalBrandAccent`/chip fill are all unaffected | The *current* `eternalNo`, post-blend, measures only **≈3.5:1** against the gradient's darker stop (`eternalGradientEnd` `#FFE0A8`) — below AA's 4.5:1. The founder's "muted brown doesn't pop" complaint tracks a genuine contrast gap, not just taste. `eternalNameSpan` measures **≈5.2:1** against the darker stop and **≈5.8:1** against the lighter stop (`eternalGradientStart` `#FFF2D4`), post-blend — both ends of the gradient now clear AA with real margin, and a ruby-jewel-tone-on-gold pairing reads as distinctly more vibrant/premium than an olive-brown, which also fits an "Eternal" top-tier outcome thematically. |

**No new token for Death** — its existing value already does the job.

**Anonymous/no-name case is unchanged and correct, confirmed:** when `playerName.isEmpty`, `_storyText()` returns `Text(content.storyAnonymous, style: baseStyle)` — a separate branch that never touches `nameColor`/`palette.nameSpan` at all. None of the above color changes affect that path; it stays fully uncolored, exactly as today.

---

## Revision 3 — Founder + player-reviewer follow-up: card still reads as a screenshot, not a card (2026-07-30)

**Trigger:** a real screenshot (`/tmp/oc_death3.png`, a short Death story — 1-line headline + 1-line story) surfaced a problem Revision 2 didn't catch: shrinking the box from 9:16 to 3:4 does nothing to fix short-content runs, because the actual bug is **structural, not proportional**. `Expanded(child: Center(child: FittedBox(_StoryBlock)))` centers whatever content there is in *whatever leftover space the box has* — for the doc's own stated worst-case content (§10.7's ~2-line headline + ~4-line story), that leftover space is deliberately near-zero (R2.1's fit-check), but for the much more common short-content case, the leftover space is still ≈half the box's total middle region, split evenly above and below the text as two separate dead zones. Shrinking the box (3:4) shrinks that leftover space too, but *proportionally* — a smaller empty gap is still a highly visible empty gap when it's still ~50% of the visible card. The shape change alone was never going to fix this; it needed a change to how that leftover space is *allocated*, not just how much of it there is. **Scope: two changes, both required together** — a further ratio adjustment (the founder's explicit ask for a shorter card) and a structural fix to the middle region's alignment (the actual fix for the dead-zone problem). Neither alone fully addresses both the founder's shape complaint and the player-reviewer's "looks unfinished" complaint.

### R3.1 Card shape — **4:5, not 3:4** (shorter/more square, further in the same direction as R2.1)

**Stated unambiguously: `width : height = 4 : 5`** — at `k=1` (a 250dp-wide box) that's **250 × 312.5dp**, down from 250×333.3dp at 3:4 and 250×444.4dp at the original 9:16. This is the *shorter* direction (moving the ratio value `width/height` from 0.75 up toward 1.0, i.e. toward square) — **not** a taller card. `referenceWidth` stays 250dp, unchanged, per R2.1's own note that it's independent of the aspect ratio.

**Why 4:5 specifically, not a bigger or smaller step:**
- It's a real, visible step shorter than 3:4 (≈21dp less height at k=1, ≈6% of the box), addressing the founder's explicit "reduce the length further" ask, without going all the way to 1:1. A square card reads as a generic tile/icon, not a "card" in the trading-card/poster sense this doc has been deliberately building toward since R2.1 — 4:5 keeps that portrait-card read while being visibly more compact.
- **4:5 is also literally Instagram's own maximum portrait feed-post ratio** (1080×1350px). This matters specifically for the shared-image stakes raised in this feedback round: a card shared to an Instagram feed post (as opposed to a Story) at 4:5 renders edge-to-edge with no letterboxing or auto-crop; 3:4 or 9:16 both risk IG cropping the top/bottom off an already-tight composition. This is a concrete, external-platform reason to land on this exact number rather than an arbitrary "a bit shorter."
- Going shorter still (e.g. 1:1) was rejected: at `k=1` a square box is only 250dp tall, leaving just ≈54dp for the headline+story region after fixed overhead (see fit-check below) — far short of even the *common* short-content case (≈101dp needed), which would force FittedBox to shrink common-case content on nearly every run, not just the rare worst-case. That trades one visible problem (empty gap) for a worse one (constantly-shrunk, harder-to-read text).

**Content-fit check at 4:5, including R3.2's structural change below** (fixed overhead now includes the new 12dp gap from R3.2):

- Fixed overhead at `k=1`: padding (48dp) + top row (≈32dp) + new fixed top-of-story gap (**12dp**, R3.2) + footer (≈104dp, unchanged, `CardFooter` untouched by this revision) = **≈196dp**.
- Available for the headline+story region in the new 312.5dp-tall box: **≈116.5dp** (down from ≈149dp at 3:4).
- **Common case** (1-line headline + 2–3 line story, the typical pooled entry): ≈101dp needed → fits with ≈15dp of intentional breathing room left over, all of it now pooled in one place (below the content, before the footer — see R3.2), not split into two dead zones. This is the case the founder's screenshot actually showed, and it's the one that matters most for "does this look finished."
- **Doc's own stated worst-case bound** (§10.7: ~2-line headline + ~4-line story, ≈151dp needed): now needs the `FittedBox(scaleDown)` safety net to engage at roughly **116.5/151 ≈ 77%** scale — a real, visible shrink (≈23%) on that specific combination, up from Revision 2's ~1%/imperceptible engagement. **This is a deliberate, acknowledged tradeoff, not an oversight** — see R3.4.
- **Loader clearance, rechecked**: `OutcomeCardLoading`'s padded region shrinks from ≈285dp (at 3:4) to ≈264.5dp (at 4:5); its centered column (≈155dp) plus bottom-positioned wordmark (≈24dp) now clears with **≈31dp** of margin at `k=1` (down from R2.1's ≈41dp) — tighter again, but still comfortably positive. No loader-internal changes needed, but there is now less headroom than R2.1 assumed; don't grow loader copy without rechecking this number specifically.

### R3.2 The actual fix for the empty-gap problem: stop centering, anchor to the top, and pool all leftover space in one place before the footer

**Keep `FittedBox(scaleDown)` exactly as-is** (it's the correct long-content safety net — see R3.4) but change what it's positioned inside:

- **Replace `Expanded(child: Center(child: FittedBox(...)))` with `Expanded(child: Align(alignment: Alignment.topCenter, child: FittedBox(fit: BoxFit.scaleDown, child: _StoryBlock(...))))`.** `Alignment.topCenter` keeps the existing horizontal centering behavior (`Center`'s x-axis behavior, unchanged — don't switch to left-anchoring; the block's own internal `crossAxisAlignment.start` on `_StoryBlock`'s `Column` already governs the text's own left-ragged wrapping, and that's independent of where the block as a whole sits in the row) and changes only the vertical anchor, from mid-region to top-of-region.
- **Add a new fixed `SizedBox(height: 12 * k)`** between the top `Row` (chip/icon) and the `Expanded` story region, so the now-top-anchored block doesn't sit flush against the chip row. **Use exactly 12dp** — not a new number — to match the existing 12dp gap `_StoryBlock` already uses between its own headline and story text (design v1 §3/§5), so the card reads with one consistent vertical rhythm (top-row → headline gap = headline → story gap = 12dp) rather than an arbitrarily different spacing value.
- **Net effect:** whatever leftover vertical space the story content doesn't use no longer splits into two dead zones (one above the headline, one below the story, both currently reading as "the app forgot to put something here"). It now collects entirely in **one place**, directly below the story text and directly above `CardFooter` — which reads as intentional pre-footer breathing room (the same kind of deliberate whitespace every card/poster layout uses before a footer lockup) rather than a void the content is floating in the middle of. This is the same total amount of empty space math-wise for any given piece of content; what changes is that it now reads as *design*, not *missing content* — which is the exact distinction the player-reviewer's "looks unfinished" reaction was picking up on.

### R3.3 What this does NOT touch

- `CardFooter` itself — untouched, same ≈104dp footprint, same tagline→wordmark→store-badges structure and gaps.
- The top `Row` (chip + icon) — untouched.
- `_StoryBlock`'s own internal composition (headline, 12dp gap, story text, name-span colors) — untouched; only *where* this block sits within the `Expanded` region changes.
- `OutcomeCardLoading`'s internal layout — untouched (see the rechecked clearance number in R3.1; it still clears, just with less slack).
- Action-row buttons, share-arrow tilt, name-span colors (R2.2–R2.4) — untouched, still current.

### R3.4 Confirming the long-content safety net still holds (the opposite edge case)

`FittedBox(fit: BoxFit.scaleDown)` has no "failure" mode by construction — it always scales its child down to fit the constraints it's given, however small those constraints get; it cannot produce a `RenderFlex` overflow or a crash regardless of how tight R3.1+R3.2 make the available region. So the **crash/overflow safety guarantee is fully intact** — nothing here reopens the risk of a broken shared PNG.

What genuinely changes is **how much it visibly shrinks** on the rare worst-case combination (§10.7's ~2-line headline + ~4-line story): from Revision 2's ~1% (imperceptible) to this revision's ~23% (a real, visible size reduction — headline ≈27dp→≈21dp, story ≈14dp→≈11dp at k=1 for that specific combination only). This is an accepted, deliberate tradeoff of this revision, not an unnoticed regression:
- It only engages at the doc's own stated *absolute ceiling* for authored content length — the common case (1-line headline + 2–3 line story) still fits with room to spare and is never touched (see R3.1's fit-check).
- §10.7 already told content authors to treat "~2 lines / ~4 lines" as a bound to write toward, not a target — this revision makes that bound meaningfully harder, and that guidance should now be read as a **hard ceiling**, not a comfortable ballpark. Flag this explicitly to whoever authors/extends the 66 pooled entries: content sitting right at that ceiling will now render visibly smaller than the reference composition, more than before.
- If this proves too aggressive once real pooled content is reviewed against it, the cheapest lever to claw back headroom without re-opening the empty-gap problem is trimming `CardFooter`'s own 10dp inter-element gaps (untouched by this revision, per R3.3) — flagged here as the next place to look, not something to change now.

---

## Revision 4 — Founder ask: bigger actions-row buttons, shallower arrow (2026-08-05)

**Trigger:** direct founder request — Share/Again read as too small, and the Share arrow's 60° tilt (R2.3) should be shallower/more natural at 45°.

### R4.1 Actions-row buttons — height only, height 44→52 — **supersedes R2.2's height value**

`_ActionsRow`'s Share and Again grow from **44dp to 52dp** height. Explicitly **height only** — `borderRadius` (14), `restShadowOffset` (5), and `fontSize` (falls back to `AppTypography.buttonLabel`'s 14dp default) all stay exactly as R2.2 set them. This was a real decision point (a proportional 14→16/5→6 scale was tried and rejected): scaling the radius/shadow too would have made these buttons rounder *and* chunkier-shadowed than every other button in the app, including Home screen's own hero `Play` button (50dp height, radius/shadow held at 14/5 — R2.2 §49's own point that radius/shadow/font stay constant across a height-only step). Height-only at 52 keeps that same precedent: still the identical `StickerButton` "pattern," just one step taller than the 44dp tier, sitting between it and Home's 50dp hero button on height alone.

**Toast position, re-derived, not re-guessed:** R2.2's "Home text-link spacing: no change needed" is now superseded too — this revision also grows the Home link (see R4.3), so the actions-row-plus-Home-link footprint grows by more than R2.2's ≈5dp. The `'✓ Shared'` toast's `Positioned(bottom: ...)` in `outcome_card_screen.dart` is fixed-offset from the bottom of the same `Stack`, not derived from the buttons/Home link's actual layout — it does not auto-adjust. Re-derived from `62` to `80`, preserving the exact same ~6dp overlap into the button box's empty top padding (never the label itself) that `62` had against the pre-Revision-4 44dp buttons/19dp-tall Home link. Any future resize of this row must re-derive this value the same way, not assume it scales itself.

### R4.2 Share button arrow — 60° → 45° — **supersedes R2.3's rotation value**

`Transform.rotate(angle: -pi/3, ...)` → **`-pi/4`** (still negative/counter-clockwise, still tilting the "→" up-and-to-the-right — just to a shallower, more conventional ~45° north-east diagonal instead of R2.3's steeper 60°). Everything else in R2.3 is unchanged: still the literal "→" glyph (not a Material `Icon`), still a fixed 6dp gap, still sharing the label's color/font but never its text-shadow.

### R4.3 Home text-link — bigger, still a plain link, not a sticker button

Explicitly considered and rejected: converting Home into a third `StickerButton` matching Share/Again's pattern. Kept as a plain text link (R2.2's original call) — just bigger: padding `vertical: 4` → **`8`**, and a local `.copyWith(fontSize: 13)` on this one `Text` (not a change to the shared `AppTypography.ghostLink` constant, which stays `11` for its other two call sites — `share_target_sheet.dart`'s "More…" and `name_capture_view.dart`'s "Skip for now" — both genuinely unaffected).

---

## 0. What actually changes, visually (recap of architecture v4 §0, visual lens only)

- One unified 9:16 card silhouette, replacing the old "badge pill above a separate bordered box." **(Superseded by Revision 2 §R2.1, itself superseded by Revision 3 §R3.1 — the silhouette is now 4:5, not 9:16 or 3:4. Kept here for history; don't build the 9:16 ratio.)**
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
| **Death (dark/inverted — the only Death treatment now)** | `ink` `#1F2A2E` | `paper` `#FFFDF7` | red @ 20% over ink → `rgba(240,72,62,0.2)` (new token `deathChipFillOnDark`) | **`#FF8A82`** (new token `deathChipTextOnDark`) | **`#FF8A82`** — *not* plain `red` (see §4.1's contrast fix) — **unchanged by Revision 2 §R2.4** | `coral` (unchanged — Death keeps the universal brand coral, doesn't retheme it) |
| **Survived** | `#EAFAF1` (new token `surviveCardBg`) | `#0C3B28` (new token `surviveInk`) | `#D3F2E1` (new token `surviveChipBg`) | `greenDark` (reused) | ~~`greenDark` (reused — same value serves both roles)~~ **superseded by Revision 2 §R2.4: `AppColors.surviveNameSpan` `#065C31`, a dedicated token, no longer reuses `greenDark` for this role** | `greenDark` (reused) |
| **Eternal** | **gradient** `linear-gradient(160deg, #FFF2D4 → #FFE0A8)` (new — see §1.2, this is a real change from the current flat-gold card) | `#5A3D00` (new token `eternalInk`) | `#5A3D00` (dark brown fill — same as base ink, an intentional "badge pops dark against the light gradient" inversion) | `gold` (reused) | ~~reuses the existing `AppColors.eternalNo` token~~ **superseded by Revision 2 §R2.4: `AppColors.eternalNameSpan` `#8B1E3F`, a dedicated token; `eternalNo` is retired from this role (left defined, unused)** | **`#A8720C`** (new token `eternalBrandAccent` — a **4th**, distinct brown; don't reuse `eternalNo`/`eternalWay`/`eternalName` for this) |

**Note on Eternal's browns:** this tier now has **four** distinct dark-amber shades in play across the app (`eternalNo #8A5A00`, `eternalWay #6B4600`, `eternalName #B5500E` from the old card, plus this doc's new `eternalBrandAccent #A8720C`). They are all subtly different and each has one specific role. Do not consolidate them — that's exactly the kind of "collapse the similar grays" mistake flagged in every prior pass, just with ambers this time. (Revision 2 retires `eternalNo` from the name-span role specifically — see §R2.4 — without touching the other three or deleting `eternalNo` itself.)

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

**Note (Revision 2): this section's literal "9:16"/"250×445" numbers are superseded by §R2.1 above (now 3:4, 250×333.3 at `k=1`). Note (Revision 3): 3:4 is itself now superseded by §R3.1 (now 4:5, 250×312.5 at `k=1`). The shape/shadow rules and the `k`-scaling methodology below are otherwise unchanged and still current.**

### 2.1 Shape, radius, and — the one deliberate shadow exception in this whole app

`.card`: 26dp corner radius, **no border at all**, and a **soft, blurred drop shadow** — `offset (0, 16), blurRadius 36, color ink @ 20% opacity` (`rgba(31,42,46,0.20)`).

**This is a real, deliberate departure from every other component in the app**, which uses the "sticker" pattern (2–3dp ink border + hard, zero-blur, offset-only shadow). Two options were on the table; here's the call and the reasoning:

- **Adopt the mockup's soft shadow and borderless shape for the outer card silhouette. Do not force the sticker pattern onto it.**
- **Why:** this card's entire purpose culminates in a rasterized export shared *outside* the app — to Instagram Stories, WhatsApp, wherever — where it will sit on top of someone else's photo, video, or story background, not this app's own pastel `bg`. A hard-edged sticker shadow is styled specifically to read well against *this app's* flat background; a soft, naturalistic shadow reads as "a floating card" against arbitrary external backgrounds, which is exactly the context this artifact actually lives in most of the time. The mockup itself is a dedicated, separate reference sheet for this one shareable artifact — every other element on it (loader, chip, store badge) also skips the sticker treatment, consistently, which reads as an intentional alternate visual system for this one specific export-oriented component, not an oversight to "fix" back to house style.
- **Scope of the exception:** this applies **only** to the outer card shell (both the loading and resolved states, since both share one silhouette per architecture §7's `outcome_card_shell.dart`). It does **not** extend to anything outside the `RepaintBoundary` — the Share/Again action buttons and the confirm toast on the surrounding screen stay sticker-styled, hard shadow (now at the grown R2.2 size). Flag this scope boundary clearly for a future verification pass: a hard-shadowed Share button sitting directly below a soft-shadowed card is *correct*, not an inconsistency to unify.

### 2.2 Dimensions — scale the card's contents to its box, don't fix them at the mockup's literal size

The mockup shows the card at a literal 250×445 (≈9:16, off by rounding) — **that literal ratio is superseded by Revision 2 §R2.1, itself superseded by Revision 3 §R3.1 (now 4:5)**; the scaling *methodology* below is unchanged. Per this project's established convention, mockup pixels are usable directly as dp — but that convention was built for *native, at-rest interactive screens* that are always viewed at whatever size a given phone happens to be. This component is different in kind: it's captured via `AspectRatio` + `RepaintBoundary` at `pixelRatio: 3` (architecture §6) and its entire reason for existing is to produce a correctly-proportioned rasterized image, regardless of the source device's screen size.

**Recommendation — a deliberate departure from the "mockup px = dp directly" convention used everywhere else in this app, for this component only:**
- Let the card's outer box size responsively (`AspectRatio` inside whatever `Expanded` space the screen gives it — same structural approach the current implementation already uses).
- Compute a single scale factor once the box's actual width is known: `k = actualWidth / 250` (the mockup's reference width — unchanged by Revision 2 or Revision 3).
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
│                            │  ^ (Revision 3 §R3.2: this block is now
│                            │    TOP-anchored in its available space, not
│                            │    centered — see R3.2 for the exact fix;
│                            │    leftover space now collects below it)
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

Container: `Column` — `.top` row, then (Revision 3: a fixed 12dp gap, then) an `Expanded`/flexible middle region **top-anchored** (Revision 3 §R3.2 — was centered both axes) containing headline+story, then the footer column pinned at the bottom (tagline → wordmark → store badges, each 10dp gap, centered, `text-align: center`).

(The box this whole anatomy lives inside is now 4:5, not 9:16 or 3:4 — see §R3.1 for the fit-check confirming this anatomy still works at the new ratio, and §R3.2 for the alignment change.)

---

## 4. Per-tier specifics

### 4.1 Death (dark/inverted only) — the name-span contrast fix

Build **only** the `.death.inv` treatment. The mockup's plain `.death` (light, paper bg) card is **not built** — it's superseded by architecture's founder-resolved "dark/inverted by default" call. (The underlying *structural* pattern of "light bg, dark ink text" isn't wasted, though — it's exactly what Survived and Eternal already use; only Death itself moves off it.)

**Contrast fix, adopted as specified in your brief:** the mockup's literal CSS never overrides `.nm` (name-span) for `.death.inv`, so it would inherit plain `red` (`#F0483E`) on the near-black `#1F2A2E` card — architecture measured this at roughly 3.5:1, legible but weak. **Use `#FF8A82` for the name-span instead** (the same lighter red the mockup already defines for the inverted chip's own text) — this is the one place in this doc where the built card should render a color the literal mockup CSS doesn't actually specify for that element, because the mockup's own adjacent choice (the chip text) already established the "right" lighter red to use. **(Revision 2 §R2.4 re-confirms this value is still correct — ≈5.0:1 post-blend — no change.)**

Chip: pill, fill `rgba(240,72,62,0.2)` (red at 20% opacity, painted over the ink card — implement as a semi-transparent red `Color` on top of the ink background, not a pre-blended opaque color, so it stays correct if the underlying card color ever changes), text `#FF8A82`, label **"💀 You died"**.

### 4.2 Survived

Chip: fill `#D3F2E1`, text `greenDark`, label **"🆘 Survived"** — the emoji swap from 🛟 applies to the chip label text *and* the icon pool (§8); don't leave 🛟 anywhere, including as a possible icon-pool draw. **Name-span: see Revision 2 §R2.4 — now `surviveNameSpan #065C31`, not `greenDark`.**

### 4.3 Eternal

Chip: dark-brown fill (`#5A3D00`) with `gold` text, label **"✨ Eternal · Top 0.3%"** (static flavor copy — not computed, not a real percentile, per architecture's explicit founder-resolved reversal of the previous card's drop). Card fill is the two-stop gradient from §1.2. Four distinct browns are in play across the different text roles (§1.1) — don't collapse them. **Name-span: see Revision 2 §R2.4 — now `eternalNameSpan #8B1E3F`, not `eternalNo`.**

### 4.4 No-name fallback

Same structural treatment as its tier (most commonly Death) — the story renders its anonymous variant with **no colored name-span at all**, exactly the same generic pattern already established in `remaining-screens-v1.md` §2.2 ("3.4 is not a fourth content pool"). Nothing new to spec here; same resolution, new layout. **Confirmed unaffected by Revision 2 §R2.4's color changes** — this path never reads `nameSpan` at all.

---

## 5. Typography reference table

| role | size | weight | line-height | letter-spacing | opacity | notes |
|---|---|---|---|---|---|---|
| Chip | 10dp | 700 | — | 0.12em | 1 | uppercase |
| Icon (top-right slot) | 28dp | — | — | — | 1 | native emoji glyph, no color |
| Headline | 27dp | 700 | 1.12 | — | 1 | the single largest text anywhere in this app's type scale so far |
| Story/tale | 14dp | 500 | 1.4 | — | 0.85 | name-span (`.nm`) is 700 weight, same size, tier-colored (colors: see Revision 2 §R2.4) |
| Tagline | 12dp | 600 | 1.35 | — | 0.75 | max-width ≈200dp at k=1.0, centered |
| Wordmark text ("Stay Alive") | 19dp | 700 | — | — | 1 | |
| Wordmark heart glyph | **15dp** | — | — | — | 1 | smaller than the wordmark text — a different ratio than onboarding's splash hero mark; don't unify them |
| Store badge label line 1 ("Download on"/"Get it on") | 8dp | 600 | 1 | — | 1 | |
| Store badge label line 2 (bold store name) | 10dp | 700 | 1 | — | 1 | stacked directly below line 1, same badge |
| Store badge icon glyph | 12dp | — | — | — | 1 | see §6 — App Store's is blank in the mockup |
| Loading headline ("Loading your life card…") | 19dp | 700 | — | — | 1 | numerically matches the wordmark's 19dp — coincidental, not a shared role |
| Loading subline | 12dp | 600 | — | — | **0.6 light / 0.55 dark** | two genuinely different opacity values per variant — don't collapse to one |
| Pulsing heart (loader) | 44dp | — | — | — | animated 1↔0.7 | see §7 |
| Actions-row button label (Share/Again) | **14dp** (Revision 2 §R2.2 — was 13dp) | 700 | — | — | 1 | `AppTypography.buttonLabel`'s own default; the override is dropped |

All sizes are reference values at `k = 1.0` (§2.2) — scale by the card's actual box width. (The button-label row is the one exception — that button lives outside the `k`-scaled card, on native screen chrome, per §R2.2/§R2.3.)

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

(See Revision 2 §R2.1 for confirmation this layout still clears the 3:4 box's available height; see Revision 3 §R3.1 for the rechecked clearance at the current 4:5 box, with reduced but still sufficient margin.)

### 7.2 Animation timing (exact, from the mockup's keyframes)

- **Heartbeat pulse:** `scale(1)→scale(1.18)→scale(1)`, opacity `1→0.7→1`, over **1s, ease-in-out, infinite loop**.
- **Dot bounce:** each dot translates `Y: 0 → -6dp → 0`, opacity `0.4 → 1 → 0.4`, over **0.9s, ease-in-out, infinite loop**, staggered with **0s / 0.15s / 0.3s** start delays across the three dots (a classic loading-dots stagger — implement as one shared `AnimationController` with three `Interval`-shifted curves, per architecture §8's "one `Ticker`, not four" memory-safety note, not three independent controllers).
- Dot size: 9dp diameter circles.
- These loop for however long the actual fetch takes, guaranteed ≥2s by the provider layer (architecture §2) — the loader has no fixed "duration" of its own; it just runs until the `AsyncValue` resolves, then unmounts (and its single `AnimationController` disposes with it).

### 7.3 Screen-level button states during loading (a gap neither mockup nor architecture's visual layer addresses)

The mockup only shows the loader *card*; it doesn't depict the surrounding screen's Share/Again action row during that phase. Architecture §6.3 requires gating Share on `hasValue`. Recommend:
- **Share:** visible but disabled — reuse this app's established disabled-button convention (opacity 0.45, non-interactive), the same treatment used for onboarding's "Start playing" and Play Loop's dimmed STOP button. Don't hide it outright; a disabled-but-visible Share reads as "not ready yet" rather than "doesn't exist." (Now at the R2.2-grown size.)
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
6. **Card shell's soft-shadow/borderless exception** (§2.1) — a deliberate, singular departure from the house sticker pattern, scoped explicitly to the card only, not the surrounding screen's buttons.
7. **Story/headline content length isn't visually bounded anywhere** — the fixed-box (now 4:5, Revision 3) with a fixed-size headline+story region means very long authored copy could overflow that region. This is a content-authoring constraint, not a Flutter problem to solve with dynamic font-shrinking (which would fight the proportional-scale approach in §2.2) — flag to whoever authors/extends the 66 pooled entries: keep headlines to ~2 lines and stories to ~4 lines at the reference scale. **Revision 3 §R3.4 confirms this bound is now a genuinely tight ceiling (~23% FittedBox engagement at the ceiling, not ~1%)** — respect it as a hard limit, not a comfortable ballpark.
8. **The literal "N/A" fallback text is a rough edge on a shareable, social-facing artifact** — architecturally resolved (that's genuinely what renders on a failed fetch), but worth a copy pass at some point given this card can be shared to Instagram/WhatsApp exactly as shown; not blocking, just flagged as a UX-quality note since a bare "N/A" reads as broken rather than "unlucky."
9. **(Revision 2)** Actions-row button size (§R2.2) and Share's arrow tilt (§R2.3) are new items added by the founder's UI-only feedback pass — see those sections for exact numbers/decisions.
10. **(Revision 2)** Name-span colors (§R2.4) were re-evaluated using the *actual post-alpha-blend* contrast, not the raw token-vs-background contrast — this surfaced two previously-unflagged legibility weak spots (Survived ≈2.7:1, Eternal ≈3.5:1 against the gradient's darker stop) that the new tokens fix along with the "more catchy" ask.
11. **(Revision 3)** The "empty gap"/"looks like a screenshot, not a card" complaint (§Revision 3) turned out to be structural, not proportional — `Expanded(child: Center(...))` centers short content in whatever leftover space exists, regardless of box size. Fixed via a further ratio step (3:4 → 4:5, §R3.1) **plus** switching the story block's alignment from `Center` to `Alignment.topCenter` with a new fixed 12dp lead-in gap (§R3.2), so leftover space pools in one place (before the footer) instead of splitting into two dead zones. The worst-case long-content `FittedBox` engagement grows from ~1% to ~23% as an accepted tradeoff (§R3.4) — crash/overflow safety is unaffected either way.

---

## 11. Explicitly unchanged / out of scope for this doc

The sharing mechanism itself (native OS sheet, `CardRenderer`/`ShareService`), the ad-interstitial cadence and "Again" flow, Home/Settings/Notifications, and the Play Loop hand-off (`pushReplacement` to `OutcomeCardScreen(summary:)`) are all untouched by this redesign — see `remaining-screens-v1.md` and `play-loop-v1.md` for those, still current. This doc's scope is strictly the outcome card's own visual redesign, plus (as of Revision 2) the four founder UI-only follow-ups, plus (as of Revision 3) the shape/alignment follow-up above. Story-content/config/remote-fetch/dedup logic is explicitly out of scope for Revisions 2 and 3 — that's a separate future pass per the founder's own sequencing.
