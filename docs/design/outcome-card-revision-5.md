# Stay Alive — Outcome Card, Revision 5: 6/7 → 3/4

**Scope:** a single-parameter follow-up to `outcome-card-revision-4.md`, after that revision's root-cause layout fix shipped and the founder saw the *actually-correct* 6:7 card on-device for the first time. Everything else in Revision 4 (the floor-rule element, `CardFooter`'s 8dp gaps, the width-bounded story text) is unchanged.

**Trigger, verbatim (founder, 2026-07-30):** *"now the card is looking too small maybe we can increase the size a bit so that a story of 3 4 lines can be adjusted."*

**Why this is a genuinely new decision, not reverting a mistake:** Revision 4's fit-check math for 6/7 was correct *given the assumption that Revision 3's `AspectRatio` had ever bound its height* — but it hadn't (the real bug Revision 4 also fixed). Once the shell's height genuinely started tracking its width via the ratio for the first time, 6/7 turned out to read as shorter than intended for a 3-4 line story. This is the first time any ratio decision this session has been checked against a shell that actually obeys its own `AspectRatio` — every number before this one was chosen against a box that was secretly still ~9:16.

## R5.1 New ratio: 3/4 (0.75), not 6/7 (≈0.857)

**`AspectRatio(3/4)`** — at `k=1`: **250 × 333.33dp**, up from 250×291.67dp at 6/7.

Re-running Revision 4's own fit-check methodology, fixed overhead unchanged at k=1 (**≈192dp**: 48dp padding + ≈32dp top row + 12dp lead-in gap + ≈100dp `CardFooter`):

- Available for headline+story+floor region at 3/4: **≈141.33dp** (up from 6/7's ≈99.7dp).
- **1-line headline + 4-line story** (≈132.64dp needed: 30.24 headline + 12 gap + 78.4 story (4 × ~19.6dp lines) + 10 gap + 2 floor rule): fits with **≈8.7dp to spare** — no `FittedBox` shrink at all, i.e. genuinely full-size text. This is the founder's explicit ask (3-4 line story) and it's now met without any safety-net engagement.
- **2-line headline + 3-line story** (≈143.28dp needed): deficit ≈1.95dp → `FittedBox` engages at ≈99% — imperceptible.
- **2-line headline + 4-line story** (the double-worst-case, ≈162.88dp needed): deficit ≈21.55dp → scale ≈87% — a real but modest shrink, only for the rare case where both the headline AND the story are simultaneously at their longest.

**Why 3/4 and not something between 6/7 and 3/4 (e.g. 7/9 ≈ 0.778):** 3/4 is the smallest *clean* fraction that clears the founder's stated target (comfortable 3-4 line story) with headroom rather than landing exactly on the edge — and it's a familiar number already used once before in this app's own revision history (Revision 2), so there's precedent for how it reads on real devices, even though — per R5's own framing above — that precedent was never actually validated against a working `AspectRatio` until now.

## R5.2 What this does NOT touch

Same convention as Revision 4 §R4.7: the floor-rule element, `CardFooter`'s gaps, the story block's width-bounded wrapping, per-tier colors/chips/icons, the top row, action-row buttons, entrance animation, and the sharing/ad/screen-chrome layers are all unchanged. `OutcomeCardShell.referenceWidth` stays 250dp (ratio-independent, per R2.1/R3.1/R4.1's repeated note).

## R5.3 Call-out for flutter-developer

Exactly one literal changes: `outcome_card_shell.dart`'s `aspectRatio: 6 / 7` → `aspectRatio: 3 / 4`. Update stale doc comments/test assertions that pin the old 6/7 number (including the real measured on-device box size from Revision 4's own sizing test, which will now measure differently) — re-measure, don't hand-compute, per the standing lesson from Revision 4's own loader-clearance note.
