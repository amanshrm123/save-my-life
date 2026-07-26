import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/core/routing/app_routes.dart';
import 'package:timing_tap/features/home/presentation/home_screen.dart';
import 'package:timing_tap/features/onboarding/presentation/onboarding_screen.dart';
import 'package:timing_tap/features/onboarding/presentation/splash_screen.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart';

Future<PreferencesService> _service(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  return PreferencesService.create();
}

Widget _app(PreferencesService service) {
  return ProviderScope(
    overrides: [preferencesServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.onboarding: (context) => const OnboardingScreen(),
        AppRoutes.home: (context) => const HomeScreen(),
      },
    ),
  );
}

void main() {
  testWidgets(
    'branches to OnboardingScreen when onboarding_complete is false',
    (tester) async {
      final service = await _service({});

      await tester.pumpWidget(_app(service));
      expect(find.byType(SplashScreen), findsOneWidget);

      // Advance past the full splash hold (progress animation + hold), then
      // let the resulting route-transition animation settle.
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(SplashScreen), findsNothing);
    },
  );

  testWidgets(
    'branches to HomeScreen when onboarding_complete is true',
    (tester) async {
      final service = await _service({kKeyOnboardingComplete: true});

      await tester.pumpWidget(_app(service));
      expect(find.byType(SplashScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(SplashScreen), findsNothing);
    },
  );

  testWidgets('splash is not back-navigable (pushReplacement, not push)', (
    tester,
  ) async {
    final service = await _service({});
    await tester.pumpWidget(_app(service));
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    // If splash had used push instead of pushReplacement, the onboarding
    // screen would be able to pop back to it. There should be nothing to
    // pop back to.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);
  });
}
