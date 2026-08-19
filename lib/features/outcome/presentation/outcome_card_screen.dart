import 'dart:async';
import 'dart:io';
import 'dart:math' show Random, pi;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/feedback.dart';
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
import 'widgets/outcome_card_shell.dart';

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
    with TickerProviderStateMixin {
  final GlobalKey _cardKey = GlobalKey();
  late final AnimationController _entranceController;

  /// Eternal-only "shine + sparks" effect timeline (juice spec effect 4) —
  /// runs alongside (but longer than) [_entranceController]'s 600ms pop, so
  /// it needs its own controller. `null` for the other two outcomes.
  AnimationController? _eternalFxController;

  /// Eternal-only spark particles, generated once in [initState] (juice
  /// spec effect 4) — empty for the other two outcomes. Purely cosmetic
  /// jitter (position/size/stagger), so a fresh unseeded `Random()` per
  /// screen instance is fine; nothing gameplay-affecting depends on it.
  List<_Spark> _sparks = const [];

  Timer? _toastTimer;
  bool _toastVisible = false;
  bool _navigating = false;
  bool _sharing = false;

  /// Guards the loading->resolved entrance trigger below so it only ever
  /// fires once, even though the provider (and thus `ref.listen`'s
  /// callback) can in principle emit again across unrelated rebuilds
  /// (architecture v4 §4/§8 risk 3).
  bool _entranceStarted = false;

  /// Juice spec "actions gate": true from the moment the entrance reveal
  /// starts until [_kActionsLockDuration] later, so a player can't
  /// Share/Again mid-reveal (Share's `RepaintBoundary` capture is always
  /// safe regardless — see `_EntranceCard`'s doc comment — but locking the
  /// buttons briefly avoids a jarring Share/Again tap landing mid-shake/
  /// flip/sparks). Applies under Reduce Motion too (a plain fade still gets
  /// the same ~300ms settle window).
  bool _actionsLocked = false;

  /// Clears [_actionsLocked] ~300ms after [_startEntrance] runs; cancelled
  /// in [dispose] (see that method's doc comment).
  Timer? _actionsLockTimer;

  /// Survived's/Eternal's delayed haptic ticks (Death's fires immediately,
  /// no `Timer` needed); cancelled in [dispose].
  final List<Timer> _hapticTimers = [];

  static const Duration _kDeathEntranceDuration = Duration(milliseconds: 500);
  static const Duration _kSurvivedEntranceDuration = Duration(
    milliseconds: 600,
  );
  static const Duration _kEternalEntranceDuration = Duration(
    milliseconds: 600,
  );
  static const Duration _kEternalFxDuration = Duration(milliseconds: 1200);
  static const Duration _kActionsLockDuration = Duration(milliseconds: 300);

  /// Survived's flip haptic fires ~65% through the entrance (juice spec
  /// effect 3) — `mediumImpactIfEnabled()` via a one-shot delayed `Future`.
  static const double _kSurvivedHapticFraction = 0.65;

  /// Eternal's second/third `lightImpactIfEnabled()` ticks fire at this
  /// interval after the first (medium) impact at pop start (juice spec
  /// effect 4) — three haptics total, ~120ms apart.
  static const Duration _kEternalHapticInterval = Duration(milliseconds: 120);

  static const int _kSparkCount = 12;
  static const double _kSparkMinSize = 5;
  static const double _kSparkMaxSize = 11;
  static const double _kSparkMaxDriftX = 50;
  static const double _kSparkTravelY = 70;
  static const int _kSparkMinDurationMs = 700;
  static const int _kSparkMaxDurationMs = 1200;
  static const int _kSparkMaxStartDelayMs = 300;

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

    final outcome = widget.summary.outcome;
    _entranceController = AnimationController(
      vsync: this,
      duration: switch (outcome) {
        RunOutcome.death => _kDeathEntranceDuration,
        RunOutcome.survived => _kSurvivedEntranceDuration,
        RunOutcome.eternal => _kEternalEntranceDuration,
      },
    );
    if (outcome == RunOutcome.eternal) {
      _eternalFxController = AnimationController(
        vsync: this,
        duration: _kEternalFxDuration,
      );
      _sparks = _generateSparks();
    }
    // `.forward()` deliberately NOT called here (architecture v4 §4/§8 risk
    // 3): left in `initState`, the card would animate in behind the loader
    // and be static by the time content resolves. It's triggered instead
    // from the loading -> resolved transition, via `ref.listen` in build().
  }

  /// Upper edge of a spark's spawn region, as a fraction of the card's
  /// width/height — "the card's upper area" (juice spec effect 4).
  static const double _kSparkSpawnXStartFraction = 0.1;
  static const double _kSparkSpawnXRangeFraction = 0.8;
  static const double _kSparkSpawnYStartFraction = 0.05;
  static const double _kSparkSpawnYRangeFraction = 0.3;

  List<_Spark> _generateSparks() {
    final random = Random();
    return List.generate(_kSparkCount, (_) {
      final color = random.nextBool() ? AppColors.gold : AppColors.goldDark;
      final startDelayMs = random.nextInt(_kSparkMaxStartDelayMs);
      final rawDurationMs =
          _kSparkMinDurationMs + random.nextInt(_kSparkMaxDurationMs - _kSparkMinDurationMs);
      // Code-review fix (MEDIUM #3): clamp so `startDelay + duration` never
      // exceeds `_kEternalFxDuration` — otherwise up to ~1/3 of sparks (worst
      // case 299ms delay + 1199ms duration = 1498ms) would get cut off
      // mid-fade instead of completing. `_kSparkMaxStartDelayMs` (300) is
      // comfortably below `_kSparkMinDurationMs` (700), so this can only
      // ever shorten toward that floor, never below it.
      final maxDurationMs = _kEternalFxDuration.inMilliseconds - startDelayMs;
      final durationMs = rawDurationMs < maxDurationMs ? rawDurationMs : maxDurationMs;
      return _Spark(
        startDelay: Duration(milliseconds: startDelayMs),
        duration: Duration(milliseconds: durationMs),
        startXFraction: _kSparkSpawnXStartFraction + random.nextDouble() * _kSparkSpawnXRangeFraction,
        startYFraction: _kSparkSpawnYStartFraction + random.nextDouble() * _kSparkSpawnYRangeFraction,
        driftX: (random.nextDouble() * 2 - 1) * _kSparkMaxDriftX,
        travelY: _kSparkTravelY,
        size: _kSparkMinSize + random.nextDouble() * (_kSparkMaxSize - _kSparkMinSize),
        color: color,
      );
    });
  }

  /// Kicks off the outcome-specific entrance reveal (juice spec effects
  /// 2/3/4) the moment the card settles: starts [_entranceController] (and,
  /// for Eternal, [_eternalFxController]), fires this outcome's haptic(s)
  /// (skipped entirely under Reduce Motion — a "juice" affordance only),
  /// and opens then clears the [_actionsLocked] Share/Again gate. Called
  /// synchronously from within `build()` (either from `ref.listen`'s
  /// callback or the first-build settle check below), so it must only ever
  /// mutate state directly (never `setState`) for the parts that need to be
  /// visible in the build about to run — the ~300ms-later unlock is the only
  /// part that legitimately needs `setState`, since it fires well after this
  /// build has finished.
  ///
  /// All of the delayed one-shot work below (the unlock, and the haptics'
  /// own delays) uses real `Timer`s stored in [_actionsLockTimer]/
  /// [_hapticTimers] and cancelled in [dispose] — same convention as this
  /// file's pre-existing `_toastTimer` — rather than bare `Future.delayed`
  /// calls, so a screen disposed mid-reveal (e.g. player backs out fast)
  /// never leaves a pending `Timer` referencing this (now-disposed) `State`
  /// alive past its own lifetime.
  void _startEntrance(BuildContext context) {
    _actionsLocked = true;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (!reduceMotion) {
      _fireEntranceHaptics();
    }
    _entranceController.forward();
    _eternalFxController?.forward();
    _actionsLockTimer = Timer(_kActionsLockDuration, () {
      if (!mounted) return;
      setState(() => _actionsLocked = false);
    });
  }

  void _fireEntranceHaptics() {
    switch (widget.summary.outcome) {
      case RunOutcome.death:
        AppFeedback.heavyImpactIfEnabled();
      case RunOutcome.survived:
        _hapticTimers.add(
          Timer(
            Duration(
              milliseconds:
                  (_kSurvivedEntranceDuration.inMilliseconds * _kSurvivedHapticFraction).round(),
            ),
            () {
              if (!mounted) return;
              AppFeedback.mediumImpactIfEnabled();
            },
          ),
        );
      case RunOutcome.eternal:
        AppFeedback.mediumImpactIfEnabled();
        _hapticTimers.add(
          Timer(_kEternalHapticInterval, () {
            if (!mounted) return;
            AppFeedback.lightImpactIfEnabled();
          }),
        );
        _hapticTimers.add(
          Timer(_kEternalHapticInterval * 2, () {
            if (!mounted) return;
            AppFeedback.lightImpactIfEnabled();
          }),
        );
    }
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _actionsLockTimer?.cancel();
    for (final timer in _hapticTimers) {
      timer.cancel();
    }
    _entranceController.dispose();
    _eternalFxController?.dispose();
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
  ///    `ShareService` path unchanged (architecture §4.1 — neither Android
  ///    intents nor iOS's pasteboard mechanism exist there, and Instagram
  ///    has no usable web story-composer).
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

      // The 3-tile sheet fires native Android intents or the iOS pasteboard
      // mechanism (`SocialSharePlugin.kt`/`SocialSharePlugin.swift`), both
      // now implemented (iOS was previously deferred here — that's now
      // stale) — gate on the platform itself, not just `!kIsWeb`, so any
      // other, genuinely unsupported platform (e.g. macOS/Linux desktop,
      // with no native `social_share` plugin registered at all) still
      // honestly falls back to the plain share path instead of showing a
      // sheet with all tiles permanently dimmed.
      if (kIsWeb ||
          (defaultTargetPlatform != TargetPlatform.android &&
              defaultTargetPlatform != TargetPlatform.iOS)) {
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
        _startEntrance(context);
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
      _startEntrance(context);
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
                            outcome: summary.outcome,
                            controller: _entranceController,
                            fxController: _eternalFxController,
                            sparks: _sparks,
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
                            outcome: summary.outcome,
                            controller: _entranceController,
                            fxController: _eternalFxController,
                            sparks: _sparks,
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
                      // Share identically. ANDed with `!_actionsLocked`
                      // (juice spec "actions gate") so Share also stays
                      // disabled for the ~300ms entrance-settle window even
                      // once the card itself has resolved.
                      shareEnabled: _isSettled(asyncContent) && !_actionsLocked,
                      actionsLocked: _actionsLocked,
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        // `ghostLink` itself stays at its shared 11dp size
                        // (also used by "Skip for now"/"More…" elsewhere,
                        // design v1 Revision 4 §R4.3) — this local
                        // `.copyWith` bumps only this Home link to 13dp.
                        child: Text(
                          'Home',
                          style: AppTypography.ghostLink.copyWith(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
                // `bottom: 88` (design v1 Revision 4 §R4.1, up from 62) —
                // clears the grown Share/Again buttons' top edge entirely
                // (verified against `tester.getRect()` in
                // outcome_card_share_sheet_test.dart's overlap regression
                // test, not just hand-derived arithmetic, which is what
                // produced this pass's first, still-overlapping attempt at
                // this value). Re-derive the same way — measure the real
                // rendered rects — if this row's sizing ever changes again.
                if (_toastVisible)
                  const Positioned(
                    left: 14,
                    right: 14,
                    bottom: 88,
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
/// `RepaintBoundary` sits INSIDE every transform this file applies for the
/// reveal — i.e. the entrance animation (shake/flip/pop, and for Eternal the
/// shine+sparks overlay) is always this widget's ANCESTOR, never its
/// descendant — which is the load-bearing part of this fix: an ancestor
/// `Opacity`/`Transform` never affects what a descendant `RepaintBoundary`
/// captures via `toImage()`, so Share always rasterizes the fully-settled,
/// full-opacity, full-scale/rotation card, regardless of how far the
/// entrance animation has actually progressed when the capture happens.
///
/// Branches on [outcome] (juice spec effects 2/3/4) for three genuinely
/// different reveal shapes — a death "crack shake" (translate+rotate
/// decaying oscillation), a survived "flip" (rotateY with overshoot), and an
/// eternal "pop" (scale+rotate overshoot) plus a shine sweep and spark
/// particles rendered as SIBLING overlays positioned over (never inside) the
/// `RepaintBoundary`, so they can render on top of the card on-screen
/// without ever leaking into the shared PNG. Under Reduce Motion
/// (`MediaQuery.disableAnimations`), all three collapse to one plain
/// fade-in with no transform/particles — same invariant, trivially: there's
/// no transform at all in that path.
class _EntranceCard extends StatelessWidget {
  const _EntranceCard({
    required this.outcome,
    required this.controller,
    required this.fxController,
    required this.sparks,
    required this.cardKey,
    required this.child,
  });

  final RunOutcome outcome;
  final AnimationController controller;

  /// Eternal-only shine+sparks timeline; `null` for the other two outcomes.
  final AnimationController? fxController;

  /// Eternal-only spark particles; empty for the other two outcomes.
  final List<_Spark> sparks;

  final GlobalKey cardKey;
  final Widget child;

  static const Duration _kReduceMotionFadeDuration = Duration(
    milliseconds: 200,
  );

  @override
  Widget build(BuildContext context) {
    final boundary = RepaintBoundary(
      key: cardKey,
      child: Padding(
        padding: const EdgeInsets.all(kOutcomeCardShadowInset),
        child: child,
      ),
    );

    if (MediaQuery.of(context).disableAnimations) {
      final totalMs = controller.duration!.inMilliseconds;
      final fadeFraction = (_kReduceMotionFadeDuration.inMilliseconds / totalMs)
          .clamp(0.0, 1.0);
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: controller,
          curve: Interval(0, fadeFraction),
        ),
        child: boundary,
      );
    }

    switch (outcome) {
      case RunOutcome.death:
        return _DeathShakeEntrance(controller: controller, child: boundary);
      case RunOutcome.survived:
        return _SurvivedFlipEntrance(controller: controller, child: boundary);
      case RunOutcome.eternal:
        return Stack(
          children: [
            _EternalPopEntrance(controller: controller, child: boundary),
            if (fxController != null)
              Positioned.fill(
                child: _EternalFxOverlay(
                  fxController: fxController!,
                  sparks: sparks,
                ),
              ),
          ],
        );
    }
  }
}

/// Builds a keyframed `Animatable<double>` from parallel `values`/`weights`
/// lists (`values.length == weights.length + 1`), driven off the RAW
/// `0..1` controller value — deliberately not off an already-curved (e.g.
/// `easeOutBack`) animation, since `TweenSequence.transform` asserts its
/// input stays within `[0, 1]` and `easeOutBack`'s whole point is to
/// transiently overshoot past `1.0`, which would trip that assertion.
/// [curve] is instead applied per-leg (each `TweenSequenceItem` individually
/// eased), which is safe and still reads as "eased" without the crash risk.
Animatable<double> _keyframeSequence(
  List<double> values,
  List<double> weights, {
  Curve curve = Curves.linear,
}) {
  final items = <TweenSequenceItem<double>>[];
  for (var i = 0; i < weights.length; i++) {
    items.add(
      TweenSequenceItem(
        tween: Tween(
          begin: values[i],
          end: values[i + 1],
        ).chain(CurveTween(curve: curve)),
        weight: weights[i],
      ),
    );
  }
  return TweenSequence<double>(items);
}

/// Death — "crack shake" (juice spec effect 2): opacity fades in over the
/// first ~120ms, while a translateX+rotateZ pair oscillates and decays to
/// rest across the full 500ms entrance.
class _DeathShakeEntrance extends StatelessWidget {
  const _DeathShakeEntrance({required this.controller, required this.child});

  final AnimationController controller;
  final Widget child;

  /// 120ms / 500ms.
  static const double _kFadeInEndFraction = 0.24;

  static const List<double> _kDx = [0, -10, 9, -7, 5, -3, 2, 0];
  static const List<double> _kDeg = [0, -3, 3, -2, 0, 0, 0, 0];
  static const List<double> _kWeights = [
    0.10,
    0.15,
    0.15,
    0.15,
    0.15,
    0.15,
    0.15,
  ];

  @override
  Widget build(BuildContext context) {
    final dxAnim = _keyframeSequence(_kDx, _kWeights).animate(controller);
    final degAnim = _keyframeSequence(_kDeg, _kWeights).animate(controller);
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: controller,
        curve: const Interval(0, _kFadeInEndFraction),
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, c) {
          final dx = dxAnim.value;
          final radians = degAnim.value * pi / 180;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translateByDouble(dx, 0, 0, 1)
              ..rotateZ(radians),
            child: c,
          );
        },
        child: child,
      ),
    );
  }
}

/// Survived — "flip" (juice spec effect 3): a perspective rotateY sweeping
/// 90°→-12°→0° (an overshoot past 0 before settling) combined with a scale
/// overshoot 0.8→1.05→1.0, opacity fading in over the first ~150ms.
class _SurvivedFlipEntrance extends StatelessWidget {
  const _SurvivedFlipEntrance({required this.controller, required this.child});

  final AnimationController controller;
  final Widget child;

  /// 150ms / 600ms.
  static const double _kFadeInEndFraction = 0.25;

  static const List<double> _kRotateYDeg = [90, -12, 0];
  static const List<double> _kRotateWeights = [0.6, 0.4];

  static const List<double> _kScale = [0.8, 1.05, 1.0];
  static const List<double> _kScaleWeights = [0.5, 0.5];

  @override
  Widget build(BuildContext context) {
    final rotateAnim = _keyframeSequence(
      _kRotateYDeg,
      _kRotateWeights,
      curve: Curves.easeOut,
    ).animate(controller);
    final scaleAnim = _keyframeSequence(
      _kScale,
      _kScaleWeights,
      curve: Curves.easeOut,
    ).animate(controller);
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: controller,
        curve: const Interval(0, _kFadeInEndFraction),
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, c) {
          final radians = rotateAnim.value * pi / 180;
          final scale = scaleAnim.value;
          final matrix = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(radians)
            ..scaleByDouble(scale, scale, scale, 1);
          return Transform(
            alignment: Alignment.center,
            transform: matrix,
            child: c,
          );
        },
        child: child,
      ),
    );
  }
}

/// Eternal — "pop" half of the shine+sparks effect (juice spec effect 4):
/// scale overshooting 0.3→1.25→0.92→1.0, rotate overshooting -12°→5°→0°,
/// opacity fading in over the first ~120ms. The shine sweep/sparks
/// themselves are a separate sibling overlay (see [_EntranceCard] /
/// [_EternalFxOverlay]), never inside this transform or the `RepaintBoundary`
/// it wraps.
class _EternalPopEntrance extends StatelessWidget {
  const _EternalPopEntrance({required this.controller, required this.child});

  final AnimationController controller;
  final Widget child;

  /// 120ms / 600ms.
  static const double _kFadeInEndFraction = 0.2;

  static const List<double> _kScale = [0.3, 1.25, 0.92, 1.0];
  static const List<double> _kScaleWeights = [0.35, 0.25, 0.4];

  /// Only 2 legs (3 keyframes) vs scale's 3 legs (4 keyframes) — the spec's
  /// "same weights" doesn't translate literally onto a shorter keyframe
  /// list, so this collapses scale's overshoot-phase weight (0.35) as the
  /// first leg and its remaining settle-phase weight (0.25 + 0.4) as the
  /// second, matching the same overshoot/settle proportion.
  static const List<double> _kRotateDeg = [-12, 5, 0];
  static const List<double> _kRotateWeights = [0.35, 0.65];

  @override
  Widget build(BuildContext context) {
    final scaleAnim = _keyframeSequence(
      _kScale,
      _kScaleWeights,
      curve: Curves.easeOut,
    ).animate(controller);
    final rotateAnim = _keyframeSequence(
      _kRotateDeg,
      _kRotateWeights,
      curve: Curves.easeOut,
    ).animate(controller);
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: controller,
        curve: const Interval(0, _kFadeInEndFraction),
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, c) {
          final radians = rotateAnim.value * pi / 180;
          return Transform.scale(
            scale: scaleAnim.value,
            child: Transform.rotate(angle: radians, child: c),
          );
        },
        child: child,
      ),
    );
  }
}

/// One eternal spark particle's randomized cosmetic parameters (juice spec
/// effect 4) — purely presentational jitter, not gameplay state.
class _Spark {
  _Spark({
    required this.startDelay,
    required this.duration,
    required this.startXFraction,
    required this.startYFraction,
    required this.driftX,
    required this.travelY,
    required this.size,
    required this.color,
  });

  final Duration startDelay;
  final Duration duration;

  /// 0-1 fraction of the card's width/height, upper area only.
  final double startXFraction;
  final double startYFraction;

  final double driftX;
  final double travelY;
  final double size;
  final Color color;
}

/// Eternal's shine sweep + spark particles (juice spec effect 4), rendered
/// as a sibling overlay sized/positioned to exactly cover the card's
/// `RepaintBoundary` box (via the identical `Stack`/`Positioned.fill`
/// layout in `_EntranceCard` — `Transform` doesn't change layout size, only
/// paint, so this overlay's box always matches the card's regardless of the
/// pop's in-flight scale/rotation) — never a descendant of it, so it can
/// never appear in Share's `toImage()` capture.
class _EternalFxOverlay extends StatelessWidget {
  const _EternalFxOverlay({required this.fxController, required this.sparks});

  final AnimationController fxController;
  final List<_Spark> sparks;

  static const Duration _kShineStartDelay = Duration(milliseconds: 150);
  static const Duration _kShineSweepDuration = Duration(milliseconds: 1000);
  static const double _kShineBandWidthFraction = 0.45;
  static const double _kShineAngleDegrees = -20;
  static const double _kShineAlpha = 0.7;

  /// How much taller than the card the (pre-rotation) band is drawn, so its
  /// rotated diagonal still fully covers the card's corners with no
  /// uncovered wedge — needs an actual unconstrained box to take effect
  /// (see [_buildShine]'s `OverflowBox`, code-review fix #4).
  static const double _kShineHeightMultiplier = 2.2;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Mirrors `OutcomeCardShell`'s own `k` scaling so the clip radius
          // matches the real card's rounded corners underneath, without
          // this overlay needing to reach into the shell's palette/layout.
          final cardWidth = constraints.maxWidth - 2 * kOutcomeCardShadowInset;
          final k = cardWidth / OutcomeCardShell.referenceWidth;
          final radius = OutcomeCardShell.cornerRadiusAtReferenceWidth * k;
          return Padding(
            padding: const EdgeInsets.all(kOutcomeCardShadowInset),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: AnimatedBuilder(
                animation: fxController,
                builder: (context, _) {
                  final totalMs = fxController.duration!.inMilliseconds;
                  final elapsedMs = fxController.value * totalMs;
                  final shineStartMs = _kShineStartDelay.inMilliseconds;
                  final shineEndMs =
                      shineStartMs + _kShineSweepDuration.inMilliseconds;
                  final shineActive =
                      elapsedMs >= shineStartMs && elapsedMs <= shineEndMs;
                  final shineProgress = shineActive
                      ? (elapsedMs - shineStartMs) /
                            (shineEndMs - shineStartMs)
                      : 0.0;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (shineActive) _buildShine(shineProgress),
                      CustomPaint(
                        painter: _SparksPainter(
                          sparks: sparks,
                          elapsedMs: elapsedMs,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShine(double progress) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final bandWidth = width * _kShineBandWidthFraction;
        final dx = -bandWidth + progress * (width + 2 * bandWidth);
        final bandHeight = height * _kShineHeightMultiplier;
        return ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: Offset(dx, 0),
              child: Transform.rotate(
                angle: _kShineAngleDegrees * pi / 180,
                // `OverflowBox` (code-review fix #4): `Align` only loosens
                // the incoming constraints (`maxHeight` stays == the
                // card's own height), so a plain `SizedBox` taller than
                // that gets silently clamped back down by
                // `constraints.enforce` — `_kShineHeightMultiplier` was a
                // no-op. `OverflowBox` hands the child genuinely
                // unconstrained space instead, so the band is drawn at its
                // real (taller) size and its rotated diagonal actually
                // covers the card's corners; the outer `ClipRect` still
                // clips the visible result back down to the card bounds.
                child: OverflowBox(
                  minWidth: bandWidth,
                  maxWidth: bandWidth,
                  minHeight: bandHeight,
                  maxHeight: bandHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: _kShineAlpha),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Paints all of [sparks] for the current [elapsedMs] into the fx timeline
/// (juice spec effect 4) — one `CustomPainter` for every spark rather than
/// 12 separate `AnimationController`s/widgets.
class _SparksPainter extends CustomPainter {
  _SparksPainter({required this.sparks, required this.elapsedMs});

  final List<_Spark> sparks;
  final double elapsedMs;

  /// Scale goes `1 -> 0.2` over a spark's lifetime (juice spec effect 4) —
  /// i.e. shrinks by this fraction of its starting size.
  static const double _kScaleShrinkFactor = 0.8;

  @override
  void paint(Canvas canvas, Size size) {
    for (final spark in sparks) {
      final startMs = spark.startDelay.inMilliseconds;
      final durationMs = spark.duration.inMilliseconds;
      if (elapsedMs < startMs || elapsedMs > startMs + durationMs) continue;
      final t = (elapsedMs - startMs) / durationMs;
      final x = spark.startXFraction * size.width + spark.driftX * t;
      final y = spark.startYFraction * size.height - spark.travelY * t;
      final scale = 1.0 - _kScaleShrinkFactor * t;
      final opacity = 1.0 - t;
      canvas.drawCircle(
        Offset(x, y),
        (spark.size / 2) * scale,
        Paint()..color = spark.color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparksPainter oldDelegate) =>
      oldDelegate.elapsedMs != elapsedMs;
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.shareLabel,
    required this.shareFill,
    required this.shareText,
    required this.shareEnabled,
    required this.actionsLocked,
    required this.onShare,
    required this.onAgain,
  });

  final String shareLabel;
  final Color shareFill;
  final Color shareText;

  /// Gated on `_isSettled(asyncContent) && !_actionsLocked` (architecture v4
  /// §6.3 covers both resolved data and the defence-in-depth error branch,
  /// not just `hasValue`; the juice spec's "actions gate" additionally holds
  /// Share disabled for ~300ms after the card settles, while the entrance
  /// reveal plays): visible but disabled (0.45 opacity, this app's
  /// established convention, design v1 §7.3) during loading/the reveal
  /// window — never hidden outright, reads as "not ready yet."
  final bool shareEnabled;

  /// Juice spec "actions gate": true for ~300ms starting the moment the
  /// entrance reveal begins. "Again" has no content-readiness gate of its
  /// own (unlike Share), but is still briefly disabled by this so a player
  /// can't restart a run mid-shake/flip/sparks.
  final bool actionsLocked;

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
            // 52dp, height only — borderRadius/restShadowOffset stay at
            // this widget's own defaults (14/5), matching every other
            // button in the app (design v1 Revision 4 §R4.1).
            height: 52,
            showTrailingArrow: true,
            enabled: shareEnabled,
            onPressed: onShare,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          // "Again" stays fully enabled throughout loading (design v1
          // §7.3) — nothing about it depends on the current card's content
          // — but is still briefly disabled by the juice spec's
          // `actionsLocked` gate while the entrance reveal plays.
          child: StickerButton(
            label: 'Again',
            fill: AppColors.paper,
            textColor: AppColors.ink,
            labelShadow: AppColors.ink,
            showLabelTextShadow: false,
            // 52dp alongside Share — see the Share button above.
            height: 52,
            enabled: !actionsLocked,
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
