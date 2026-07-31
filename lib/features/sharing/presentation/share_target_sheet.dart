import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/copy/app_copy.dart';
import '../../../core/feedback/feedback.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/toast_pill.dart';
import '../../play_loop/domain/run_state.dart';
import '../domain/share_composition.dart';
import '../domain/share_target.dart';
import '../state/share_providers.dart';
import 'widgets/brand_icons.dart';

/// What the sheet resolved to, for the caller (`OutcomeCardScreen._onShare`)
/// to react to after `showShareTargetSheet` returns (design v1 §7).
/// `null`/absent means "dismissed with no further action needed" — a
/// successful direct-intent launch, a scrim tap, or a drag-to-dismiss all
/// pop with no value, since none of those need the caller to do anything
/// else. Only "More…" needs a signal back out, since it hands off to the
/// existing `ShareService` flow (and that flow's own "✓ Shared" toast) which
/// lives on the outcome screen, not in this sheet.
enum ShareSheetAction { more }

/// Shows the custom 3-tile Instagram/WhatsApp/Facebook picker (architecture
/// v5 §4, design share-target-sheet-v1) that replaces the generic OS share
/// sheet on Android. Never call this on web (`kIsWeb`) — callers gate that
/// themselves (architecture §4.1); this function does not re-check it.
///
/// [installedTargets] must already be resolved BEFORE calling this (§9 — no
/// in-sheet loading state is ever built), and [cardFile] must be the single
/// already-rendered PNG for this Share tap — this function/widget never
/// re-renders the card, it only reuses the one file across however many
/// tiles the player tries (architecture §11's single-render invariant).
Future<ShareSheetAction?> showShareTargetSheet(
  BuildContext context, {
  required File cardFile,
  required RunOutcome outcome,
  required List<ShareTarget> installedTargets,
}) {
  return showModalBottomSheet<ShareSheetAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.ink.withValues(alpha: 0.55),
    elevation: 0,
    builder: (context) => ShareTargetSheet(
      cardFile: cardFile,
      outcome: outcome,
      installedTargets: installedTargets,
    ),
  );
}

class ShareTargetSheet extends ConsumerStatefulWidget {
  const ShareTargetSheet({
    super.key,
    required this.cardFile,
    required this.outcome,
    required this.installedTargets,
  });

  final File cardFile;
  final RunOutcome outcome;
  final List<ShareTarget> installedTargets;

  /// Identifies the actual visible bottom-sheet panel `Container` (as
  /// opposed to this widget's root, which is now a full-screen `Stack` per
  /// the scrim-dismiss fix below) — tests assert bottom-anchoring against
  /// this key's `RenderBox`, not the outer `Stack`'s, since the `Stack`
  /// itself always spans the full screen regardless of where the visible
  /// panel sits. Public (unlike `_ShareTargetSheetState`) so test files in
  /// other libraries can reference it.
  @visibleForTesting
  static const panelKey = Key('shareTargetSheetPanel');

  @override
  ConsumerState<ShareTargetSheet> createState() => _ShareTargetSheetState();
}

class _ShareTargetSheetState extends ConsumerState<ShareTargetSheet> {
  Timer? _toastTimer;
  String? _toastText;

  /// Guards against a rapid double-tap on the same (or another) tile firing
  /// two overlapping native calls while the first is still in flight. Not
  /// the same guard as `OutcomeCardScreen._sharing` (which covers the whole
  /// Share-tap-to-sheet-closed span); this one is purely local to a single
  /// in-flight `shareToStory` call.
  bool _dispatching = false;

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _showToast(String text) {
    _toastTimer?.cancel();
    setState(() => _toastText = text);
    _toastTimer = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      setState(() => _toastText = null);
    });
  }

  String _notInstalledCopyFor(ShareTarget target) {
    switch (target) {
      case ShareTarget.instagramStory:
        return kToastInstagramNotInstalled;
      case ShareTarget.whatsappStatus:
        return kToastWhatsAppNotInstalled;
      case ShareTarget.facebookStory:
        return kToastFacebookNotInstalled;
    }
  }

  String _couldNotOpenCopyFor(ShareTarget target) {
    switch (target) {
      case ShareTarget.instagramStory:
        return kToastCouldNotOpenInstagram;
      case ShareTarget.whatsappStatus:
        return kToastCouldNotOpenWhatsApp;
      case ShareTarget.facebookStory:
        return kToastCouldNotOpenFacebook;
    }
  }

  Future<void> _onTileTap(ShareTarget target) async {
    // Dimmed tiles stay tappable (design §5's load-bearing divergence from
    // `StickerButton.enabled`) — this is a pre-check, never dismisses the
    // sheet, always shows the "isn't installed" copy (design §8.2 table).
    if (isShareTargetDimmed(target, widget.installedTargets)) {
      _showToast(_notInstalledCopyFor(target));
      return;
    }

    if (_dispatching) return;
    _dispatching = true;
    try {
      final gradient = shareGradientFor(widget.outcome);
      final service = ref.read(socialShareServiceProvider);
      final result = await service.shareToStory(
        target: target,
        stickerPath: widget.cardFile.path,
        topColor: gradient.top,
        bottomColor: gradient.bottom,
      );
      if (!mounted) return;
      if (result.isSuccess) {
        // Direct intent launched OK -> dismiss immediately, no toast
        // (design §7/§8 — launching the composer is not the same as a
        // completed post, so the existing "✓ Shared" toast never fires
        // here).
        //
        // Guarded on `isCurrent` (P1 fix): if the player taps a tile then
        // taps the scrim to dismiss before `shareToStory` resolves, this
        // route is already mid-exit by the time we get here — `mounted` is
        // still true (the exit animation hasn't finished disposing this
        // State yet), but this route is no longer the navigator's current
        // one. An unconditional `pop()` in that window would pop whatever
        // route IS current instead (e.g. `OutcomeCardScreen` itself).
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          Navigator.of(context).pop();
        }
      } else {
        // ActivityNotFoundException or a race-condition NOT_INSTALLED from
        // the native side both read the same to the player: keep the sheet
        // open, let them try another tile (design §7).
        _showToast(_couldNotOpenCopyFor(target));
      }
    } finally {
      _dispatching = false;
    }
  }

  void _onMore() {
    Navigator.of(context).pop(ShareSheetAction.more);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // `Align(bottomCenter)` — NOT `Center` — is load-bearing here:
    // `isScrollControlled: true` gives this builder a *loose* (not literally
    // infinite) max-height constraint, so `Align`'s render box actually
    // fills that full loose height rather than shrink-wrapping to its child
    // — a bare `Center` would do the exact same thing, floating the panel
    // mid-screen with dead scrim below it instead of flush against the
    // screen/safe-area bottom (design §2/§3), so `Align` alone doesn't fully
    // solve the "sits at the bottom" requirement either; it's `Alignment
    // .bottomCenter` doing that work, not shrink-wrapping. Horizontal
    // centering still applies via the `ConstrainedBox(maxWidth: 400)` below.
    //
    // That full-height `Align` render box is exactly why an explicit
    // dismiss-on-outside-tap `GestureDetector` (below) is load-bearing too:
    // the framework's own modal-barrier tap-to-dismiss sits *behind* this
    // route's content in z-order, and since this content's own render box
    // now spans the full screen (not just the visible panel), taps on the
    // dead scrim area above the panel land on this widget's subtree first —
    // relying on the barrier alone silently never closes the sheet from
    // there. Placed first in the `Stack` (painted behind, hit-tested after)
    // so the panel's own tiles/link, layered on top, still win.
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            // The framework's own modal barrier already publishes an
            // accessible "dismiss" semantics node for this route; this
            // GestureDetector exists purely to win the hit-test race against
            // this content's own full-screen render box (see the class doc
            // above) and would otherwise publish a second, unlabeled
            // full-screen tappable node on top of it.
            excludeFromSemantics: true,
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              key: ShareTargetSheet.panelKey,
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: Border.all(color: AppColors.ink, width: 2.5),
                // The sheet's only free edge is the top (bottom/sides sit flush
                // against the screen/safe-area) — a solid, zero-blur ink band
                // peeking above via a negative-offset BoxShadow is the same
                // "ink backing plate" language `StickerButton` uses, rotated to
                // this panel's one free edge (design §2). `Container`'s own
                // decoration paints this shadow outside its layout box with no
                // special clipping workaround needed (unlike the RepaintBoundary
                // capture case elsewhere in this app).
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.ink,
                    offset: Offset(0, -5),
                    blurRadius: 0,
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 12),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Share your card',
                        textAlign: TextAlign.center,
                        style: AppTypography.headline,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final target in ShareTarget.values)
                            _ShareTile(
                              target: target,
                              dimmed: isShareTargetDimmed(
                                target,
                                widget.installedTargets,
                              ),
                              onTap: () => _onTileTap(target),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: _onMore,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text('More…', style: AppTypography.ghostLink),
                        ),
                      ),
                    ],
                  ),
                  // Overlay, not a Column child (design §8.2) — the error toast
                  // must not change the panel's own height while it's showing/
                  // hiding, or the tiles above it visibly jump on every toast
                  // appear/dismiss. `Positioned` sits above "More…" without
                  // participating in the Column's intrinsic sizing.
                  if (_toastText != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 40,
                      child: ToastPill(text: _toastText!),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One tappable Instagram/WhatsApp/Facebook tile (design §4). Deliberately
/// its own small widget rather than reusing `StickerButton` directly: a
/// dimmed tile here must stay fully tappable (it shows the "isn't
/// installed" toast on tap), which is the opposite of what
/// `StickerButton.enabled = false` does (nulls its own `onTap`) — see design
/// §5's explicit warning against copying that semantics wholesale. Shares
/// the same press/shadow timing constants as `StickerButton` (90ms
/// tap-down/130ms release, 5->2dp shadow offset) so it still reads as this
/// app's one established tappable-chrome vocabulary.
class _ShareTile extends StatefulWidget {
  const _ShareTile({
    required this.target,
    required this.dimmed,
    required this.onTap,
  });

  final ShareTarget target;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  State<_ShareTile> createState() => _ShareTileState();
}

class _ShareTileState extends State<_ShareTile>
    with SingleTickerProviderStateMixin {
  static const double _restShadowOffset = 5;
  static const double _pressedShadowOffset = 2;

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
    return Opacity(
      opacity: widget.dimmed ? 0.45 : 1,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        // Always live regardless of `dimmed` (design §5) — a dimmed tap
        // still fires `widget.onTap`, which is what shows the "isn't
        // installed" toast rather than silently no-op-ing.
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 80,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final shadowOffset = ui.lerpDouble(
                _restShadowOffset,
                _pressedShadowOffset,
                _controller.value,
              )!;
              final translateY = _restShadowOffset - shadowOffset;
              return Padding(
                padding: const EdgeInsets.only(bottom: _restShadowOffset),
                child: Transform.translate(
                  offset: Offset(0, translateY),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.paper2,
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
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: CustomPaint(
                            painter: brandGlyphPainterFor(widget.target),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.target.brandName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.target.surfaceLabel,
                        textAlign: TextAlign.center,
                        style: AppTypography.helper,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
