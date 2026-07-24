import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/core/routing/app_routes.dart';
import 'package:timing_tap/core/widgets/sticker_button.dart';
import 'package:timing_tap/features/onboarding/data/player_profile_repository.dart';
import 'package:timing_tap/features/onboarding/domain/player_profile.dart';
import 'package:timing_tap/features/onboarding/presentation/onboarding_screen.dart';
import 'package:timing_tap/features/onboarding/presentation/widgets/page_dots.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart';

/// A repository that always throws on the terminal write actions, to
/// simulate a platform-channel/prefs failure (bug #2 regression coverage).
/// `load()` is left intact (inherited) so the screen still builds normally.
class _ThrowingPlayerProfileRepository extends PlayerProfileRepository {
  _ThrowingPlayerProfileRepository(super.prefs);

  @override
  Future<PlayerProfile> completeWithName(String name) {
    throw Exception('simulated platform-channel failure');
  }

  @override
  Future<PlayerProfile> completeAnonymous() {
    throw Exception('simulated platform-channel failure');
  }
}

Future<PreferencesService> _service([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  return PreferencesService.create();
}

Widget _appWithOverrides(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      initialRoute: AppRoutes.onboarding,
      routes: {
        AppRoutes.onboarding: (context) => const OnboardingScreen(),
        AppRoutes.placeholderHome: (context) =>
            const Scaffold(body: Center(child: Text('placeholder-home'))),
      },
    ),
  );
}

Future<PreferencesService> _pumpOnboarding(
  WidgetTester tester, {
  List<Override> extraOverrides = const [],
}) async {
  final service = await _service();
  await tester.pumpWidget(
    _appWithOverrides([
      preferencesServiceProvider.overrideWithValue(service),
      ...extraOverrides,
    ]),
  );
  await tester.pumpAndSettle();
  return service;
}

Future<void> _tapButtonLabelled(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(StickerButton, label));
  await tester.pumpAndSettle();
}

void main() {
  group('OnboardingScreen - dot indicator', () {
    testWidgets('dots are shown on teach-card pages 0-2', (tester) async {
      await _pumpOnboarding(tester);

      expect(find.byType(PageDots), findsOneWidget);
      var dots = tester.widget<PageDots>(find.byType(PageDots));
      expect(dots.activeIndex, 0);

      await _tapButtonLabelled(tester, 'Next');
      dots = tester.widget<PageDots>(find.byType(PageDots));
      expect(dots.activeIndex, 1);

      await _tapButtonLabelled(tester, 'Next');
      dots = tester.widget<PageDots>(find.byType(PageDots));
      expect(dots.activeIndex, 2);
    });

    testWidgets('dots render nothing on the name-capture page (page 3)', (
      tester,
    ) async {
      await _pumpOnboarding(tester);

      await _tapButtonLabelled(tester, 'Next'); // -> page 1
      await _tapButtonLabelled(tester, 'Next'); // -> page 2
      await _tapButtonLabelled(tester, 'Got it'); // -> page 3 (name capture)

      expect(find.byType(PageDots), findsNothing);
    });
  });

  group('OnboardingScreen - button label progression', () {
    testWidgets(
      'labels progress Next -> Next -> Got it -> Start playing',
      (tester) async {
        await _pumpOnboarding(tester);
        expect(find.text('Next'), findsOneWidget);
        expect(find.text('Got it'), findsNothing);

        await _tapButtonLabelled(tester, 'Next');
        expect(find.text('Next'), findsOneWidget);

        await _tapButtonLabelled(tester, 'Next');
        expect(find.text('Got it'), findsOneWidget);

        await _tapButtonLabelled(tester, 'Got it');
        expect(find.text('Start playing'), findsOneWidget);
        expect(find.text('Skip for now'), findsOneWidget);
      },
    );
  });

  group('OnboardingScreen - swipe navigation', () {
    testWidgets('a manual left swipe advances the PageView by one page', (
      tester,
    ) async {
      await _pumpOnboarding(tester);

      var dots = tester.widget<PageDots>(find.byType(PageDots));
      expect(dots.activeIndex, 0);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 800);
      await tester.pumpAndSettle();

      dots = tester.widget<PageDots>(find.byType(PageDots));
      expect(dots.activeIndex, 1);
    });

    testWidgets('swipe-forward parity: swiping reaches the same page as '
        'tapping the button would', (tester) async {
      await _pumpOnboarding(tester);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 800);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 800);
      await tester.pumpAndSettle();

      expect(find.text('Got it'), findsOneWidget);
    });
  });

  group('OnboardingScreen - persistence contract', () {
    testWidgets(
      'onboarding_complete / player_name are NOT written while paging '
      'through the teach cards — only at the terminal Skip action',
      (tester) async {
        final service = await _pumpOnboarding(tester);

        expect(service.onboardingComplete, isFalse);
        expect(service.playerName, '');

        await _tapButtonLabelled(tester, 'Next'); // page 0 -> 1
        expect(service.onboardingComplete, isFalse);
        expect(service.playerName, '');

        await _tapButtonLabelled(tester, 'Next'); // page 1 -> 2
        expect(service.onboardingComplete, isFalse);
        expect(service.playerName, '');

        await _tapButtonLabelled(tester, 'Got it'); // page 2 -> 3 (name capture)
        expect(service.onboardingComplete, isFalse);
        expect(service.playerName, '');

        // Terminal action: only now should prefs be written.
        await tester.tap(find.text('Skip for now'));
        await tester.pumpAndSettle();

        expect(service.onboardingComplete, isTrue);
        expect(service.playerName, '');
        expect(find.text('placeholder-home'), findsOneWidget);
      },
    );

    testWidgets(
      'Start playing with a valid name writes both onboarding_complete and '
      'player_name only at that terminal tap',
      (tester) async {
        final service = await _pumpOnboarding(tester);

        await _tapButtonLabelled(tester, 'Next');
        await _tapButtonLabelled(tester, 'Next');
        await _tapButtonLabelled(tester, 'Got it');

        await tester.enterText(find.byType(TextField), 'Aman');
        await tester.pumpAndSettle();
        expect(service.onboardingComplete, isFalse);
        expect(service.playerName, '');

        await _tapButtonLabelled(tester, 'Start playing');

        expect(service.onboardingComplete, isTrue);
        expect(service.playerName, 'Aman');
        expect(find.text('placeholder-home'), findsOneWidget);
      },
    );
  });

  group(
    'OnboardingScreen - bug #2 regression: submit failure must not '
    'permanently disable the controls',
    () {
      testWidgets(
        'when the terminal prefs write throws, "Start playing" becomes '
        'interactive again (not stuck disabled) and a SnackBar is shown',
        (tester) async {
          final service = await _service();
          await tester.pumpWidget(
            _appWithOverrides([
              preferencesServiceProvider.overrideWithValue(service),
              playerProfileRepositoryProvider.overrideWithValue(
                _ThrowingPlayerProfileRepository(service),
              ),
            ]),
          );
          await tester.pumpAndSettle();

          await _tapButtonLabelled(tester, 'Next');
          await _tapButtonLabelled(tester, 'Next');
          await _tapButtonLabelled(tester, 'Got it');

          await tester.enterText(find.byType(TextField), 'Aman');
          await tester.pumpAndSettle();

          // Sanity: button is enabled before the failing tap.
          var button = tester.widget<StickerButton>(
            find.widgetWithText(StickerButton, 'Start playing'),
          );
          expect(button.enabled, isTrue);

          await tester.tap(find.widgetWithText(StickerButton, 'Start playing'));
          await tester.pump(); // let the async write fail and rebuild happen
          await tester.pumpAndSettle();

          // The write failed: we must NOT have navigated away.
          expect(find.byType(OnboardingScreen), findsOneWidget);
          expect(find.text('placeholder-home'), findsNothing);

          // A SnackBar should tell the player something went wrong.
          expect(find.text("Couldn't save that — try again."), findsOneWidget);

          // Regression check for bug #2: the button must be re-enabled, not
          // permanently stuck disabled.
          button = tester.widget<StickerButton>(
            find.widgetWithText(StickerButton, 'Start playing'),
          );
          expect(
            button.enabled,
            isTrue,
            reason:
                'Start playing must re-enable after a failed write, not '
                'stay disabled forever (bug #2 regression).',
          );

          // It must also be genuinely tappable again (not just enabled=true
          // with a null callback) — tap it a second time and confirm it
          // attempts the write again rather than silently no-op-ing.
          await tester.tap(find.widgetWithText(StickerButton, 'Start playing'));
          await tester.pump();
          await tester.pumpAndSettle();
          expect(find.text("Couldn't save that — try again."), findsOneWidget);
        },
      );

      testWidgets(
        '"Skip for now" also becomes interactive again after a failed write',
        (tester) async {
          final service = await _service();
          await tester.pumpWidget(
            _appWithOverrides([
              preferencesServiceProvider.overrideWithValue(service),
              playerProfileRepositoryProvider.overrideWithValue(
                _ThrowingPlayerProfileRepository(service),
              ),
            ]),
          );
          await tester.pumpAndSettle();

          await _tapButtonLabelled(tester, 'Next');
          await _tapButtonLabelled(tester, 'Next');
          await _tapButtonLabelled(tester, 'Got it');

          await tester.tap(find.text('Skip for now'));
          await tester.pump();
          await tester.pumpAndSettle();

          expect(find.byType(OnboardingScreen), findsOneWidget);

          final skipLink = tester.widget<GestureDetector>(
            find.ancestor(
              of: find.text('Skip for now'),
              matching: find.byType(GestureDetector),
            ),
          );
          expect(
            skipLink.onTap,
            isNotNull,
            reason:
                'Skip for now must re-enable after a failed write, not '
                'stay disabled forever (bug #2 regression).',
          );
        },
      );
    },
  );
}
