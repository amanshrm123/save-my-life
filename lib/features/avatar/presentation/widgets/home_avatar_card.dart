import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/note_chip.dart';
import '../../domain/avatar_catalog.dart';
import '../../domain/avatar_constants.dart';
import 'avatar_figure.dart';

/// The Home dashboard's avatar card (design `home-avatars-v1.md` §2): sits
/// in the same flexible slot the old `Spacer()` occupied. Matches
/// `StatTile`'s sticker weight (2.5dp ink / 4dp shadow / 14dp radius), not
/// `StickerButton`'s heavier treatment — this is a secondary/navigational
/// tap, not a primary action (§2.2).
///
/// No fixed height anywhere in this widget's own layout: the card box is an
/// `AspectRatio`, and the figure inside scales via `FittedBox` — so on a
/// short screen the `Expanded` slot above simply gives this less room and
/// the `AspectRatio` box shrinks to fit (never overflows).
class HomeAvatarCard extends StatelessWidget {
  const HomeAvatarCard({
    super.key,
    required this.avatarId,
    required this.bestLifePercent,
    required this.onTap,
    this.shouldAnimateFill = true,
  });

  /// The committed `selectedAvatarProvider` value; `-1` means never picked.
  final int avatarId;
  final int bestLifePercent;
  final VoidCallback onTap;

  /// Threaded straight through to `AvatarFigure.shouldAnimate` — Home passes
  /// its own `RouteAware`-derived visibility flag here so the fill only
  /// animates while this card is genuinely on screen (see `AvatarFigure`'s
  /// doc comment for why).
  final bool shouldAnimateFill;

  static const TextStyle _microlabelStyle = TextStyle(
    fontFamily: 'Fredoka',
    fontSize: 9,
    fontWeight: FontWeight.w700,
    color: AppColors.mute,
    letterSpacing: 0.04 * 9,
  );

  // A fixed reference box for the microlabel+figure composition, scaled as a
  // whole by the wrapping `FittedBox` below (§2.1's "compute once, scale
  // everything" discipline) -- this is what makes the composition genuinely
  // overflow-proof: laying the `Text` + figure out at a fixed, known size
  // means the inner `Column` never depends on the ambient (possibly
  // vanishingly small, on the shortest devices) constraints to avoid a
  // `RenderFlex` overflow, and the outer `FittedBox` guarantees it always
  // fits the actual available space, growing or shrinking to match exactly
  // (`BoxFit.contain`, not `scaleDown` -- the figure must still fill the
  // card's remaining space in the common case, not stay pinned small).
  static const double _kContentWidth = 120;
  static const double _kContentHeight = _kContentWidth / kAvatarCardAspectRatio;

  @override
  Widget build(BuildContext context) {
    final spec = AvatarCatalog.byId(avatarId);

    // Zero-state (design §3.4): a fresh install always shows a full green
    // figure + "READY", never a near-empty/red first impression.
    final isZeroState = bestLifePercent == 0;
    final fillPercent = isZeroState ? 100 : bestLifePercent;
    final microlabel = isZeroState ? 'READY' : 'BEST LIFE';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 168),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (avatarId == -1) ...[
            // `FittedBox(scaleDown)` + `NoteChip`'s own `shrinkWrap` (so it
            // reads as a "pill" per design §2.6, not a full-width banner
            // stretched to this card's 168dp `ConstrainedBox` regardless of
            // how much narrower the `AspectRatio` box below has actually
            // shrunk) together make this hint participate in the same
            // overflow-proof sizing the figure composition already has:
            // it visibly shrinks instead of overflowing the outer `Column`
            // at pathologically small available height.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: NoteChip.hint(text: '👆 Pick your look'),
            ),
            const SizedBox(height: 6),
          ],
          // `Flexible` (not a bare `AspectRatio`) is load-bearing here: a
          // `Column(mainAxisSize: MainAxisSize.min)` gives its non-flex
          // children an *unbounded* main-axis constraint, so a bare
          // `AspectRatio` would always size itself off the 168dp width alone
          // (~205dp tall) regardless of how little vertical room the outer
          // `Expanded` slot actually has -- overflowing on short screens
          // exactly the way design §2.1 warns against. Wrapping in
          // `Flexible` lets the Column's real (bounded) incoming height
          // constraint reach the `AspectRatio`, so it shrinks instead.
          Flexible(
            child: AspectRatio(
              aspectRatio: kAvatarCardAspectRatio,
              child: Semantics(
                button: true,
                label: 'Choose your avatar',
                child: GestureDetector(
                  onTap: onTap,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.ink, width: 2.5),
                      boxShadow: const [
                        BoxShadow(color: AppColors.ink, offset: Offset(0, 4), blurRadius: 0),
                      ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: _kContentWidth,
                        height: _kContentHeight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(microlabel, style: _microlabelStyle),
                            Expanded(
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: AvatarFigure(
                                  spec: spec,
                                  fillPercent: fillPercent,
                                  shouldAnimate: shouldAnimateFill,
                                ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
