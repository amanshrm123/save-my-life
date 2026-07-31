# Stay Alive — Outcome Card, Revision 4: Shorter Shell + "Not-Blank" Content Floor

**Scope:** a further revision of `docs/design/outcome-story-cards-v1.md` §Revision 3 (`R3.1`/`R3.2`), triggered by fresh founder feedback after Revision 3 shipped. **This doc documents only what changes.** Everything else in `outcome-story-cards-v1.md` — chip/tier colors, per-tier palettes, `CardFooter`'s structure, the loader's internal composition, action-button sizing/arrow tilt, entrance animation — is unchanged and should still be read there. Spun out as its own file rather than embedded as a third revision block in the v1 doc, matching this project's own precedent for a revision big enough to warrant it (`play-loop-v1.md` → `play-loop-v2.md`; the v1 doc's own Revision 2 header names this exact convention).

**Trigger, verbatim (founder, 2026-07-30):** *"Outcome card length is still long if we can reduce it a bit more but other things around should be fixed accordingly so that it should not give too much blank space feel."* Confirmed on-device: for short story content (e.g. Death's one-line "A panicked in the final band." beat), roughly **half** the card's visible height between the story block and `CardFooter` is empty.

**Read first:** `lib/features/outcome/presentation/widgets/outcome_card_shell.dart`, `outcome_card.dart`, `outcome_card_loading.dart`, `card_footer.dart`, and `docs/design/outcome-story-cards-v1.md` §Revision 3 in full (R3.1–R3.4) — this doc assumes that context and doesn't re-derive it.

**Why Revision 3's fix wasn't enough:** R3.2 correctly diagnosed the *structural* half of the problem (centered leftover space splits into two dead zones) and fixed it by top-anchoring the story block so leftover space pools in one place, below the story, above the footer. But R3.2 never claimed to reduce the *amount* of leftover space for short content — it only relocated it. The founder's fresh complaint is about that relocated pool still being too large, on top of a separate, softer ask to shrink the shell again. Fixing this needs two independent levers, same pairing pattern as Revision 3 itself: **(a)** a real ratio reduction (less box to be empty in), and **(b)** something that consumes part of that pooled leftover space with actual designed content, not just smaller padding (padding is still blank space — it just gets a different name).

Design spec, not code — no Dart. Flutter mechanisms named below describe the intended structure precisely enough to implement directly, since the founder wants this shippable without another round-trip.

---

## R4.1 Card shape — 6/7 (≈0.857), not 4/5

**Stated unambiguously: `width : height = 6 : 7`.** At `k = 1` (a 250dp-wide box): **250 × 291.67dp** — down from 250×312.5dp at 4:5 (Revision 3). `OutcomeCardShell.referenceWidth` stays 250dp, unchanged (R2.1/R3.1's note that it's independent of aspect ratio still holds).

**Why 6/7, not a bigger or smaller step:**

- **Same magnitude as the last step, not an arbitrary new number.** R2.1→R3.1 (3/4 → 4/5) shortened the box by ≈20.8dp at k=1. 4/5 → 6/7 shortens it by another **≈20.8dp** — literally the same step size, in the same direction, applied again. This is a defensible, explainable increment rather than a fresh guess, and matches the founder's own framing ("reduce it **a bit more**" — a continuation of the same trend, not a big new swing).
- **It stays inside Instagram's own accepted portrait range.** Instagram Feed posts accept any ratio from 1.91:1 (wide) down to 4:5 (0.8, the *most* portrait ratio allowed) up through 1:1 (square) — anything *squarer* than 4:5 (i.e. ratio > 0.8, which is the direction 6/7 ≈ 0.857 moves) still renders edge-to-edge with no auto-crop. R3.1's Instagram argument for landing exactly on 4:5 doesn't force 4:5 as a ceiling — it only rules out going *more portrait* than 4:5, not squarer. 6/7 is safely inside that window.
- **Why not go further (e.g. 9/10 ≈ 0.9, or square 1:1):** re-running R3.1's own fit-check math at 9/10 shows the *common* pooled-content case (1-line headline + 2–3 line story, ≈101dp needed at k=1 — R3.1's own bound) would need ≈82dp available, forcing the `FittedBox` safety net to visibly engage (~81% scale) on the **typical** run, not just the rare worst-case ceiling. That trades today's "occasionally-shrunk outlier" for "usually-shrunk normal card," which is a worse visible-inconsistency problem than the one being fixed. 6/7 keeps the common case's `FittedBox` engagement imperceptible (see fit-check below) while still landing a real, visible shrink. If the founder wants the card shorter still after seeing 6/7 in hand, treat 9/10 as the next available step — not this one.

**Content-fit check at 6/7, including R4.2's content-floor addition below** (fixed overhead now includes the new floor element's footprint):

- Fixed overhead at `k=1`: padding (48dp, unchanged) + top row (≈32dp, unchanged) + R3.2's 12dp lead-in gap (unchanged) + `CardFooter` (≈100dp — see R4.3, down from ≈104dp) = **≈192dp**.
- Available for the headline+story+floor region in the new 291.67dp-tall box: **≈99.7dp** (down from R3.1's ≈116.5dp at 4:5).
- **Short case — the founder's actual flagged scenario** (1-line headline + 1-line story, ≈62dp of text, +12dp for R4.2's floor element = **≈74dp** needed): leftover ≈**25.7dp**, i.e. **≈26% of the region** is genuinely empty — down from **≈47%** today. This is the number that matters most: it roughly halves the felt "blank" fraction for exactly the case the founder flagged, from the actual on-device screenshot.
- **Common case** (1-line headline + 2–3 line story, ≈101dp of text + 12dp floor = ≈113dp needed): deficit ≈13.3dp → `FittedBox` engages at **≈88% scale** — a small, likely-imperceptible-in-practice shrink (headline 27dp→≈24dp, story 14dp→≈12dp at k=1), not the "usually visibly shrunk" outcome a squarer ratio (9/10) would have produced.
- **§10.7's own stated worst-case bound** (~2-line headline + ~4-line story, ≈151dp of text + 12dp floor = ≈163dp needed): scale ≈**61%** — a materially bigger shrink than R3.1's ≈77% at 4:5. **This is a real, deliberate widening of an already-accepted tradeoff (R3.4), not a new one** — `FittedBox(scaleDown)` still has no failure mode; it cannot overflow or crash regardless of how tight this gets. But it does mean §10.7's "hard ceiling" framing needs re-tightening: flag explicitly to whoever authors/extends the 66 pooled entries that **~2-line headline + ~3-line story should now be treated as the practical ceiling**, not ~4-line story — content sitting at the old ceiling will render noticeably smaller than the reference composition. If a real content audit later shows this is too aggressive, the fallback levers, cheapest-first, are: (1) drop R4.2's floor element specifically for content already near the ceiling (see R4.2's note on this), (2) soften the ratio back toward 5/6, (3) trim `CardFooter` further than R4.3 already does.

---

## R4.2 The actual "not blank" fix: a fixed content-floor rule under the story block, inside the same scale-safety unit

**This is the load-bearing change for the founder's "shouldn't feel blank" complaint — the ratio step alone (R4.1) only gets the short case from ~47% to ~35% blank; it's this addition that gets it the rest of the way to ~26%.**

Padding/margin cannot fix "feels blank," because padding *is* blank space with a different name — shrinking it just relocates the emptiness, exactly as R3.2 already demonstrated. The only way to genuinely reduce the *feeling* of blankness without new data plumbing (out of scope — see R4.4) is to put a small, deliberate piece of always-rendered content where the empty pool currently sits, so the eye has something to land on immediately below the story text instead of a void trailing off into the footer.

**Add one new widget, `_StoryFloorRule`, directly inside the existing `FittedBox` — as a sibling of `_StoryBlock`, not a replacement for it:**

```dart
Expanded(
  child: Align(
    alignment: Alignment.topCenter,     // unchanged from R3.2
    child: FittedBox(
      fit: BoxFit.scaleDown,            // unchanged from R3.2 — still the safety net
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,   // matches _StoryBlock's own alignment
        children: [
          _StoryBlock(playerName: playerName, content: content, palette: palette, k: k),
          SizedBox(height: 10 * k),      // NEW — see "why 10, not 12" below
          Container(                     // NEW — _StoryFloorRule
            width: 36 * k,
            height: 2 * k,
            decoration: BoxDecoration(
              color: palette.baseText.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(1 * k),
            ),
          ),
        ],
      ),
    ),
  ),
),
```

**Why this specific mechanism, not the alternatives that were considered and rejected:**

- **Why inside the same `FittedBox`, not appended after `Expanded` as a new sibling in the outer `Column`:** anything placed *after* `Expanded` in the outer `Column` gets pushed flush against `CardFooter`, because `Expanded` always consumes 100% of whatever space is left — the visible gap would just relocate to sit *above* the new element (between story text and rule), recreating the exact "one big undifferentiated void trailing off the text" problem R3.2 already fixed once. Putting the rule *inside* the `FittedBox`, as part of the same top-anchored, min-sized unit as `_StoryBlock`, means it sits directly under the story with a small fixed gap regardless of story length — and because it's still inside `Expanded`+`FittedBox`, the crash-safety guarantee (R3.4: `FittedBox(scaleDown)` cannot overflow) is fully preserved; nothing about this addition reopens overflow risk.
- **Why a plain decorative rule and not a real stat/number:** the obvious "better" content floor would be something like a run stat (survival time, tap count) that always renders regardless of story length, giving the eye real information instead of a design flourish. That's a **legitimate future idea, explicitly flagged as out of scope for this pass** — see R4.4: `OutcomeStoryContent` (the model `OutcomeCard` actually receives) has no numeric stat fields today; `RunState`'s stats (`lifePercent`, `peakLifePercent`, etc.) are already baked into headline copy as text by `StoryRenderer`, not exposed separately to the widget layer. Plumbing a new field through would be a real data/architecture change, not a UI-only fix, and this pass (like R2 and R3 before it) is explicitly scoped UI-only. A decorative rule needs zero new data and is fully reversible if a stat-line lands later.
- **Why 10dp gap, not R3.2's 12dp:** deliberately *not* reusing 12dp, to keep the rule visually distinct from the headline→story rhythm (which is genuinely 12dp throughout `_StoryBlock`) — 10dp instead matches `CardFooter`'s own existing inter-element rhythm (tagline→wordmark→badges, each 10dp — see R4.3), so the rule reads as "the start of the footer's visual language creeping up into the middle region" rather than an arbitrary fourth spacing value. One consistent footer-adjacent rhythm (10dp), one consistent story-internal rhythm (12dp).
- **36dp width / 2dp height / 0.15 alpha:** small and quiet on purpose — this is meant to read as an intentional design accent (the kind of thin rule a poster/trading-card layout uses to separate sections), not a UI element demanding attention or looking like an error/divider bug. `palette.baseText` at 0.15 alpha is deliberately *lower* than the tagline's existing 0.75 or the subline's 0.55–0.6 (§5 of the v1 doc) — this element should be the quietest thing on the card, felt more than seen.
- **Left-aligned (`crossAxisAlignment.start`), not centered:** matches `_StoryBlock`'s own left-ragged text alignment, reading as "part of the story block's own signature," rather than centered like `CardFooter`'s elements — deliberately different from the footer's centering so the two visual languages (story block vs. footer) stay distinguishable even though they now share a spacing constant.
- **Always rendered, not conditional on measured leftover space.** A "smarter" version of this fix would only show the rule when there's meaningfully more leftover space than the rule's own footprint, skipping it for already-long content where it'd just add to `FittedBox` shrink pressure for no visual benefit. That requires runtime measurement (`LayoutBuilder`/`TextPainter`) and a size-comparison branch — real added complexity and a new source of bugs for a decorative element. Given the ceiling-case impact is already an accepted, flagged tradeoff (R4.1), ship the simple always-on version first; treat the conditional version as a nice-to-have follow-up only if real content review shows the ceiling-case shrink is actually a problem in practice, not a theoretical one.

---

## R4.3 `CardFooter` — trim the two inter-element gaps 10dp → 8dp

**Why now, when R3.3 explicitly said `CardFooter` was untouched:** R4.1's ratio step and R4.2's floor element both eat into the same limited headroom that the worst-case ceiling content relies on (R4.1's fit-check: ceiling scale drops from R3.1's ≈77% to ≈61%). R3.4 already named "trim `CardFooter`'s own 10dp inter-element gaps" as the cheapest lever to claw back headroom without reopening the empty-gap problem, for exactly this situation. Pulling it now, rather than waiting for a future pass, partially offsets the ceiling-case cost of R4.1+R4.2 combined.

**Change, in `card_footer.dart`:** both `SizedBox(height: 10 * k)` instances (tagline → wordmark, wordmark → store badges) become `SizedBox(height: 8 * k)`. Reclaims ≈4dp of fixed overhead at k=1 (folded into R4.1's fit-check above, which already uses the post-trim ≈192dp/≈100dp footer figure, not R3's ≈196dp/≈104dp). No other change to `CardFooter` — tagline/wordmark/store-badge content, sizes, and colors are all untouched.

---

## R4.4 Tier-specific consideration — confirmed: one uniform fix, no per-tier branching needed

Checked directly against the actual model `OutcomeCard` receives (`OutcomeStoryContent`: `headline`, `storyNamed`, `storyAnonymous`, `icon`, `isFallback` — no numeric/stat fields) and against `_StoryBlock`'s implementation: **headline and story content is pooled and structurally identical across all three tiers** — Death, Survived, and Eternal all draw from the same `_StoryBlock` composition (headline + 12dp gap + story text), differing only in palette/chip/icon, never in how much content renders. There is no tier today where "Survived/Eternal show more stats" in the sense of extra always-present fields on the card — the chip labels differ in *string length* (Eternal's "✨ Eternal · Top 0.3%" is the longest, already handled by the existing `Flexible`+`OutcomeChip` internal `FittedBox` per the code comment in `outcome_card.dart`), not in story-block *height*.

**Conclusion: R4.1–R4.3 apply uniformly to Death, Survived, and Eternal — no tier-specific variant needed.** If a future pass adds a real per-tier stat line (e.g. Eternal showing an actual computed percentile, Survived showing a run count), revisit R4.2's "why not a real stat" note — at that point a stat-based floor would likely be strictly better than the decorative-rule floor shipped here, and the rule could be retired in favor of it. Not needed today.

---

## R4.5 Explicit call-outs for flutter-developer

1. **`outcome_card_shell.dart`:** change exactly one literal — `aspectRatio: 4 / 5` → `aspectRatio: 6 / 7`. Nothing else in this file changes (radius, shadow, `k`-scaling methodology, `TextScaler.noScaling` — all unchanged).
2. **`outcome_card.dart`:** inside the existing `Expanded(child: Align(child: FittedBox(child: ...)))`, change the `FittedBox`'s child from `_StoryBlock(...)` directly to a new `Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [_StoryBlock(...), SizedBox(height: 10*k), <floor rule Container>])` per R4.2's exact snippet. Everything above and below the `Expanded` (top row, 12dp gap, `CardFooter` call) is untouched.
3. **`card_footer.dart`:** both `SizedBox(height: 10 * k)` → `SizedBox(height: 8 * k)`, per R4.3. No other edits.
4. **`outcome_card_loading.dart` — does it need a matching change?** **Yes for the ratio, automatically; no manual edit required, but it needs an explicit re-verification pass.** It calls the same shared `OutcomeCardShell`, so the 6/7 ratio change in step 1 applies to it with zero code changes on the loader's side — R3.3's "loader internal layout untouched" still holds; only the outer box it sits inside gets shorter. **This is exactly the file that had a real overflow regression the last time the ratio changed** (per this task's own brief), so treat the following as a required check, not a formality:
   - Estimated clearance at k=1: padded region ≈291.67 − 48 = **≈243.7dp** available for [pulsing heart + 18dp gap + loading headline + 18dp gap + 3 dots + 18dp gap + subline] (≈165–180dp, depending on how many lines the subline wraps to at 180dp width) **+** the wordmark row (≈21–24dp) ≈ **≈186–204dp total**. That leaves **≈40–58dp of margin** at k=1 by this estimate — comfortably positive, and `FittedBox(scaleDown)` inside the loader (added in a prior pass specifically as this same safety net) means even a miscalculated margin degrades to a shrink, not an overflow.
   - **Do not treat this arithmetic as sufficient sign-off.** The prior regression happened because real rendered font metrics didn't match the doc's estimate — the exact failure mode this estimate is subject to again. Render the loader on an actual device/simulator at the new ratio for all three tiers (subline text wraps differently depending on nothing tier-specific, but check anyway) before calling this done, per the standing verification requirement below.
5. **No changes** to `outcome_chip.dart`, `store_badges.dart`, the top `Row` (chip+icon), `_StoryBlock`'s own internal composition, action-row buttons/arrow tilt, or the entrance animation — all untouched by this revision, same as R3.3's list.

---

## R4.6 Verification checklist — game-ux-designer sign-off (CLAUDE.md rule 6)

Before this is considered done, confirm on a real rendered card (screenshot or on-device, all three tiers, at least one short-content run per tier and one long-content run per tier if the pool allows forcing one):

1. Shell renders at 250×291.67 (or the equivalent at the device's actual card width) — not 4:5's 250×312.5.
2. Short-content runs (the founder's flagged case) visibly show less empty space below the story block than before — should read as a small, intentional gap bounded by the new rule, not a void.
3. The new floor rule is visible but quiet — a thin line, not a distracting bar; confirm it doesn't read as a rendering glitch or an unstyled `Divider`.
4. Common-length story content (2–3 lines) does **not** show an obviously-shrunk headline/story — the ≈88% `FittedBox` engagement estimated in R4.1 should be at most barely perceptible.
5. `OutcomeCardLoading` still clears with no visible clipping/overflow on all three tiers, per R4.5 item 4 — this is the item most likely to surface a real discrepancy from the estimate above.
6. `CardFooter`'s tightened 8dp gaps still read as deliberate spacing, not cramped.
7. Confirm the rule's crash-safety claim holds in practice: force (or find) the longest available pooled headline+story combination and confirm it shrinks but never overflows/clips in the exported `RepaintBoundary` PNG, not just on-screen.

---

## R4.7 What this does NOT touch

Same convention as R3.3: per-tier colors/chips/icons, the top row, `_StoryBlock`'s own internal composition (beyond adding a sibling after it), the loader's internal layout, action-row buttons and arrow tilt, entrance animation, and the sharing/ad/screen-chrome layers around the card are all unchanged by this revision.
