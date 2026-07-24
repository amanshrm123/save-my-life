import 'package:flutter/material.dart';

import 'core/routing/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/onboarding/presentation/splash_screen.dart';
import 'features/placeholder/placeholder_home_screen.dart';
import 'features/play_loop/presentation/play_loop_screen.dart';

/// Root `MaterialApp`: theme, initial route, and the (imperative,
/// no-routing-package) route table (architecture v1 §2, §7).
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stay Alive',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.onboarding: (context) => const OnboardingScreen(),
        AppRoutes.placeholderHome: (context) => const PlaceholderHomeScreen(),
        AppRoutes.play: (context) => const PlayLoopScreen(),
      },
    );
  }
}
