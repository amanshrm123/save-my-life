import 'package:flutter/widgets.dart';

import '../features/onboarding/onboarding_flow.dart';
import '../features/run/play_screen.dart';

/// The one routing decision `SplashScreen` makes once its real init work
/// resolves (docs/design/onboarding-flow-v1.md §3.3): first launch
/// (`isOnboardingComplete == false`) goes into onboarding; every launch
/// after that is meant to land on Home (screen-library §6.1).
///
/// ---
/// **TEMPORARY SHIM — Home does not exist yet.** Home/Stats/streak-broken
/// (6.1-6.3) are explicitly out of scope for `onboarding-flow-v1.md` (see
/// its §0) and have not been built in this codebase. Until Home is built,
/// every returning-launch path lands on [PlayScreen] instead. This is the
/// single, marked hand-off point: once Home exists, replace the
/// `PlayScreen()` return below with Home and delete this comment block —
/// nothing else in the onboarding flow needs to change.
/// ---
Widget routeAfterSplash({required bool isOnboardingComplete}) {
  if (isOnboardingComplete) {
    // TODO(home): swap for Home once it's built (see shim note above).
    return const PlayScreen();
  }
  return const OnboardingFlow();
}
