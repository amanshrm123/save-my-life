import 'package:flutter/material.dart';

import 'core/routing/app_route_observer.dart';
import 'core/routing/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/avatar/presentation/avatar_picker_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/home/presentation/stats_screen.dart';
import 'features/notifications/presentation/reminder_opt_in_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/onboarding/presentation/splash_screen.dart';
import 'features/play_loop/presentation/play_loop_screen.dart';
import 'features/settings/presentation/settings_screen.dart';

/// Root `MaterialApp`: theme, initial route, and the (imperative,
/// no-routing-package) route table (architecture v1 §2, §7; v3 §9).
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stay Alive',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      navigatorObservers: [appRouteObserver],
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.onboarding: (context) => const OnboardingScreen(),
        AppRoutes.home: (context) => const HomeScreen(),
        AppRoutes.play: (context) => const PlayLoopScreen(),
        AppRoutes.settings: (context) => const SettingsScreen(),
        AppRoutes.stats: (context) => const StatsScreen(),
        AppRoutes.reminderOptIn: (context) => const ReminderOptInScreen(),
        AppRoutes.avatarPicker: (context) => const AvatarPickerScreen(),
      },
    );
  }
}
