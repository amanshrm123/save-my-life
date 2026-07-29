import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/core/routing/app_route_observer.dart';
import 'package:timing_tap/core/routing/app_routes.dart';
import 'package:timing_tap/features/avatar/presentation/avatar_picker_screen.dart';
import 'package:timing_tap/features/avatar/presentation/widgets/avatar_tile.dart';
import 'package:timing_tap/features/avatar/state/avatar_providers.dart';
import 'package:timing_tap/features/home/presentation/home_screen.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart';

/// Functional coverage for Home's avatar card (design `home-avatars-v1.md`
/// §2) and its real round-trip through the picker: the three render states,
/// and the draft-then-commit contract as seen from Home's own perspective
/// (committing in the picker must actually show up on Home after popping
/// back; staging without committing must not).
void main() {
  Future<ProviderContainer> pumpHome(WidgetTester tester, {Map<String, Object> initialPrefs = const {}}) async {
    // Realistic portrait viewport -- see `avatar_picker_flow_test.dart` for
    // why the default flutter_test canvas (800x600, landscape-shaped) isn't
    // representative here.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      // Neutral streak state -- neither the celebration nor the
      // streak-broken Home *state* should be showing, just the plain
      // dashboard body this feature actually touches.
      kKeyStreakCurrent: 0,
      kKeyStreakLastPlayDay: -1,
      kKeyReminderOptInShown: true,
      ...initialPrefs,
    });
    final service = await PreferencesService.create();
    final container = ProviderContainer(
      overrides: [preferencesServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorObservers: [appRouteObserver],
          initialRoute: AppRoutes.home,
          routes: {
            AppRoutes.home: (context) => const HomeScreen(),
            AppRoutes.avatarPicker: (context) => const AvatarPickerScreen(),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('unset avatar (-1) + zero bestLifePercent shows the hint chip and READY', (tester) async {
    await pumpHome(tester, initialPrefs: {kKeyBestLifePercent: 0});

    expect(find.textContaining('Pick your look'), findsOneWidget);
    expect(find.text('READY'), findsOneWidget);
    expect(find.text('BEST LIFE'), findsNothing);
  });

  testWidgets('a committed avatar with zero bestLifePercent shows READY, no hint chip', (tester) async {
    await pumpHome(tester, initialPrefs: {kKeyAvatarId: 4, kKeyBestLifePercent: 0});

    expect(find.text('READY'), findsOneWidget);
    expect(find.textContaining('Pick your look'), findsNothing);
  });

  testWidgets('a committed avatar with a normal (non-zero) bestLifePercent shows BEST LIFE, no hint chip, no READY', (tester) async {
    await pumpHome(tester, initialPrefs: {kKeyAvatarId: 4, kKeyBestLifePercent: 45});

    expect(find.text('BEST LIFE'), findsOneWidget);
    expect(find.text('READY'), findsNothing);
    expect(find.textContaining('Pick your look'), findsNothing);
  });

  testWidgets(
    'tapping the avatar card navigates to the picker; committing a new '
    'look and popping back updates Home\'s card',
    (tester) async {
      final container = await pumpHome(tester, initialPrefs: {kKeyAvatarId: -1, kKeyBestLifePercent: 0});

      expect(find.textContaining('Pick your look'), findsOneWidget);

      await tester.tap(find.text('READY')); // part of the avatar card's hit area
      await tester.pumpAndSettle();
      expect(find.byType(AvatarPickerScreen), findsOneWidget);

      final tile = tester.widgetList<AvatarTile>(find.byType(AvatarTile)).firstWhere((t) => t.spec.id == 2);
      await tester.tap(find.byWidget(tile));
      await tester.pump();
      await tester.tap(find.text('Use this avatar'));
      await tester.pumpAndSettle();

      expect(find.byType(AvatarPickerScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(container.read(selectedAvatarProvider), 2);
      expect(
        find.textContaining('Pick your look'),
        findsNothing,
        reason: 'a committed avatar must clear the never-picked hint on Home',
      );
    },
  );

  testWidgets(
    'staging a tile in the picker WITHOUT committing then popping back '
    'leaves Home showing the previously-committed avatar unchanged',
    (tester) async {
      final container = await pumpHome(tester, initialPrefs: {kKeyAvatarId: 1, kKeyBestLifePercent: 30});
      expect(find.textContaining('Pick your look'), findsNothing);

      await tester.tap(find.text('BEST LIFE'));
      await tester.pumpAndSettle();
      expect(find.byType(AvatarPickerScreen), findsOneWidget);

      final tile = tester.widgetList<AvatarTile>(find.byType(AvatarTile)).firstWhere((t) => t.spec.id == 5);
      await tester.tap(find.byWidget(tile));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        container.read(selectedAvatarProvider),
        1,
        reason: 'an uncommitted staged tap must never leak back into Home',
      );
    },
  );
}
