import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/core/routing/app_routes.dart';
import 'package:timing_tap/core/widgets/sticker_button.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart';
import 'package:timing_tap/features/placeholder/placeholder_home_screen.dart';
import 'package:timing_tap/features/placeholder/placeholder_outcome_screen.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/presentation/play_loop_screen.dart';

/// Architecture v2 §8: the genuinely-working handoff for a finished run —
/// shows which of death/survived/eternal occurred, with "Again"/"Home".
void main() {
  Future<PreferencesService> service([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    return PreferencesService.create();
  }

  Widget appPushingOutcome(PreferencesService svc, RunOutcome outcome) {
    return ProviderScope(
      overrides: [preferencesServiceProvider.overrideWithValue(svc)],
      child: MaterialApp(
        initialRoute: AppRoutes.placeholderHome,
        routes: {
          AppRoutes.placeholderHome: (context) => const PlaceholderHomeScreen(),
          AppRoutes.play: (context) => const PlayLoopScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/outcome-under-test') {
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => PlaceholderOutcomeScreen(outcome: outcome),
            );
          }
          return null;
        },
      ),
    );
  }

  Future<void> pushOutcomeScreen(WidgetTester tester) async {
    final context = tester.element(find.byType(PlaceholderHomeScreen));
    Navigator.of(context).pushNamed('/outcome-under-test');
    await tester.pumpAndSettle();
  }

  const cases = {
    RunOutcome.death: ('DEATH', "That's a wipe."),
    RunOutcome.survived: ('SURVIVED', 'One clean stop saved you.'),
    RunOutcome.eternal: ('ETERNAL', 'Three perfects, cold.'),
  };

  for (final entry in cases.entries) {
    testWidgets('shows the ${entry.key.name} badge and headline', (tester) async {
      final svc = await service();
      await tester.pumpWidget(appPushingOutcome(svc, entry.key));
      await tester.pumpAndSettle();
      await pushOutcomeScreen(tester);

      expect(find.text(entry.value.$1), findsOneWidget);
      expect(find.text(entry.value.$2), findsOneWidget);
    });
  }

  testWidgets('"Again" pushReplacements to a fresh PlayLoopScreen', (tester) async {
    final svc = await service();
    await tester.pumpWidget(appPushingOutcome(svc, RunOutcome.death));
    await tester.pumpAndSettle();
    await pushOutcomeScreen(tester);

    await tester.tap(find.widgetWithText(StickerButton, 'Again'));
    await tester.pumpAndSettle();

    expect(find.byType(PlayLoopScreen), findsOneWidget);
    expect(find.byType(PlaceholderOutcomeScreen), findsNothing);

    // Flush the fresh run's countdown timers before the test ends — see
    // the matching comment in placeholder_home_screen_test.dart.
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pumpAndSettle();
  });

  testWidgets('"Home" pops back to PlaceholderHomeScreen', (tester) async {
    final svc = await service();
    await tester.pumpWidget(appPushingOutcome(svc, RunOutcome.survived));
    await tester.pumpAndSettle();
    await pushOutcomeScreen(tester);

    await tester.tap(find.widgetWithText(StickerButton, 'Home'));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceholderHomeScreen), findsOneWidget);
    expect(find.byType(PlaceholderOutcomeScreen), findsNothing);
  });
}
