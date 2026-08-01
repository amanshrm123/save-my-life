import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/app_page_transitions.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sticker_button.dart';
import '../../../core/widgets/toast_pill.dart';
import '../../ads/application/ad_gate.dart';
import '../../ads/application/ad_service.dart';
import '../../ads/presentation/ad_failed_view.dart';
import '../../ads/presentation/interstitial_screen.dart';
import '../../ads/state/ad_providers.dart';
import '../../play_loop/domain/run_state.dart';
import '../../play_loop/domain/run_summary.dart';
import '../../play_loop/presentation/play_loop_screen.dart';
import '../../sharing/domain/share_target.dart';
import '../../sharing/presentation/share_target_sheet.dart';
import '../../sharing/state/share_providers.dart';
import '../domain/outcome_story_content.dart';
import '../state/outcome_providers.dart';
import 'widgets/outcome_card.dart';
import 'widgets/outcome_card_loading.dart';

/// Real outcome-card screen (architecture v4 §4/§5), hosting the shareable
/// `RepaintBoundary` card, the Share/Again actions row, the post-share
/// confirm toast, and the "Again" -> `AdGate` -> interstitial/ad-failed ->
/// next-run navigation (unchanged from the pre-redesign implementation).
///
/// The card content is now driven by `AsyncValue` (`outcomeStoryProvider`):
/// a minimum 2s tier-themed loader shows every time before the content
/// resolves, per architecture v4 §2/§4 — no route change, just a phase
/// inside this screen.
class OutcomeCardScreen extends ConsumerStatefulWidget {
  const OutcomeCardScreen({super.key, required this.summary});

  final RunSummary summary;

  @override
  ConsumerState<OutcomeCardScreen> createState() => _OutcomeCardScreenState();
}

class _OutcomeCardScreenState extends ConsumerState<OutcomeCardScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _cardKey = GlobalKey();
  late final AnimationController _entranceController;
  late final Animation<double> _entrance;

  Timer? _toastTimer;
  bool _toastVisible = false;
  bool _navigating = false;
  bool _sharing = false;

  /// Guards the loading->resolved entrance trigger below so it only ever
  /// fires once, even though the provider (and thus `ref.listen`'s
  /// callback) can in principle emit again across unrelated rebuilds
  /// (architecture v4 §4/§8 risk 3).
  bool _entranceStarted = false;

  @override
  void initState() {
    super.initState();
    // Every reachable OutcomeCardScreen build corresponds to exactly one
    // completed run — the session-only interstitial cadence counter
    // (architecture §5/§11 risk 3) advances here, once. Deferred to a
    // post-frame callback: `initState` can run mid-build (e.g. while a
    // route-transition's own `SlideTransition` is being built), and Riverpod
    // disallows modifying a provider during the widget tree's build phase.
    // The 2s minimum card load must not change this cadence, so it stays
    // exactly where it was pre-redesign (architecture v4 §4).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(adGateProvider.notifier).registerRunCompleted();
    });

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _entrance = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutBack,
    );
    // `.forward()` deliberately NOT called here (architecture v4 §4/§8 risk
    // 3): left in `initState`, the card would animate in behind the loader
    // and be static by the time content resolves. It's triggered instead
    // from the loading -> resolved transition, via `ref.listen` in build().
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _entranceController.dispose();
    super.dispose();
  }

  String get _shareText {
    switch (widget.summary.outcome) {
      case RunOutcome.death:
        return 'I just died in Stay Alive — stayalive.app';
      case RunOutcome.survived:
        return 'I just pulled a last-second save in Stay Alive — stayalive.app';
      case RunOutcome.eternal:
        return 'I just went Eternal in Stay Alive — stayalive.app';
    }
  }

  /// Share flow (architecture v5 §4/§11/§12):
  ///  - `CardRenderer.renderToFile` runs exactly once per Share tap, before
  ///    anything else — the single-render invariant holds regardless of how
  ///    many tiles the player tries from one open sheet, since the same
  ///    [file] is reused for every tile tap inside `ShareTargetSheet`.
  ///  - Web (`kIsWeb`) skips the sheet entirely and keeps today's direct
  ///    `ShareService` path unchanged (architecture §4.1 — Android intents
  ///    don't exist there, and Instagram has no usable web story-composer).
  ///  - `_sharing` now also covers "sheet is open": it isn't cleared until
  ///    `showShareTargetSheet` itself resolves (whenever/however the sheet
  ///    closes), so a double-tap on Share while the sheet is up is a no-op
  ///    rather than stacking a second sheet (architecture §12 flag 4).
  Future<void> _onShare() async {
    if (_sharing) return;
    _sharing = true;
    try {
      final renderer = ref.read(cardRendererProvider);
      final file = await renderer.renderToFile(_cardKey);
      if (!mounted || file == null) return;

      // The 3-tile sheet fires native platform intents (Android) / pasteboard
      // deep links (iOS) — web has neither (no `Intent`, no
      // `UIPasteboard`/custom-scheme story composer), so web always falls
      // back directly to the plain share path. Android always reaches the
      // sheet regardless of `kFbAppId`: WhatsApp's tile works there
      // independent of the Facebook App ID, so there's always at least one
      // live tile. iOS is different — WhatsApp is *always* dimmed there (no
      // iOS Status-share path exists at all), and with no `kFbAppId`
      // configured (the default — no repo build config sets `FB_APP_ID`
      // today) Instagram/Facebook are ALSO dimmed, which would leave every
      // one of the sheet's 3 tiles dead with "More…" as the only working
      // path. So iOS additionally falls back straight to the plain share
      // path whenever `kFbAppId` is empty, exactly mirroring what iOS did
      // before this feature existed, rather than showing a dead-end sheet.
      // Any other/future platform (macOS/Windows/Linux) falls back the same
      // way web does, rather than hitting an unimplemented MethodChannel.
      if (kIsWeb ||
          (defaultTargetPlatform == TargetPlatform.iOS && kFbAppId.isEmpty)) {
        await _shareViaMoreSheet(file);
        return;
      }

      // Re-probed fresh on every Share tap (architecture §11) — install
      // state can change between sessions, so this deliberately never
      // reuses a stale result from an earlier sheet. Falls back to "all
      // dimmed" on any unexpected error (e.g. a cast failure on the
      // channel's return value) rather than letting it propagate and make
      // the Share tap silently do nothing — `SocialShareService` already
      // handles the expected PlatformException/MissingPluginException
      // cases itself, so this only ever catches genuinely unexpected ones.
      List<ShareTarget> installedTargets;
      try {
        installedTargets = await ref.read(installedTargetsProvider.future);
      } catch (_) {
        installedTargets = const <ShareTarget>[];
      }
      if (!mounted) return;

      final action = await showShareTargetSheet(
        context,
        cardFile: file,
        outcome: widget.summary.outcome,
        installedTargets: installedTargets,
      );
      if (!mounted) return;

      if (action == ShareSheetAction.more) {
        await _shareViaMoreSheet(file);
      }
    } finally {
      _sharing = false;
    }
  }

  /// The unchanged pre-existing path: real `share_plus` OS sheet, "✓ Shared"
  /// toast only on a genuine `ShareResultStatus.success`. Reached either
  /// directly on web, or via the sheet's "More…" link on Android
  /// (architecture §4.1/§8 — completely unchanged either way).
  Future<void> _shareViaMoreSheet(File file) async {
    final shareService = ref.read(shareServiceProvider);
    final success = await shareService.shareFile(file, text: _shareText);
    if (!mounted || !success) return;
    _showToast();
  }

  void _showToast() {
    _toastTimer?.cancel();
    setState(() => _toastVisible = true);
    _toastTimer = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      setState(() => _toastVisible = false);
    });
  }

  Future<void> _onAgain() async {
    if (_navigating) return;
    _navigating = true;

    if (!ref.read(adGateProvider.notifier).isDue) {
      _goToPlay(context);
      return;
    }

    final result = await ref.read(adServiceProvider).showInterstitial();
    if (!mounted) return;
    if (result == InterstitialResult.shown) {
      _goToInterstitial(context);
    } else {
      _goToAdFailed(context);
    }
  }

  void _onHome() {
    Navigator.of(
      context,
    ).popUntil((route) => route.settings.name == AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final asyncContent = ref.watch(outcomeStoryProvider(summary));

    // Fires the entrance beat exactly once, the moment the loader resolves
    // (into either real content or the unreachable-by-construction error
    // branch) — never re-triggers on later rebuilds (share toast, etc.).
    ref.listen<AsyncValue<OutcomeStoryContent>>(outcomeStoryProvider(summary), (
      previous,
      next,
    ) {
      if (_entranceStarted) return;
      if (_isSettled(next)) {
        if (!mounted) return;
        _entranceStarted = true;
        _entranceController.forward();
      }
    });

    // `ref.listen` only fires on a *transition* — it would never trigger if
    // `outcomeStoryProvider` were ever already resolved on this widget's
    // very first build (not reachable in production today, since a fresh
    // `autoDispose` family entry always starts out `loading`, but this
    // guards against that changing later and keeps future widget tests that
    // override the provider with a `data:`/`error:` initial value from
    // landing on a permanently-invisible card).
    if (!_entranceStarted && _isSettled(asyncContent)) {
      _entranceStarted = true;
      _entranceController.forward();
    }

    final style = _shareButtonStyle(summary.outcome);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onHome();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      // The entrance fade+scale (architecture v4 §9) applies
                      // ONLY to the resolved card — never to the loader
                      // (which must render at full opacity the instant it
                      // mounts, not hidden behind an animation that only
                      // starts on resolve) and never to the actions
                      // row/Home link below, which stay visible throughout
                      // loading (design v1 §7.3).
                      //
                      // Per-branch `RepaintBoundary`, not one shared
                      // ancestor above the whole `when()`: the
                      // FadeTransition/ScaleTransition now wraps AROUND
                      // each resolved branch's own RepaintBoundary (see
                      // `_EntranceCard`) rather than sitting inside it, so
                      // Share's capture always rasterizes the fully-settled
                      // card, never a mid-animation frame, no matter how
                      // fast the player taps Share after the card resolves
                      // (this pass's fix — previously the FadeTransition
                      // sat inside the boundary and Share became tappable
                      // the same frame the animation started).
                      //
                      // `Center` here is load-bearing (P0 fix): `Expanded`
                      // hands this subtree a TIGHT constraint (minHeight ==
                      // maxHeight), and `OutcomeCardShell`'s `AspectRatio`
                      // can only derive its own height from its width under
                      // a LOOSE constraint — under a tight one,
                      // `RenderAspectRatio` always falls back to the
                      // incoming `minHeight` instead, silently ignoring the
                      // ratio entirely. `Center` converts the tight
                      // constraint into a loose one (0..maxHeight), letting
                      // `AspectRatio` size itself for real.
                      child: Center(
                        child: asyncContent.when(
                          // Wrapped in the same `kOutcomeCardShadowInset`
                          // Padding the data/error branches get (via
                          // `_EntranceCard`) so all three branches resolve
                          // to the identical final box size — no
                          // pop-on-resolve size jump. Deliberately NOT
                          // wrapped in `_EntranceCard` itself: the loader
                          // must render instantly at full opacity/scale,
                          // with no `RepaintBoundary` capture concern.
                          loading: () => Padding(
                            padding: const EdgeInsets.all(
                              kOutcomeCardShadowInset,
                            ),
                            child: OutcomeCardLoading(outcome: summary.outcome),
                          ),
                          data: (content) => _EntranceCard(
                            entrance: _entrance,
                            cardKey: _cardKey,
                            child: OutcomeCard(
                              outcome: summary.outcome,
                              playerName: summary.playerName,
                              content: content,
                            ),
                          ),
                          // Unreachable by construction: the service always
                          // returns the N/A fallback rather than throwing
                          // (architecture v4 §2) — mapped to the same N/A
                          // card as defence-in-depth (architecture v4
                          // §4/§6.3), never left to throw past the widget
                          // tree. Share is correctly enabled here too (see
                          // `shareEnabled` below) since a fully-rendered N/A
                          // card is genuinely shareable, not a broken state.
                          error: (error, stackTrace) => _EntranceCard(
                            entrance: _entrance,
                            cardKey: _cardKey,
                            child: OutcomeCard(
                              outcome: summary.outcome,
                              playerName: summary.playerName,
                              content: OutcomeStoryContent.naFor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ActionsRow(
                      shareLabel: style.label,
                      shareFill: style.fill,
                      shareText: style.textColor,
                      // `hasValue` alone would leave Share permanently
                      // disabled behind the (unreachable-by-construction)
                      // `AsyncError` branch, even though it renders a
                      // complete, genuinely shareable N/A card — gate on
                      // `_isSettled` instead so both resolved paths enable
                      // Share identically.
                      shareEnabled: _isSettled(asyncContent),
                      onShare: _onShare,
                      onAgain: _onAgain,
                    ),
                    // Architecture v3 §9's nav graph lists Home as a
                    // sibling action to Share/Again, but the mockup's
                    // actions row only shows two buttons (§2.1) — same
                    // category of mockup gap as the missing Home
                    // gear-icon/back-chevron (design v3 §5.1/§5.3).
                    // Reuses onboarding's established plain-text-link
                    // convention ("Skip for now") rather than bolting on
                    // a third sticker button this tight card screen has
                    // no room for.
                    GestureDetector(
                      onTap: _onHome,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text('Home', style: AppTypography.ghostLink),
                      ),
                    ),
                  ],
                ),
                if (_toastVisible)
                  const Positioned(
                    left: 14,
                    right: 14,
                    bottom: 62,
                    child: ToastPill(text: '✓ Shared'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _ShareButtonStyle _shareButtonStyle(RunOutcome outcome) {
    switch (outcome) {
      case RunOutcome.death:
        return const _ShareButtonStyle('Share', AppColors.red, Colors.white);
      case RunOutcome.survived:
        return const _ShareButtonStyle('Share', AppColors.green, Colors.white);
      case RunOutcome.eternal:
        return const _ShareButtonStyle(
          'Flex it',
          AppColors.gold,
          AppColors.ink,
        );
    }
  }
}

class _ShareButtonStyle {
  const _ShareButtonStyle(this.label, this.fill, this.textColor);
  final String label;
  final Color fill;
  final Color textColor;
}

/// True once [value] has settled into either a real result or the
/// (unreachable-by-construction) error path — i.e. everything except the
/// initial `loading` state. Shared by the entrance-trigger check and the
/// Share-enabled gate so both treat "resolved data" and "resolved error"
/// identically.
bool _isSettled(AsyncValue<OutcomeStoryContent> value) =>
    value is AsyncData<OutcomeStoryContent> ||
    value is AsyncError<OutcomeStoryContent>;

/// Extra transparent inset applied around the card content so the card
/// shell's soft drop-shadow (design v1 §2.1 — painted OUTSIDE the card's own
/// rounded-rect bounds) isn't clipped out of the exported PNG: a bare
/// `RepaintBoundary` rasterizes exactly its own tight box, which — with no
/// inset — is exactly the card's own bounds and nothing more.
///
/// Shared by `_EntranceCard` (data/error branches) AND the `loading` branch
/// in `_OutcomeCardScreenState.build` — all three `AsyncValue` branches must
/// resolve to the exact same final box size (this file's own "nothing shifts
/// on resolve" invariant, per `outcome_card_loading.dart`'s doc comment), so
/// they all apply this one inset rather than each branch inventing its own.
const double kOutcomeCardShadowInset = 32;

/// The resolved (or N/A-fallback) card, entrance-animated in. The
/// `RepaintBoundary` sits INSIDE the `FadeTransition`/`ScaleTransition` —
/// i.e. the entrance animation is this widget's ancestor, not its
/// descendant — which is the load-bearing part of this fix: an ancestor
/// `Opacity`/`Transform` never affects what a descendant `RepaintBoundary`
/// captures via `toImage()`, so Share always rasterizes the fully-settled,
/// full-opacity, full-scale card, regardless of how far the entrance
/// animation has actually progressed when the capture happens.
class _EntranceCard extends StatelessWidget {
  const _EntranceCard({
    required this.entrance,
    required this.cardKey,
    required this.child,
  });

  final Animation<double> entrance;
  final GlobalKey cardKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: entrance,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1).animate(entrance),
        child: RepaintBoundary(
          key: cardKey,
          child: Padding(
            padding: const EdgeInsets.all(kOutcomeCardShadowInset),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.shareLabel,
    required this.shareFill,
    required this.shareText,
    required this.shareEnabled,
    required this.onShare,
    required this.onAgain,
  });

  final String shareLabel;
  final Color shareFill;
  final Color shareText;

  /// Gated on `_isSettled(asyncContent)` (architecture v4 §6.3 — covers both
  /// resolved data and the defence-in-depth error branch, not just
  /// `hasValue`): visible but disabled (0.45 opacity, this app's established
  /// convention, design v1 §7.3) during loading — never hidden outright,
  /// reads as "not ready yet."
  final bool shareEnabled;
  final VoidCallback onShare;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StickerButton(
            label: shareLabel,
            fill: shareFill,
            textColor: shareText,
            labelShadow: AppColors.ink,
            showLabelTextShadow: false,
            height: 44,
            borderRadius: 14,
            restShadowOffset: 5,
            showTrailingArrow: true,
            enabled: shareEnabled,
            onPressed: onShare,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          // "Again" stays fully enabled throughout loading (design v1
          // §7.3) — nothing about it depends on the current card's content.
          child: StickerButton(
            label: 'Again',
            fill: AppColors.paper,
            textColor: AppColors.ink,
            labelShadow: AppColors.ink,
            showLabelTextShadow: false,
            height: 44,
            borderRadius: 14,
            restShadowOffset: 5,
            onPressed: onAgain,
          ),
        ),
      ],
    );
  }
}

// --- "Again" -> AdGate -> interstitial/ad-failed -> next-run navigation
// (architecture v3 §9). Deliberately top-level, not `State` methods: once
// "Again" hands off to the interstitial/ad-failed route, the *original*
// `OutcomeCardScreenState` has been replaced (and disposed) by
// `pushReplacement`, so every subsequent hop takes its own fresh
// `BuildContext` (and, where Riverpod access is needed, its own `Consumer`)
// rather than reusing a `State` whose `ref`/`context` may already be gone.

void _goToPlay(BuildContext context) {
  Navigator.of(context).pushReplacement(
    fadeSlideRoute(
      settings: const RouteSettings(name: AppRoutes.play),
      builder: (_) => const PlayLoopScreen(),
    ),
  );
}

void _goToInterstitial(BuildContext context) {
  Navigator.of(context).pushReplacement(
    fadeSlideRoute(
      settings: const RouteSettings(name: '/ad/interstitial'),
      builder: (innerContext) =>
          InterstitialScreen(onDone: () => _goToPlay(innerContext)),
    ),
  );
}

void _goToAdFailed(BuildContext context) {
  Navigator.of(context).pushReplacement(
    fadeSlideRoute(
      settings: const RouteSettings(name: '/ad/failed'),
      builder: (innerContext) => Consumer(
        builder: (consumerContext, ref, _) => AdFailedView(
          onRetry: () => _retryInterstitial(innerContext, ref),
          onMaybeLater: () => _goToPlay(innerContext),
        ),
      ),
    ),
  );
}

Future<void> _retryInterstitial(BuildContext context, WidgetRef ref) async {
  final result = await ref.read(adServiceProvider).showInterstitial();
  if (!context.mounted) return;
  if (result == InterstitialResult.shown) {
    _goToInterstitial(context);
  } else {
    _goToAdFailed(context);
  }
}
