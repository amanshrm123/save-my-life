import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/copy/app_copy.dart';
import '../../../core/routing/app_route_observer.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sticker_button.dart';
import '../../ads/presentation/banner_ad_slot.dart';
import '../../avatar/presentation/widgets/home_avatar_card.dart';
import '../../avatar/state/avatar_providers.dart';
import '../../progression/domain/stats_snapshot.dart';
import '../../progression/domain/streak_calculator.dart';
import '../../progression/state/stats_providers.dart';
import '../../settings/state/settings_providers.dart';
import '../../tour/domain/tour_step.dart';
import '../../tour/presentation/widgets/tour_overlay.dart';
import '../../tour/state/tour_providers.dart';
import 'widgets/stat_tile.dart';
import 'widgets/streak_advanced_overlay.dart';
import 'widgets/streak_bar.dart';
import 'widgets/streak_broken_view.dart';

/// Resolves [key]'s currently-attached widget's on-screen rect in global
/// coordinates — or `null` if there is nothing safe to spotlight
/// (onboarding-tour v1 §4.1): the key was never attached, its box hasn't
/// been laid out yet, or it laid out to zero size. A pure function of a
/// [GlobalKey] (never a whole `BuildContext`/`Element`/`RenderObject`) so it
/// is unit-testable without mounting a widget tree, and so the tour only
/// ever carries the resulting `Rect` onward (onboarding-tour v1 §9.4).
@visibleForTesting
Rect? resolveTourTargetRect(GlobalKey? key) {
  final renderObject = key?.currentContext?.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) return null;
  final size = renderObject.size;
  if (size.isEmpty) return null;
  return renderObject.localToGlobal(Offset.zero) & size;
}

/// The real Home hub (design v3 §5.1), replacing `PlaceholderHomeScreen`:
/// wordmark + tagline, daily-streak card, 3 stat tiles, big Play button,
/// gear -> Settings. Also hosts the two Home *states* (not routes) —
/// streak-advanced (6.2) and streak-broken (6.3) — which wholesale replace
/// the dashboard body per design v3 §5.2/§5.3.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver, RouteAware {
  static const StreakCalculator _calculator = StreakCalculator();

  bool _reminderPromptScheduled = false;
  ModalRoute<void>? _observedRoute;

  /// Whether Home is the current, actually-visible route right now — threaded
  /// down to `HomeAvatarCard`/`AvatarFigure` as `shouldAnimateFill` so the
  /// life-meter fill only animates while genuinely on screen (see
  /// `AvatarFigure`'s doc comment). Defaults true: the very first build after
  /// `didChangeDependencies` subscribes is Home's own first appearance, which
  /// should still get the normal fill-in entrance animation.
  bool _isVisible = true;

  // --- Home dashboard first-time feature tour (onboarding-tour v1). Ephemeral
  // UI state on this State object, deliberately not a Riverpod notifier
  // (design v1 §5.2) -- see `_maybeStartTour`/`_advanceTourStep`/`_endTour*`
  // below. The four target keys are allocated at most once per session
  // (`_allocateTourKeys`'s `??=`) and then kept for the rest of Home's
  // lifetime -- NOT released when the tour ends (code-reviewer finding #2:
  // `_StreakCard`/the stat-tile `Row`/`HomeAvatarCard`/`_SettingsIconButton`
  // are permanent dashboard fixtures, and nulling their `key:` back to
  // `null` made the framework destroy-and-reinflate all four on every tour
  // dismissal, visibly replaying `HomeAvatarCard`'s fill animation from
  // empty). Only `_tourOverlayKey` is released with the tour
  // (`_releaseTourKeys`) -- that widget is genuinely torn down each time.
  GlobalKey? _streakCardKey;
  GlobalKey? _statTileRowKey;
  GlobalKey? _avatarCardKey;
  GlobalKey? _settingsGearKey;
  GlobalKey? _tourOverlayKey;

  /// Null when no tour is showing; otherwise the index into [kHomeTourSteps].
  int? _tourStep;

  /// The current step's target rect, already converted to `TourOverlay`'s
  /// local coordinate space. Null only for the one transient frame between a
  /// step (re)starting and the post-frame remeasure resolving it.
  Rect? _spotlightRect;

  /// True once a dismiss has been requested, driving `TourOverlay`'s 150ms
  /// fade-out before the fields below are actually cleared (design v1 §3.3).
  bool _tourClosing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Design v1 §9.3: allocate the tour's GlobalKeys now only if the tour
    // could still fire this session -- decidable synchronously, since
    // `PreferencesService` getters are sync. Once the tour has been shown,
    // Home allocates zero extra objects here for the rest of the process
    // lifetime (a key only comes back if Settings' "Replay tour" explicitly
    // asks for the tour again, see `_maybeStartTour`) -- but once allocated,
    // the four target keys are never released again (see the field-group
    // doc comment above).
    if (!ref.read(tourRepositoryProvider).shown) {
      _allocateTourKeys();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Home is reached via `pushReplacement` chains (Play -> Outcome) that
    // never pop it off the Navigator, so it sits mounted-but-offscreen the
    // whole time and rebuilds on every `statsProvider` change regardless of
    // visibility (the bug this `RouteAware` subscription fixes — see
    // `didPush`/`didPopNext`/`didPushNext` below). Subscribe/resubscribe only
    // when the owning route actually changes.
    final route = ModalRoute.of(context);
    if (route != _observedRoute) {
      if (_observedRoute != null) appRouteObserver.unsubscribe(this);
      _observedRoute = route;
      if (route != null) appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Architecture v3 §11 risk 5: re-evaluate streak-broken on resume, so
    // crossing midnight while the app sits open on Home updates correctly
    // (today() is re-read on the next build this triggers).
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeMetrics() {
    // Onboarding-tour v1 §4.1: rotation / text-scale / keyboard change while
    // the tour is up -- re-measure the current step's rect. There is no
    // orientation lock in `main.dart`, so this is a real case.
    if (_tourStep != null && !_tourClosing) _scheduleTourRemeasure();
  }

  // --- RouteAware: the *only* place that decides whether to act on
  // `justAdvanced` / the reminder-prompt gate. `build()` below just renders
  // whatever the provider's current state is; it never schedules anything.

  @override
  void didPush() {
    // Home just became the current, visible route for the first time.
    _setVisible(true);
    _onBecameVisible();
  }

  @override
  void didPopNext() {
    // A route pushed above Home (Outcome, Settings, Stats, reminder opt-in,
    // ...) was popped -- Home is the visible route again.
    _setVisible(true);
    _onBecameVisible();
  }

  @override
  void didPushNext() {
    // Home is being covered by a newly-pushed route (e.g. the player tapped
    // "Play day N" from the celebration, or opened Settings/Stats while it
    // was showing). Clear the transient flag now: the celebration has
    // already been on screen for the whole time Home was visible, and
    // clearing it while Home is hidden can never cause a visible flicker the
    // way clearing it mid-display (the old `mounted`-only gating) could.
    if (ref.read(statsProvider).justAdvanced) {
      ref.read(statsProvider.notifier).clearJustAdvanced();
    }
    _setVisible(false);
  }

  void _setVisible(bool visible) {
    if (_isVisible == visible) return;
    if (!mounted) {
      _isVisible = visible;
      return;
    }
    setState(() => _isVisible = visible);
  }

  void _onBecameVisible() {
    final snap = ref.read(statsProvider);
    // The celebration is showing (or about to) -- don't also stack the
    // reminder-prompt push on top of it; that gets (re-)evaluated once the
    // celebration is dismissed and Home becomes visible again.
    if (snap.justAdvanced) {
      _discardSuppressedReplayRequest();
      return;
    }

    final today = _calculator.today();
    if (_calculator.isBrokenAtOpen(snap.streak, today)) {
      _discardSuppressedReplayRequest();
      return;
    }

    // Onboarding-tour v1 §2.2: the tour takes precedence over the
    // reminder-prompt gate -- if it's going to show, skip the reminder-prompt
    // gate for this pass. It gets re-evaluated the next time Home becomes
    // visible, and its own flag is untouched by the skip.
    if (_maybeStartTour(snap)) return;

    _maybeScheduleReminderPrompt(snap.streak.count);
  }

  /// The in-context 8.4 opt-in (architecture §8): shown once, after the
  /// streak reaches day 2, gated by `reminder_opt_in_shown` and never asked
  /// if the reminder is already on. A real push (unlike 6.2/6.3's in-place
  /// Home states), per design v3 §7.
  void _maybeScheduleReminderPrompt(int streakCount) {
    if (_reminderPromptScheduled) return;
    if (streakCount < 2) return;
    final repo = ref.read(settingsRepositoryProvider);
    if (repo.reminderOptInShown) return;
    if (ref.read(settingsProvider).reminder) return;

    _reminderPromptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reminderPromptScheduled = false;
      if (!mounted) return;
      Navigator.of(context).pushNamed(AppRoutes.reminderOptIn);
    });
  }

  // --- Home dashboard first-time feature tour (onboarding-tour v1 §2/§4/§9).

  /// Reads whether Settings' "Replay tour" queued a replay, consuming it via
  /// a deferred write (code-reviewer finding #6: writing to
  /// `pendingHomeTourProvider`'s notifier synchronously here is safe today --
  /// this is only ever reached outside the build phase -- but deferring
  /// costs nothing and removes the risk entirely if a future call path ever
  /// reaches it mid-build, e.g. from `didChangeDependencies`). Read once;
  /// `_maybeStartTour`'s own `_tourStep != null` guard already prevents this
  /// being read twice for the one request.
  bool _consumePendingReplayRequest() {
    final requested = ref.read(pendingHomeTourProvider);
    if (requested) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(pendingHomeTourProvider.notifier).state = false;
      });
    }
    return requested;
  }

  /// Code-reviewer finding #4: `justAdvanced` and streak-broken suppress the
  /// tour in `_onBecameVisible` (nothing to spotlight, §4.1) -- including a
  /// replay the player explicitly asked for from Settings -- but
  /// `_maybeStartTour` (the only other reader of `pendingHomeTourProvider`)
  /// is never reached from those branches. Left unconsumed, a suppressed
  /// replay request would sit in RAM and ambush the player at a later,
  /// unrelated Home visit instead of just being asked for again.
  void _discardSuppressedReplayRequest() => _consumePendingReplayRequest();

  /// Starts the tour once the player has completed at least one run and it
  /// has never been shown, or immediately -- regardless of run count /
  /// `home_tour_shown` -- when Settings' "Replay tour" queued a replay
  /// (§2.3). Returns true when the tour is (already, or now) showing, so
  /// `_onBecameVisible` can skip the reminder-prompt gate for this pass.
  bool _maybeStartTour(StatsSnapshot snap) {
    if (_tourStep != null) return true;

    final replayRequested = _consumePendingReplayRequest();
    if (!replayRequested) {
      if (ref.read(tourRepositoryProvider).shown) return false;
      if (snap.totalRunsPlayed < 1) return false;
    }

    _allocateTourKeys();
    setState(() => _tourStep = 0);
    _scheduleTourRemeasure();

    // §2.4: written on first display (once step 1 has rendered), not on
    // completion -- a player who kills the app mid-tour is not re-tour'd
    // next launch. Writing the identical `true` value again on a replay is
    // a harmless no-op.
    //
    // Guards on `_tourStep != null`, not `!_tourClosing` (code-reviewer
    // finding #5): if `build()` takes the `justAdvanced`/streak-broken
    // branch in this same frame (`_hardEndTourIfActive`, which mutates
    // `_tourStep` directly rather than through `setState`), the tour never
    // actually displayed a single step and the flag must not be burned for
    // it. The rect-resolution failure path (§4.1) is different: that DOES
    // still count as "shown" (`_tourClosing` becomes true, but `_tourStep`
    // stays non-null until `_finishEndTour`), so it's still correct for
    // this write to go through in that case.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tourStep == null) return;
      ref.read(tourRepositoryProvider).markShown();
    });

    return true;
  }

  void _advanceTourStep() {
    if (_tourStep == null || _tourClosing) return;
    final next = _tourStep! + 1;
    if (next >= kHomeTourSteps.length) {
      _requestEndTour();
      return;
    }
    setState(() => _tourStep = next);
    _scheduleTourRemeasure();
  }

  /// Starts the tour's 150ms fade-out (design v1 §3.3). The tour's fields
  /// are only actually cleared once that finishes, via [_finishEndTour] --
  /// `TourOverlay.onDismissed` -- so unmounting the `Stack` child (and with
  /// it the painter/card/tickers) happens through the normal framework path
  /// (design v1 §9.1), not mid-animation.
  void _requestEndTour() {
    if (_tourStep == null || _tourClosing) return;
    setState(() => _tourClosing = true);
  }

  void _finishEndTour() {
    if (_tourStep == null) return;
    setState(() {
      _tourStep = null;
      _spotlightRect = null;
      _tourClosing = false;
      _releaseTourKeys();
    });
  }

  /// Design v1 §4.1: the `justAdvanced`/streak-broken branches replace the
  /// dashboard body wholesale, so every measured rect is instantly garbage
  /// -- end the tour immediately, with no fade-out to honor (the body it was
  /// drawn over is already gone). Mutates fields directly rather than via
  /// `setState` because this is called from within `build()` itself.
  void _hardEndTourIfActive() {
    if (_tourStep == null) return;
    _tourStep = null;
    _spotlightRect = null;
    _tourClosing = false;
    _releaseTourKeys();
  }

  void _allocateTourKeys() {
    _streakCardKey ??= GlobalKey();
    _statTileRowKey ??= GlobalKey();
    _avatarCardKey ??= GlobalKey();
    _settingsGearKey ??= GlobalKey();
    _tourOverlayKey ??= GlobalKey();
  }

  /// Only releases [_tourOverlayKey] -- the overlay widget it's attached to
  /// is torn down with the tour anyway (§9.1), so there's nothing to keep
  /// stable for. The four target-widget keys are deliberately NOT nulled
  /// here (code-reviewer finding #2 on this pass): `_StreakCard`, the
  /// stat-tile `Row`, `HomeAvatarCard` and `_SettingsIconButton` are
  /// permanent dashboard fixtures, not tour-only widgets, so swapping their
  /// `key:` back to `null` on every tour end made `Widget.canUpdate` return
  /// false for each of them -- destroying and reinflating all four,
  /// including `HomeAvatarCard`'s `AnimationController`, which visibly
  /// replayed the life-meter fill animation from empty on every dismissal.
  /// Four `GlobalKey`s (allocated at most once per session, per
  /// `_allocateTourKeys`'s `??=`) living for the rest of Home's lifetime is
  /// a fixed, bounded cost -- not the unbounded-growth pattern CLAUDE.md
  /// rule 7 targets -- and is a strictly better trade than the remount.
  void _releaseTourKeys() {
    _tourOverlayKey = null;
  }

  GlobalKey? _tourTargetKeyFor(int? step) {
    switch (step) {
      case 0:
        return _streakCardKey;
      case 1:
        return _statTileRowKey;
      case 2:
        return _avatarCardKey;
      case 3:
        return _settingsGearKey;
      default:
        return null;
    }
  }

  /// Measurement is once-per-step (or on a metrics change), never per-frame
  /// or inside `build()`/`paint()` (design v1 §9.7): the target rect is
  /// measured in global coordinates, then converted to `TourOverlay`'s own
  /// local space via its own `RenderBox.globalToLocal` -- this stays correct
  /// regardless of what padding/`SafeArea` sits above it.
  void _scheduleTourRemeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tourStep == null || _tourClosing) return;
      final rect = _measureCurrentTourTarget();
      if (rect == null) {
        // §4.1: the target key resolved to null, or its box isn't laid out
        // / has zero size -- never paint a spotlight over nothing.
        _requestEndTour();
        return;
      }
      setState(() => _spotlightRect = rect);
    });
  }

  Rect? _measureCurrentTourTarget() {
    final globalRect = resolveTourTargetRect(_tourTargetKeyFor(_tourStep));
    if (globalRect == null) return null;
    final overlayBox = _tourOverlayKey?.currentContext?.findRenderObject();
    if (overlayBox is! RenderBox || !overlayBox.hasSize) return null;
    return Rect.fromPoints(
      overlayBox.globalToLocal(globalRect.topLeft),
      overlayBox.globalToLocal(globalRect.bottomRight),
    );
  }

  void _goToPlay() => Navigator.of(context).pushNamed(AppRoutes.play);
  void _goToSettings() => Navigator.of(context).pushNamed(AppRoutes.settings);
  void _goToStats() => Navigator.of(context).pushNamed(AppRoutes.stats);
  void _goToAvatarPicker() =>
      Navigator.of(context).pushNamed(AppRoutes.avatarPicker);

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(statsProvider);

    if (snap.justAdvanced) {
      // Design v1 §4.1: this branch replaces the dashboard body wholesale,
      // so every measured tour rect is instantly garbage -- end it now.
      _hardEndTourIfActive();
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: StreakAdvancedView(
            dayCount: snap.streak.count,
            onPlay: _goToPlay,
          ),
        ),
      );
    }

    final today = _calculator.today();
    if (_calculator.isBrokenAtOpen(snap.streak, today)) {
      _hardEndTourIfActive();
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: StreakBrokenView(
            previousStreak: snap.streak.count,
            onStartNewStreak: _goToPlay,
          ),
        ),
      );
    }

    final tourStep = _tourStep;

    return PopScope(
      // Onboarding-tour v1 §4: the overlay is not a route, so the back
      // button would otherwise reach `Navigator` unimpeded and -- since Home
      // is the stack root after splash's `pushReplacement` -- exit the app.
      canPop: tourStep == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _requestEndTour();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        // `TourOverlay` is a sibling of the ENTIRE dashboard-plus-banner
        // `Column` below (not nested inside its `Expanded` dashboard
        // portion) so it stays `Positioned.fill` against the FULL Scaffold
        // body -- keeping its own local coordinate space identical to
        // `MediaQuery.sizeOf(context)` (what `_CoachMarkPlacement`'s "top
        // 55%" placement heuristic and cutout-inflate math both assume).
        // Nesting it inside the reduced, banner-shortened `Expanded` area
        // instead would silently put those two out of sync (ads-branch
        // merge-coordination note, design v1 §8).
        body: Stack(
          children: [
            // Code-reviewer finding #3 on this pass: the tour's opaque
            // `GestureDetector` (`TourOverlay`) only blocks pointer hit
            // testing -- Semantics actions dispatch straight to a node's
            // handler and bypass hit testing entirely, so without this a
            // screen-reader user could still activate Play/Settings/etc.
            // (or the ad banner) underneath while the tour is up, landing
            // exactly on the covered-route problem design v1 §4 explains
            // the opaque model exists to prevent.
            ExcludeSemantics(
              excluding: tourStep != null,
              // Restructured for the banner footer slot (real-ad-serving
              // pass, game-ux-designer spec): the dashboard content sits in
              // an `Expanded` above the slot, and the slot itself sits
              // outside that `Expanded`, at the very bottom, in its OWN
              // `SafeArea(top: false)` so it alone owns the bottom
              // nav-inset (the content `SafeArea` below skips its own
              // bottom inset accordingly, via `bottom: false`, to avoid
              // double-padding).
              child: Column(
                children: [
                  Expanded(
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 14,
                          // 8dp gap between the Play button and the banner
                          // slot's top edge (game-ux-designer spec) — down
                          // from the original 14 now that the slot itself
                          // sits right below.
                          bottom: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      style: AppTypography.wordmark.copyWith(
                                        fontSize: 26,
                                        height: 0.9,
                                      ),
                                      children: const [
                                        TextSpan(text: 'Stay '),
                                        TextSpan(
                                          text: 'Alive',
                                          style: TextStyle(
                                            color: AppColors.coral,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                _SettingsIconButton(
                                  key: _settingsGearKey,
                                  onPressed: _goToSettings,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(kAppTagline, style: AppTypography.body),
                            const SizedBox(height: 14),
                            _StreakCard(
                              key: _streakCardKey,
                              streakCount: snap.streak.count,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              key: _statTileRowKey,
                              children: [
                                Expanded(
                                  child: StatTile(
                                    value: '${snap.totalSurvives}',
                                    label: 'Survived',
                                    valueColor: AppColors.greenDark,
                                    onTap: _goToStats,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: StatTile(
                                    value: '${snap.totalEternal}',
                                    label: 'Eternal',
                                    valueColor: AppColors.goldDark,
                                    onTap: _goToStats,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: StatTile(
                                    value: '${snap.totalDeaths}',
                                    label: 'Deaths',
                                    valueColor: AppColors.redDark,
                                    onTap: _goToStats,
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              child: Center(
                                child: HomeAvatarCard(
                                  key: _avatarCardKey,
                                  avatarId: ref.watch(selectedAvatarProvider),
                                  bestLifePercent: snap.bestLifePercent,
                                  onTap: _goToAvatarPicker,
                                  shouldAnimateFill: _isVisible,
                                ),
                              ),
                            ),
                            StickerButton(
                              label: 'Play',
                              fill: AppColors.coral,
                              labelShadow: AppColors.coralDark,
                              height: 50,
                              onPressed: _goToPlay,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    // Design v1 §8: paused while the tour is up -- Home
                    // stays the "visible route" for the whole tour (it's
                    // not a pushed route), so without this the native
                    // banner would keep auto-refreshing creatives behind
                    // an opaque scrim the player can't see or interact
                    // with.
                    child: BannerAdSlot(
                      isVisible: _isVisible && tourStep == null,
                    ),
                  ),
                ],
              ),
            ),
            if (tourStep != null)
              TourOverlay(
                key: _tourOverlayKey,
                step: kHomeTourSteps[tourStep],
                stepIndex: tourStep,
                stepCount: kHomeTourSteps.length,
                targetRect: _spotlightRect,
                closing: _tourClosing,
                onAdvance: _advanceTourStep,
                onSkip: _requestEndTour,
                onDismissed: _finishEndTour,
              ),
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({super.key, required this.streakCount});

  final int streakCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink, width: 2.5),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(0, 5), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DAILY STREAK',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.mute,
              letterSpacing: 0.04 * 9,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$streakCount ',
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.coral,
                  ),
                ),
                TextSpan(
                  text: streakCount == 1 ? 'day' : 'days',
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mute,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          StreakWeekBar(streakCount: streakCount),
        ],
      ),
    );
  }
}

/// Reuses Play Loop's pause-icon 28dp circular icon-button treatment
/// (design v3 §5.1's resolution of the mockup's missing gear icon).
class _SettingsIconButton extends StatelessWidget {
  const _SettingsIconButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Settings',
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.paper,
            border: Border.fromBorderSide(
              BorderSide(color: AppColors.ink, width: 2),
            ),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.settings, size: 14, color: AppColors.ink),
        ),
      ),
    );
  }
}
