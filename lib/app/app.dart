import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import 'splash_screen.dart';

// Re-exported for backward compatibility with existing test/production
// imports that reach `PlayScreen`/`tapFlashColorProvider` via `app/app.dart`
// — the widgets themselves now live in `features/run/play_screen.dart`
// (moved out so `router.dart`/onboarding screens can reach `PlayScreen`
// without importing this file and creating an import cycle).
export '../features/run/play_screen.dart';

/// Root widget: `ProviderScope` + [AppShell]. Kept as a separate wrapper
/// (rather than folding `ProviderScope` directly into [AppShell]) so a
/// widget test can instead wrap [AppShell] in its own
/// `UncontrolledProviderScope`/`ProviderContainer` with
/// `profileRepositoryProvider`/`nameValidatorProvider`/`clockProvider`
/// overridden — the same seam-via-Riverpod-overrides pattern used
/// throughout this codebase's tests (architecture v1 §1.3) — without
/// [App]'s own `ProviderScope` shadowing those overrides.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: AppShell());
  }
}

/// Every launch — first or returning — starts at [SplashScreen]
/// (docs/design/onboarding-flow-v1.md §3.2); it decides whether to route
/// into onboarding or (today, via a temporary shim) Play — see
/// `router.dart`.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Timing Tap',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SplashScreen(),
    );
  }
}
