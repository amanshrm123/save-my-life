import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/feedback/feedback.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/note_chip.dart';
import '../../../onboarding/state/onboarding_providers.dart';
import '../../domain/avatar_catalog.dart';
import '../../domain/avatar_constants.dart';
import 'avatar_figure.dart';

/// The Home dashboard's avatar card (design `home-avatars-v1.md` §2, name +
/// press effect per `home-avatar-button-v2.md`): sits in the same flexible
/// slot the old `Spacer()` occupied. Matches `StatTile`'s sticker weight
/// (2.5dp ink / 4dp shadow / 14dp radius), not `StickerButton`'s heavier
/// treatment — this is a secondary/navigational tap, not a primary action
/// (§2.2).
///
/// No fixed height anywhere in this widget's own layout: the card box is an
/// `AspectRatio`, and the figure inside scales via `FittedBox` — so on a
/// short screen the `Expanded` slot above simply gives this less room and
/// the `AspectRatio` box shrinks to fit (never overflows).
///
/// `ConsumerStatefulWidget` (v2 §1/§2): it watches `playerProfileProvider`
/// to render the player's name below the figure, and owns a small
/// `AnimationController` (mirroring `StickerButton`'s press math, duplicated
/// locally rather than retrofitting `StickerButton` itself — see v2 §2) for
/// the card's own tap-down/tap-up shadow-offset feedback.
class HomeAvatarCard extends ConsumerStatefulWidget {
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

  /// The player's name "name plate" line (v2 §3) — `AppColors.ink` on the
  /// card's own `AppColors.paper` fill measures ~14.4:1 contrast (comfortably
  /// clears WCAG AAA), so no text-shadow is needed or used, unlike
  /// `StickerButton`'s white-on-saturated-fill labels.
  static const TextStyle _nameStyle = TextStyle(
    fontFamily: 'Fredoka',
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.1,
    color: AppColors.ink,
  );

  // A fixed reference box for the microlabel+figure+name composition, scaled
  // as a whole by the wrapping `FittedBox` below (§2.1's "compute once, scale
  // everything" discipline) -- this is what makes the composition genuinely
  // overflow-proof: laying the `Text` + figure + name out at a fixed, known
  // size means the inner `Column` never depends on the ambient (possibly
  // vanishingly small, on the shortest devices) constraints to avoid a
  // `RenderFlex` overflow, and the outer `FittedBox` guarantees it always
  // fits the actual available space, growing or shrinking to match exactly
  // (`BoxFit.contain`, not `scaleDown` -- the figure must still fill the
  // card's remaining space in the common case, not stay pinned small).
  static const double _kContentWidth = 120;
  static const double _kContentHeight = _kContentWidth / kAvatarCardAspectRatio;

  @override
  ConsumerState<HomeAvatarCard> createState() => _HomeAvatarCardState();
}

class _HomeAvatarCardState extends ConsumerState<HomeAvatarCard>
    with SingleTickerProviderStateMixin {
  // Mirrors `StickerButton`'s exact press math (v2 §2), scaled to this
  // card's existing, lighter, already-shipped static shadow weight (4dp
  // rest, unchanged from today) rather than `StickerButton`'s own
  // (5dp/2dp) CTA-weight defaults.
  static const double _restShadowOffset = 4;
  static const double _pressedShadowOffset = 1.5;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, value: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    AppFeedback.lightImpactIfEnabled();
    _controller.animateTo(
      1,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
    );
  }

  void _onTapUp(TapUpDetails details) {
    _controller.animateTo(
      0,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOutBack,
    );
  }

  void _onTapCancel() {
    _controller.animateTo(
      0,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOutBack,
    );
  }

  @override
  Widget build(BuildContext context) {
    final spec = AvatarCatalog.byId(widget.avatarId);

    // Zero-state (design §3.4): a fresh install always shows a full green
    // figure + "READY", never a near-empty/red first impression.
    final isZeroState = widget.bestLifePercent == 0;
    final fillPercent = isZeroState ? 100 : widget.bestLifePercent;
    final microlabel = isZeroState ? 'READY' : 'BEST LIFE';

    // Same fallback convention already used at the other Home-tier read
    // site, `settings_screen.dart` (v2 §1): no new provider, no new fetch --
    // `playerProfileProvider` is already a resident `AsyncNotifier`.
    final profileAsync = ref.watch(playerProfileProvider);
    final displayName = profileAsync.maybeWhen(
      data: (p) => p.isAnonymous ? 'Anonymous' : p.name,
      orElse: () => '…',
    );

    // The figure/name/microlabel subtree never depends on the press
    // animation's value — passed as `AnimatedBuilder.child` (not rebuilt
    // inside `builder`) so a press only re-lays-out the `Transform.translate`
    // + `Container` decoration each frame, not the whole `FittedBox`/
    // `AvatarFigure`/`Text` composition underneath it.
    final cardContent = AnimatedBuilder(
      animation: _controller,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: HomeAvatarCard._kContentWidth,
          height: HomeAvatarCard._kContentHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(microlabel, style: HomeAvatarCard._microlabelStyle),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: AvatarFigure(
                      spec: spec,
                      fillPercent: fillPercent,
                      shouldAnimate: widget.shouldAnimateFill,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: Text(
                  displayName,
                  style: HomeAvatarCard._nameStyle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      builder: (context, child) {
        final shadowOffset = ui.lerpDouble(
          _restShadowOffset,
          _pressedShadowOffset,
          _controller.value,
        )!;
        final translateY = _restShadowOffset - shadowOffset;
        return Transform.translate(
          offset: Offset(0, translateY),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.ink, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink,
                  offset: Offset(0, shadowOffset),
                  blurRadius: 0,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 168),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.avatarId == -1) ...[
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
                  onTapDown: _onTapDown,
                  onTapUp: _onTapUp,
                  onTapCancel: _onTapCancel,
                  onTap: widget.onTap,
                  behavior: HitTestBehavior.opaque,
                  child: cardContent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
