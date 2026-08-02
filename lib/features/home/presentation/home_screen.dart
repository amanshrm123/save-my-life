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
import '../../progression/domain/streak_calculator.dart';
import '../../progression/state/stats_providers.dart';
import '../../settings/state/settings_providers.dart';
import 'widgets/stat_tile.dart';
import 'widgets/streak_advanced_overlay.dart';
import 'widgets/streak_bar.dart';
import 'widgets/streak_broken_view.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    if (snap.justAdvanced) return;

    final today = _calculator.today();
    if (_calculator.isBrokenAtOpen(snap.streak, today)) return;

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

  void _goToPlay() => Navigator.of(context).pushNamed(AppRoutes.play);
  void _goToSettings() => Navigator.of(context).pushNamed(AppRoutes.settings);
  void _goToStats() => Navigator.of(context).pushNamed(AppRoutes.stats);
  void _goToAvatarPicker() => Navigator.of(context).pushNamed(AppRoutes.avatarPicker);

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(statsProvider);

    if (snap.justAdvanced) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(child: StreakAdvancedView(dayCount: snap.streak.count, onPlay: _goToPlay)),
      );
    }

    final today = _calculator.today();
    if (_calculator.isBrokenAtOpen(snap.streak, today)) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: StreakBrokenView(previousStreak: snap.streak.count, onStartNewStreak: _goToPlay),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      // Restructured for the banner footer slot (real-ad-serving pass,
      // game-ux-designer spec): the existing dashboard content sits in an
      // `Expanded` above the slot, and the slot itself sits outside that
      // `Expanded`, at the very bottom, in its OWN `SafeArea(top: false)` so
      // it alone owns the bottom nav-inset (the content `SafeArea` above
      // skips its own bottom inset accordingly, via `bottom: false`, to
      // avoid double-padding).
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 14,
                  // 8dp gap between the Play button and the banner slot's
                  // top edge (game-ux-designer spec) — down from the
                  // original 14 now that the slot itself sits right below.
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
                              style: AppTypography.wordmark.copyWith(fontSize: 26, height: 0.9),
                              children: const [
                                TextSpan(text: 'Stay '),
                                TextSpan(text: 'Alive', style: TextStyle(color: AppColors.coral)),
                              ],
                            ),
                          ),
                        ),
                        _SettingsIconButton(onPressed: _goToSettings),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      kAppTagline,
                      style: AppTypography.body,
                    ),
                    const SizedBox(height: 14),
                    _StreakCard(streakCount: snap.streak.count),
                    const SizedBox(height: 12),
                    Row(
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
          SafeArea(top: false, child: BannerAdSlot(isVisible: _isVisible)),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streakCount});

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
        boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(0, 5), blurRadius: 0)],
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
  const _SettingsIconButton({required this.onPressed});

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
            border: Border.fromBorderSide(BorderSide(color: AppColors.ink, width: 2)),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.settings, size: 14, color: AppColors.ink),
        ),
      ),
    );
  }
}
