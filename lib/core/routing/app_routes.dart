/// Route-name constants for the app's plain `Navigator` (no routing package
/// in v1 — see architecture v1 §2). Kept centralised so a future migration
/// to `go_router` has a ready-made set of route names to reuse.
library;

class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String play = '/play';
  static const String settings = '/settings';
  static const String stats = '/stats';
  static const String reminderOptIn = '/reminder-opt-in';
}
