# Home Avatar Button — v2 (name + press effect)

Status: proposed, implementation-ready
Owner: game-ux-designer
Touches: `lib/features/avatar/presentation/widgets/home_avatar_card.dart` only
Does NOT touch: `avatar_picker_screen.dart`, `avatar_figure.dart`, `avatar_catalog.dart`,
`avatar_providers.dart`, or Home's navigation (`_goToAvatarPicker` still pushes
`AppRoutes.avatarPicker` — unchanged).

## 0. Why this is a different proposal from the reverted one

Earlier this session a round that (a) swapped the "BEST LIFE" microlabel for
the player's name **and** (b) replaced the dedicated picker screen with
inline tap-to-cycle selection was fully reverted ("no it is not looking good
revert the changes back"). This spec deliberately differs from that attempt
in every load-bearing way:

| Reverted attempt | This proposal |
|---|---|
| Name **replaced** the "BEST LIFE" microlabel, in its existing top-left, 9sp, muted-gray slot | "BEST LIFE"/"READY" microlabel is **left exactly as-is**; the name is a **new, separate** element in a different position and different type treatment |
| Tap behavior changed to inline cycling (no picker screen) | Tap behavior is **completely unchanged** — still `Navigator.pushNamed(AppRoutes.avatarPicker)` |
| No press-down feedback was part of that round | This round's actual ask is a real press effect — new, additive, well-precedented (reuses `StickerButton`'s math) |
| Card chrome (fill/border/radius/shadow) implicitly in play alongside the other two changes | Card chrome (paper fill, 2.5dp ink border, 14dp radius, 4dp shadow) is **untouched** — only content (+name) and interaction (+press animation) change |

Net effect: this is additive and interaction-only, not a re-skin of the same
slot that already failed to land. If it's rejected again, at least it fails
on genuinely new information (the centered name treatment or the press
effect itself), not a repeat of the same mistake.

## 1. Where the name renders

**Decision: below the avatar figure, as a new third line inside the card,
horizontally centered. It does not replace "BEST LIFE"/"READY", and it does
not overlay the figure.**

Rationale:
- The card's fill is always `AppColors.paper` regardless of life%/avatar —
  only the small body-vessel *inside* the figure carries the dynamic
  green/gold/red life-meter fill (see `AvatarFigure`/`avatarFillColorForPercent`).
  Overlaying text on the figure itself would mean its background color changes
  per-run (survives band changes) — a contrast problem that would have to be
  re-solved per band, and would fight the figure's own silhouette/stroke.
  Putting the name in the always-paper zone below the figure sidesteps that
  entirely: one fixed background, one fixed contrast answer (§3).
- "BEST LIFE"/"READY" is a *meta caption* about the stat, not the player's
  identity — different role than the name. Keeping it in its shipped top-left
  slot and adding the name as a distinct centered line below the figure reads
  as a small "trading card" composition (meta caption top-left, portrait
  center, name plate bottom-center) rather than fighting over one slot. This
  is also why it's fine for the two labels to use different alignment/weight
  — they're different semantic roles, not inconsistent styling of the same one.

### Layout (reference box, `_kContentWidth = 120`, `_kContentHeight ≈ 146.3`,
unchanged from `HomeAvatarCard` today — scaled as a whole by the existing
outer `FittedBox`, per that widget's existing "compute once, scale
everything" discipline):

```
┌────────────────────────────┐  <- Container: paper fill, ink border 2.5,
│ BEST LIFE                  │     radius 14, shadow (animated, §2)
│                             │
│         [avatar figure]     │  <- unchanged: Expanded > Center > FittedBox
│                             │     > AvatarFigure
│                             │
│         Aman                │  <- NEW: centered name line
└────────────────────────────┘
```

Column structure inside the existing `SizedBox(width: 120, height: 146.3)`
(replacing its current 2-child `Column` with 3 children):

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start, // unchanged
  children: [
    Text(microlabel, style: _microlabelStyle),          // unchanged
    Expanded(
      child: Center(
        child: FittedBox(fit: BoxFit.contain, child: AvatarFigure(...)),
      ),
    ),                                                    // unchanged
    const SizedBox(height: 4),                            // NEW
    SizedBox(                                              // NEW
      width: double.infinity,
      child: Text(
        _displayName,
        style: _nameStyle,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ],
)
```

`SizedBox(width: double.infinity, ...)` is required, not decorative: the
`Column`'s `crossAxisAlignment: CrossAxisAlignment.start` gives non-flex
children only as much cross-axis width as they ask for, so a bare `Text`
would hug the left edge; forcing the row to full width lets
`textAlign: TextAlign.center` actually center within the 120dp content box.

Giving the name its own fixed-height line does shrink the `Expanded` figure
slot by a few dp — accepted trade-off, call it out to reviewers so it isn't
read as an accidental regression in figure size.

### States

| State | `_displayName` value | Source |
|---|---|---|
| Named player | the player's name, e.g. `"Aman"` | `playerProfileProvider` `AsyncData` where `!isAnonymous` |
| Anonymous (name never set) | `'Anonymous'` | `playerProfileProvider` `AsyncData` where `isAnonymous` |
| Profile still loading | `'…'` | `playerProfileProvider` `AsyncLoading`/`AsyncError` (`orElse`) |
| Never-picked avatar (`avatarId == -1`) | unaffected — name renders normally; the existing "👆 Pick your look" `NoteChip` still renders above the card, independent of this | n/a |

This is the exact fallback convention already used at the one other Home-tier
read site, `settings_screen.dart`:

```dart
final name = profileAsync.maybeWhen(
  data: (p) => p.isAnonymous ? 'Anonymous' : p.name,
  orElse: () => '…',
);
```

Reuse this verbatim in `HomeAvatarCard` (it will need to become a
`ConsumerWidget`/watch `playerProfileProvider`, same provider `_LastChanceLine`
and Settings already watch — no new provider, no new async work, the value is
already resident in memory once onboarding completes).

Long names: fixed `maxLines: 1` + `TextOverflow.ellipsis` against the 120dp
reference width, exactly like every other fixed-reference-box element in this
widget. No tooltip/marquee — flagged as a later-phase nice-to-have only if
real player names turn out to commonly overflow 120dp at 13sp bold Fredoka
(unlikely; that's roughly 10-12 characters before ellipsis, comfortably
covers common first names).

## 2. The button effect — reuse `StickerButton`'s exact press math, wrap the *whole existing card*, change nothing else

**Decision: wrap the existing `Container` (unchanged fill/border/radius) in
the same tap-down/tap-up shadow-offset animation `StickerButton` already
uses, at the card's own existing (lighter) shadow weight. Do not adopt
`StickerButton` as a component wrapper (it's not designed to host arbitrary
child content on a paper fill) — duplicate its small, well-isolated animation
block locally in `HomeAvatarCard`, mirroring it value-for-value.**

Why "wrap the whole card, change nothing else" is the safe move here: the
history section (§0) shows the previous revert happened when *content* and
*navigation behavior* both changed at once inside this exact slot. A press
effect that only affects how the existing, unchanged box moves/shadows on
touch — with zero change to its fill, border, corner radius, or what tapping
it does — is the smallest possible diff that still satisfies "should look
more like a button." If this specific piece gets rejected, the failure
signal is unambiguous (it's about the animation itself, not tangled up with
three other simultaneous changes).

Why not reuse `StickerButton` itself as a wrapper: `StickerButton` owns its
whole box (`fill`, `labelShadow`, centered single-line label, fixed
`height`) — it was built for the coral/green CTA-button role, not for hosting
an `AspectRatio` figure composition on a paper background. Retrofitting it
to accept an arbitrary child would mean widening a component reused
everywhere in the app (onboarding, Play, picker, Outcome share) just for this
one call site — bigger blast radius than the ask requires. Copying its four
numbers and two `AnimationController.animateTo` calls into `HomeAvatarCard`
gets identical *feel* with a fraction of the risk.

### Exact values (mirroring `StickerButton`, scaled to this card's existing lighter shadow weight)

| Parameter | `StickerButton` default | `HomeAvatarCard` (this spec) |
|---|---|---|
| Rest shadow offset | 5dp | **4dp** (unchanged from today's static value) |
| Pressed shadow offset | 2dp | **1.5dp** (same ~0.4× ratio, scaled to the lighter 4dp weight) |
| Tap-down animation | 90ms, `Curves.easeOut` | same: 90ms, `Curves.easeOut` |
| Tap-up/cancel animation | 130ms, `Curves.easeOutBack` | same: 130ms, `Curves.easeOutBack` |
| Translate on press | `Offset(0, rest - current)` | same formula |
| Haptic on tap-down | `AppFeedback.lightImpactIfEnabled()` | same call |
| Border/radius/fill | n/a (CTA colors) | **unchanged**: `AppColors.paper` fill, `AppColors.ink` 2.5dp border, 14dp radius |

Implementation shape (converts `HomeAvatarCard` from `StatelessWidget` to
`StatefulWidget` — the only structural code-shape change this spec requires):

```dart
class _HomeAvatarCardState extends State<HomeAvatarCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, value: 0);

  static const double _restShadowOffset = 4;
  static const double _pressedShadowOffset = 1.5;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    AppFeedback.lightImpactIfEnabled();
    _controller.animateTo(1, duration: const Duration(milliseconds: 90), curve: Curves.easeOut);
  }

  void _onTapUp(TapUpDetails _) =>
      _controller.animateTo(0, duration: const Duration(milliseconds: 130), curve: Curves.easeOutBack);

  void _onTapCancel() =>
      _controller.animateTo(0, duration: const Duration(milliseconds: 130), curve: Curves.easeOutBack);

  // build(): AnimatedBuilder around the *existing* Container, lerping
  // BoxShadow's Offset.dy between _restShadowOffset and _pressedShadowOffset,
  // and Transform.translate(Offset(0, restShadowOffset - currentOffset))
  // around it — identical math to StickerButton's build(), just against
  // this card's existing decoration values instead of `widget.fill`/
  // `widget.labelShadow`.
}
```

No bottom-padding reservation change is needed (unlike `StickerButton`'s own
`Padding(bottom: restShadowOffset)`): the pressed offset (1.5dp) is strictly
*less than* the already-shipped static rest offset (4dp), so the animated
shadow never paints outside the footprint the card already has today at
rest. If a future change ever made the rest offset larger than 4dp, revisit
this.

`GestureDetector.onTap` stays exactly as it is today (`onTap: widget.onTap`,
`behavior: HitTestBehavior.opaque`) — only `onTapDown`/`onTapUp`/`onTapCancel`
are newly added, same as `StickerButton`.

## 3. Name text color / contrast

**Decision: `AppColors.ink` (`#1F2A2E`), matched against the card's own
`AppColors.paper` (`#FFFDF7`) fill — the same rigor as the Outcome card's
`surviveNameSpan`/`eternalNameSpan` tokens, computed explicitly rather than
picked by eye.**

Computed per WCAG 2.1 relative-luminance formula (`sRGB` → linear, `L =
0.2126R + 0.7152G + 0.0722B`, contrast `= (L_light + 0.05) / (L_dark + 0.05)`):

- `paper` (`#FFFDF7`) relative luminance ≈ **0.978**
- `ink` (`#1F2A2E`) relative luminance ≈ **0.0215**
- Contrast ratio ≈ **14.4 : 1** — comfortably clears WCAG AAA (7:1) for
  normal-size text, with wide margin.

For reference, the existing "BEST LIFE" microlabel's color (`AppColors.mute`,
`#7B8A86`) on the same `paper` background measures only ≈ **3.5:1** — legible
as a *small, secondary* caption (AA-large's 3:1 floor), but not a color this
spec should reuse for the name, which is meant to read as the card's primary
identity label. `ink` is both the higher-contrast choice and the one already
used everywhere else in the app for primary text-on-paper (headline, input
text) — no new color token needed.

No text-shadow: `StickerButton`'s white-on-saturated-fill labels need a
text-shadow for pop/legibility; ink-on-paper at 14.4:1 doesn't, and no other
ink-on-paper text in the app (streak card, microlabel, headline styles) uses
one. Adding one here would be a gratuitous, inconsistent flourish — flagged
explicitly given the "didn't look good" history; don't add it.

Proposed style token (new, local to `HomeAvatarCard`, not promoted to
`AppTypography` unless another call site needs it):

```dart
static const TextStyle _nameStyle = TextStyle(
  fontFamily: 'Fredoka',
  fontSize: 13,
  fontWeight: FontWeight.w700,
  height: 1.1,
  color: AppColors.ink,
);
```

13sp/bold sits between the 9sp microlabel and the figure — legible as the
card's "name plate" without competing with the figure for visual weight.

## 4. Explicitly out of scope for this change

- Inline avatar cycling — not proposed, not being reconsidered; tapping the
  card still opens `avatar_picker_screen.dart`.
- Any change to `avatar_picker_screen.dart`, `AvatarTile`, or
  `AvatarGenderToggle`.
- Any change to `AvatarFigure`/`avatar_catalog.dart`/life-meter fill logic.
- Promoting `_nameStyle` to `AppTypography` (do it later only if a second
  call site needs the exact same style).
- Truncation UX beyond single-line ellipsis (tooltip/marquee) — later-phase
  nice-to-have only if real names are observed overflowing.

## 5. Test coverage guidance (scoped — per this repo's workflow rule 4/5)

Add/extend tests only for what changes in `HomeAvatarCard`:
- Widget test: named profile renders the name centered below the figure.
- Widget test: anonymous profile renders `'Anonymous'`.
- Widget test: loading/error profile state renders `'…'`.
- Widget test: long name truncates with ellipsis, doesn't overflow/throw.
- Widget test (`pumpAndSettle`/`WidgetTester.press`): `tapDown` drives the
  shadow offset from 4dp toward 1.5dp within the animation window; `tapUp`/
  `tapCancel` animates it back to 4dp. (Mirror the existing pattern any
  `StickerButton` press-effect test in this codebase already uses, if one
  exists — same assertions, different widget under test.)
- Confirm `_controller.dispose()` is covered by existing widget-disposal
  teardown (no explicit test needed beyond normal `tester.pumpWidget`
  teardown, but do not skip calling `dispose()` in the implementation).
- Do NOT re-run the full avatar picker flow test
  (`avatar_picker_flow_test.dart`) or the full Home screen test suite for
  this change — the picker and Home's navigation are unchanged; scope to
  `HomeAvatarCard`'s own test file (new, if it doesn't exist yet) plus
  whatever existing Home smoke test already renders `HomeAvatarCard` and
  would need its golden/fallback-text expectations updated for the new name
  line.

## 6. Memory-safety note (per this app's in-memory-first constraint)

- New state: one `AnimationController` per `HomeAvatarCard` instance,
  identical lifecycle to every other sticker-style animated widget in this
  app (`StickerButton`) — created in `initState`, disposed in `dispose`. Home
  only ever mounts one `HomeAvatarCard` at a time, so this is a single
  bounded controller, not a per-item list allocation.
- No new provider, no new fetch, no new cache: `playerProfileProvider` is
  already a resident `AsyncNotifier` read elsewhere (Settings,
  `_LastChanceLine`); watching it here adds a listener, not new data.
- No unbounded growth: name string is bounded by the existing profile-name
  input validation (already length-limited at entry in onboarding/settings),
  and this widget only ever renders the current value, never accumulates a
  history.
