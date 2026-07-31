import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/features/avatar/presentation/widgets/avatar_figure.dart';
import 'package:timing_tap/features/avatar/presentation/widgets/home_avatar_card.dart';
import 'package:timing_tap/features/onboarding/domain/player_profile.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart';

/// Coverage scoped to `HomeAvatarCard` only (design `home-avatar-button-v2.md`
/// §5) -- the name "plate" it now renders below the figure (§1/§3) and the
/// press-down shadow-offset animation added on the existing card (§2). The
/// picker screen and Home's own navigation are unchanged by that spec, so
/// this file deliberately does not re-run `avatar_picker_flow_test.dart` or
/// the full Home smoke suite.
///
/// A never-completing/throwing `PlayerProfileNotifier` override is used for
/// the loading/error cases below rather than trying to race the real
/// `PreferencesService`-backed provider's microtask -- both hit the same
/// `orElse: () => '…'` branch of `HomeAvatarCard`'s fallback, so either is a
/// faithful stand-in for "not `AsyncData` yet".
void main() {
  // `container` lets the loading/error tests pass in their own
  // `PlayerProfileNotifier` override (built inline at the call site, so this
  // helper never has to spell out Riverpod's internal, unexported `Override`
  // type itself).
  Future<ProviderContainer> pumpCard(
    WidgetTester tester, {
    ProviderContainer? container,
    Map<String, Object> initialPrefs = const {},
    int avatarId = 0,
    int bestLifePercent = 45,
    VoidCallback? onTap,
  }) async {
    ProviderContainer resolvedContainer;
    if (container != null) {
      resolvedContainer = container;
    } else {
      SharedPreferences.setMockInitialValues(initialPrefs);
      final service = await PreferencesService.create();
      resolvedContainer = ProviderContainer(
        overrides: [preferencesServiceProvider.overrideWithValue(service)],
      );
    }
    addTearDown(resolvedContainer.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: resolvedContainer,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: HomeAvatarCard(
                avatarId: avatarId,
                bestLifePercent: bestLifePercent,
                onTap: onTap ?? _noop,
              ),
            ),
          ),
        ),
      ),
    );
    // A fixed manual pump (matching `presentation_smoke_test.dart`'s existing
    // convention for this widget) rather than `pumpAndSettle`: safe either
    // way given `AvatarFigure`'s fill tween is a bounded 320ms
    // `TweenAnimationBuilder`, but keeping the same pattern this widget's
    // other tests already use.
    await tester.pump(const Duration(milliseconds: 400));
    return resolvedContainer;
  }

  Finder cardContainer() => find.descendant(
    of: find.byType(HomeAvatarCard),
    matching: find.byType(Container),
  );

  double shadowOffsetOf(WidgetTester tester) {
    final container = tester.widget<Container>(cardContainer());
    final decoration = container.decoration as BoxDecoration;
    return decoration.boxShadow!.single.offset.dy;
  }

  testWidgets('named profile renders the name centered below the figure', (
    tester,
  ) async {
    await pumpCard(
      tester,
      initialPrefs: {kKeyPlayerName: 'Aman', kKeyOnboardingComplete: true},
    );

    final nameFinder = find.text('Aman');
    expect(nameFinder, findsOneWidget);

    final nameText = tester.widget<Text>(nameFinder);
    expect(nameText.textAlign, TextAlign.center);
    expect(nameText.maxLines, 1);
    expect(nameText.overflow, TextOverflow.ellipsis);

    // "below the figure" (v2 §1): the name's vertical position must sit
    // strictly below the figure's, not overlay it.
    final figureCenter = tester.getCenter(find.byType(AvatarFigure));
    final nameCenter = tester.getCenter(nameFinder);
    expect(nameCenter.dy, greaterThan(figureCenter.dy));

    // The "BEST LIFE"/"READY" microlabel is untouched -- still present,
    // still a distinct element from the new name line (v2 §0/§1).
    expect(find.text('BEST LIFE'), findsOneWidget);
  });

  testWidgets('anonymous profile (name never set) renders "Anonymous"', (
    tester,
  ) async {
    await pumpCard(
      tester,
    ); // no kKeyPlayerName seeded -> PlayerProfile.name == ''

    expect(find.text('Anonymous'), findsOneWidget);
    expect(find.text('Aman'), findsNothing);
  });

  testWidgets('profile stuck loading renders the "…" fallback', (tester) async {
    await pumpCard(
      tester,
      container: ProviderContainer(
        overrides: [
          playerProfileProvider.overrideWith(
            _NeverCompletingProfileNotifier.new,
          ),
        ],
      ),
    );

    expect(find.text('…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile in an error state renders the "…" fallback', (
    tester,
  ) async {
    await pumpCard(
      tester,
      container: ProviderContainer(
        // Riverpod auto-retries a failed `AsyncNotifier.build()` on a timer
        // by default; disabled here so no pending `Timer` outlives this
        // test (the retry behavior itself is orthogonal to what's under
        // test -- `HomeAvatarCard`'s AsyncError fallback rendering).
        retry: (retryCount, error) => null,
        overrides: [
          playerProfileProvider.overrideWith(_ThrowingProfileNotifier.new),
        ],
      ),
    );

    expect(find.text('…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long name truncates with ellipsis instead of overflowing', (
    tester,
  ) async {
    const longName = 'Maximilianus Constantinopolous';
    await pumpCard(
      tester,
      initialPrefs: {kKeyPlayerName: longName, kKeyOnboardingComplete: true},
    );

    // The `Text` widget's `data` always holds the full, untruncated string --
    // only its *rendering* is clipped to one line via `overflow`/`maxLines`
    // (v2 §1's "Long names" note) -- so this asserts the truncation
    // *mechanism* is wired up, and that laying it out never throws/overflows
    // (`RenderFlex`/text-overflow assertions would surface via
    // `tester.takeException()`).
    final nameFinder = find.text(longName);
    expect(nameFinder, findsOneWidget);
    final nameText = tester.widget<Text>(nameFinder);
    expect(nameText.maxLines, 1);
    expect(nameText.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tapDown drives the shadow offset from 4dp toward 1.5dp; tapUp animates it back to 4dp',
    (tester) async {
      await pumpCard(tester);
      expect(shadowOffsetOf(tester), closeTo(4, 0.01));

      final gesture = await tester.startGesture(
        tester.getCenter(cardContainer()),
      );
      await tester.pump();
      // Midway through the 90ms tap-down animation: already moved off rest,
      // not yet at the pressed extreme.
      await tester.pump(const Duration(milliseconds: 45));
      final midOffset = shadowOffsetOf(tester);
      expect(midOffset, lessThan(4));
      expect(midOffset, greaterThan(1.5));

      // Full 90ms elapsed (easeOut never overshoots) -- settled at pressed.
      await tester.pump(const Duration(milliseconds: 45));
      expect(shadowOffsetOf(tester), closeTo(1.5, 0.01));

      await gesture.up();
      await tester.pump();
      // Full 130ms tap-up animation elapsed -- back at rest.
      await tester.pump(const Duration(milliseconds: 130));
      expect(shadowOffsetOf(tester), closeTo(4, 0.01));
    },
  );

  testWidgets(
    'REGRESSION: the name plate updates live when playerProfileProvider '
    'changes while this card stays mounted — e.g. the player edits their '
    'name in Settings while Home (and this cached HomeAvatarCard) is still '
    'in the widget tree underneath, not rebuilt from scratch. Exercises the '
    'real cross-screen state-propagation path via `updateName`, not a '
    'fresh-pump-per-name shortcut.',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        kKeyPlayerName: 'Aman',
        kKeyOnboardingComplete: true,
      });
      final service = await PreferencesService.create();
      final container = ProviderContainer(
        overrides: [preferencesServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await pumpCard(tester, container: container);
      expect(find.text('Aman'), findsOneWidget);

      // Simulate Settings' "edit name" flow mutating the SAME resident
      // `playerProfileProvider` instance this still-mounted `HomeAvatarCard`
      // watches — no new `pumpWidget`/remount of the card itself, matching
      // what actually happens when Settings is pushed on top of Home rather
      // than replacing it.
      await container.read(playerProfileProvider.notifier).updateName('Zara');
      await tester.pump();

      expect(
        find.text('Zara'),
        findsOneWidget,
        reason: 'ref.watch(playerProfileProvider) must propagate the new name into the still-mounted card',
      );
      expect(find.text('Aman'), findsNothing, reason: 'the stale name must not linger after the update');
    },
  );

  testWidgets('tapCancel also animates the shadow back to 4dp', (tester) async {
    await pumpCard(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(cardContainer()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(shadowOffsetOf(tester), closeTo(1.5, 0.01));

    await gesture.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    expect(shadowOffsetOf(tester), closeTo(4, 0.01));
  });
}

void _noop() {}

/// Stands in for `AsyncLoading` -- `build()` returns a `Future` that never
/// resolves within a test's lifetime, so the provider stays in its initial
/// loading state for the whole test.
class _NeverCompletingProfileNotifier extends PlayerProfileNotifier {
  @override
  Future<PlayerProfile> build() => Completer<PlayerProfile>().future;
}

/// Stands in for `AsyncError` -- `build()` rejects, which the
/// `AsyncNotifier` framework surfaces as an `AsyncError` state rather than
/// letting the exception escape into the widget tree.
class _ThrowingProfileNotifier extends PlayerProfileNotifier {
  @override
  Future<PlayerProfile> build() async {
    throw Exception('boom');
  }
}
