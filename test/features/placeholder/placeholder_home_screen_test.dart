import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/core/routing/app_routes.dart';
import 'package:timing_tap/core/widgets/sticker_button.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart';
import 'package:timing_tap/features/placeholder/placeholder_home_screen.dart';
import 'package:timing_tap/features/play_loop/presentation/play_loop_screen.dart';

/// Architecture v2 §8: `PlaceholderHomeScreen`'s new "Play" button is the
/// entry point into the whole Play Loop feature — this fixes what was
/// previously a dead end.
void main() {
  Future<PreferencesService> service([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    return PreferencesService.create();
  }

  Widget app(PreferencesService svc) {
    return ProviderScope(
      overrides: [preferencesServiceProvider.overrideWithValue(svc)],
      child: MaterialApp(
        initialRoute: AppRoutes.placeholderHome,
        routes: {
          AppRoutes.placeholderHome: (context) => const PlaceholderHomeScreen(),
          AppRoutes.play: (context) => const PlayLoopScreen(),
        },
      ),
    );
  }

  testWidgets('tapping "Play" navigates to PlayLoopScreen via AppRoutes.play', (
    tester,
  ) async {
    final svc = await service({kKeyOnboardingComplete: true, kKeyPlayerName: 'Aman'});
    await tester.pumpWidget(app(svc));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceholderHomeScreen), findsOneWidget);
    expect(find.widgetWithText(StickerButton, 'Play'), findsOneWidget);

    await tester.tap(find.widgetWithText(StickerButton, 'Play'));
    await tester.pumpAndSettle();

    expect(find.byType(PlayLoopScreen), findsOneWidget);
    expect(find.byType(PlaceholderHomeScreen), findsNothing);

    // Flush the countdown's internal `Future.delayed` timers before the test
    // ends — otherwise the test framework's "no pending timers" invariant
    // fails even though the timers are harmlessly `mounted`-guarded.
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pumpAndSettle();
  });

  testWidgets('the anonymous greeting still renders correctly alongside the '
      'new Play button (no regression to existing Home content)', (tester) async {
    final svc = await service();
    await tester.pumpWidget(app(svc));
    await tester.pumpAndSettle();

    expect(find.text("You're in"), findsOneWidget);
    expect(find.widgetWithText(StickerButton, 'Play'), findsOneWidget);
  });
}
