import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/ad_config.dart';
import '../state/ad_providers.dart';

/// The Home footer banner slot (real-ad-serving pass, game-ux-designer
/// spec). Fixed, ALWAYS-reserved 54dp total height — never
/// `SizedBox.shrink()` — whether the AppLovin SDK isn't configured at all,
/// the banner ad unit ID dart-define is unset, the SDK hasn't finished
/// initializing yet, or (once all of that has settled) the native ad simply
/// hasn't rendered anything into its platform view yet. Flat, quiet footer
/// chrome (`AppColors.paper2` background, 1px `AppColors.dotInactive` top
/// hairline, no border/shadow) deliberately does NOT read as a sticker-book
/// button/card, unlike this app's other chrome.
///
/// Memory-safety (CLAUDE.md rule 7): this widget does not implement its own
/// `dispose()` for the ad view, because [MaxAdView] is backed by a real
/// `AndroidView`/`UiKitView` platform view — Flutter's own widget lifecycle
/// already tears down that native view automatically when the widget is
/// removed from the tree (inside `MaxAdView`'s own `State`), the same way
/// any other platform-view-backed widget is torn down. This deliberately
/// does NOT use the SDK's imperative `preloadWidgetAdView`/
/// `destroyWidgetAdView` API (that's for pre-warming an ad ahead of the
/// widget mounting, not needed for a single always-mounted footer slot),
/// which is the API that *would* require an explicit destroy call in
/// `dispose()`.
class BannerAdSlot extends ConsumerWidget {
  const BannerAdSlot({super.key, this.isVisible = true});

  /// Total reserved height, including the 1px top hairline divider.
  static const double kHeight = 54;

  /// Whether Home (the only screen that mounts this slot) is the current,
  /// actually-visible route right now — threaded straight from
  /// `HomeScreen._isVisible` (its existing `RouteAware` visibility tracking,
  /// already used for the reminder-prompt/streak logic). Drives
  /// `MaxAdView.isAutoRefreshEnabled` (fix 7, real-ad-serving pass review):
  /// `HomeScreen` stays mounted-but-covered under `PlayLoopScreen`/
  /// `OutcomeCardScreen` for the whole run (it's reached via
  /// `pushReplacement` chains that never pop it off the Navigator), so
  /// without this the native banner would keep auto-refreshing creatives
  /// every ~30s while completely invisible — wasted native
  /// memory/network for a RAM-resident app (CLAUDE.md rule 7), and exactly
  /// the "impressions on an unviewable ad" pattern ad networks flag as
  /// invalid traffic.
  ///
  /// Confirmed against the `applovin_max` package's own source
  /// (`max_ad_view.dart`'s `_MaxAdViewState.didUpdateWidget`): toggling this
  /// prop across a rebuild calls the platform view's `startAutoRefresh`/
  /// `stopAutoRefresh` method channel directly — it does NOT tear down and
  /// recreate the underlying native ad view (that only happens via the
  /// `isAdaptiveBannerEnabled`/creation-params path, not this one), so
  /// pausing/resuming here never triggers a fresh ad load the way a full
  /// remount would.
  final bool isVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Banner and interstitial ad units are configured independently
    // (ad_config.dart's `kAdsConfigured` doc comment) — a build could have
    // an SDK key + interstitial unit but no banner unit at all, which must
    // permanently fall back to the placeholder rather than ever attempting
    // to create a banner with an empty ad unit ID string.
    final configured = kAdsConfigured && kAppLovinBannerUnitId.isNotEmpty;
    // Only reads `adSdkReadyProvider` when actually configured — an
    // unconfigured build never touches the ad-network provider chain at
    // all, matching this slot's existing "never call into the SDK with an
    // empty ad unit ID" convention.
    final sdkReady = configured && ref.watch(adSdkReadyProvider).hasValue;
    final showAd = configured && sdkReady;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.paper2,
        border: Border(
          top: BorderSide(color: AppColors.dotInactive, width: 1),
        ),
      ),
      child: SizedBox(
        height: kHeight,
        width: double.infinity,
        child: showAd
            ? MaxAdView(
                adUnitId: kAppLovinBannerUnitId,
                adFormat: AdFormat.banner,
                // Explicit, non-adaptive sizing: this slot's height is a
                // fixed 54dp by design (1dp of which is the top divider),
                // so an adaptive banner — which can size taller on some
                // devices/widths — is deliberately turned off here rather
                // than risking an overflow of this permanently-reserved
                // footer strip.
                isAdaptiveBannerEnabled: false,
                // `MediaQuery.sizeOf` (not the old ambient `MediaQuery.of`)
                // is aspect-scoped (see Flutter's own `_MediaQueryAspect`
                // mechanism): this widget only rebuilds when the actual
                // device *size* changes (a real rotation/window resize),
                // never on an unrelated MediaQuery change elsewhere (text
                // scale, keyboard inset, padding, ...) — so this read is
                // NOT the source of excess rebuild/reload churn. That
                // churn, if it happens, comes from inside `MaxAdView`
                // itself: its own `_MaxAdViewState.build()` reads the
                // full, un-scoped `MediaQuery.of(context).size` and pairs
                // that with a `FutureBuilder` whose `future` is
                // recomputed fresh on every rebuild — briefly returning to
                // `ConnectionState.waiting` (which unmounts the platform
                // view) before resolving again (remounting it, issuing a
                // fresh ad load). That's package-internal behavior, not
                // fixable from this file — confirmed by reading
                // `max_ad_view.dart` directly rather than assumed.
                width: MediaQuery.sizeOf(context).width,
                // Matches the outer `SizedBox`'s own `kHeight` exactly —
                // this used to (incorrectly) pass `kHeight - 1`, but the
                // outer `SizedBox(height: kHeight)` above already imposes a
                // TIGHT height constraint on this whole subtree, so any
                // value passed here gets clamped back to `kHeight` by
                // layout regardless (an `OverflowBox` sits between this and
                // the platform view, but with no explicit min/maxHeight
                // override it passes its incoming constraints straight
                // through rather than truly relaxing them). The `- 1` was
                // dead: it had zero effect on the actual rendered size.
                height: kHeight,
                isAutoRefreshEnabled: isVisible,
              )
            // The native MaxAdView platform view supplies its own
            // semantics once mounted, so it's deliberately NOT wrapped in
            // ExcludeSemantics the way this empty placeholder is (mirrors
            // AdFailedView's `excludeSemantics` convention: a decorative
            // empty box has nothing a screen reader should announce).
            : const ExcludeSemantics(child: SizedBox.shrink()),
      ),
    );
  }
}
