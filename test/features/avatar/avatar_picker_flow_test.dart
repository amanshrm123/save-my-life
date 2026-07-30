import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/features/avatar/data/avatar_repository.dart';
import 'package:timing_tap/features/avatar/presentation/avatar_picker_screen.dart';
import 'package:timing_tap/features/avatar/presentation/widgets/avatar_tile.dart';
import 'package:timing_tap/features/avatar/state/avatar_providers.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart';

/// Functional coverage for `AvatarPickerScreen`'s draft-then-commit contract
/// (design `home-avatars-v1.md` §5.4): grid taps only ever stage a local
/// selection; only the CTA persists it. Also covers the re-entrancy guard on
/// that CTA and the picker's `initState` clamping of an out-of-range/absent
/// persisted `avatar_id`.
void main() {
  Future<ProviderContainer> pumpPicker(
    WidgetTester tester, {
    Map<String, Object> initialPrefs = const {},
    List<Override> Function(PreferencesService service)? overridesBuilder,
  }) async {
    // A realistic portrait phone viewport -- the default flutter_test canvas
    // (800x600, landscape-shaped) is narrower-than-tall, which spreads the
    // 3-column grid's tiles wide enough that a 2-row catalog no longer fits
    // the screen and genuinely scrolls, making row-2 tiles unreachable by a
    // plain `tester.tap` (its derived offset lands on whatever is really
    // painted at that screen position instead, e.g. the CTA button below).
    // Every real device this ships to is portrait, so this is the
    // representative shape for exercising taps against every grid tile.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(initialPrefs);
    final service = await PreferencesService.create();
    final container = ProviderContainer(
      overrides: [
        preferencesServiceProvider.overrideWithValue(service),
        ...?overridesBuilder?.call(service),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AvatarPickerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  List<AvatarTile> tilesInGrid(WidgetTester tester) {
    return tester.widgetList<AvatarTile>(find.byType(AvatarTile)).toList();
  }

  testWidgets(
    'tapping a tile then "Use this avatar" persists the id and updates '
    'selectedAvatarProvider',
    (tester) async {
      final container = await pumpPicker(tester, initialPrefs: {kKeyAvatarId: 0});
      expect(container.read(selectedAvatarProvider), 0);

      // Stage tile id 3 (4th male tile).
      final tileToTap = tilesInGrid(tester).firstWhere((t) => t.spec.id == 3);
      await tester.tap(find.byWidget(tileToTap));
      await tester.pump();

      // Still uncommitted at this point.
      expect(container.read(selectedAvatarProvider), 0);

      await tester.tap(find.text('Use this avatar'));
      await tester.pumpAndSettle();

      expect(container.read(selectedAvatarProvider), 3);
      expect(
        PreferencesService(await SharedPreferences.getInstance()).avatarId,
        3,
        reason: 'the commit must write through to prefs, not just RAM',
      );
      // The CTA pops the picker once committed.
      expect(find.byType(AvatarPickerScreen), findsNothing);
    },
  );

  testWidgets(
    'tapping a tile WITHOUT committing then popping back leaves the '
    'previously-committed selection unchanged (draft-then-commit)',
    (tester) async {
      final container = await pumpPicker(tester, initialPrefs: {kKeyAvatarId: 1});
      expect(container.read(selectedAvatarProvider), 1);

      final tileToTap = tilesInGrid(tester).firstWhere((t) => t.spec.id == 4);
      await tester.tap(find.byWidget(tileToTap));
      await tester.pumpAndSettle();

      // Pop via the header's back chevron instead of the CTA.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(
        container.read(selectedAvatarProvider),
        1,
        reason: 'a staged-but-uncommitted tap must never leak into the '
            'committed provider value',
      );
      expect(
        PreferencesService(await SharedPreferences.getInstance()).avatarId,
        1,
        reason: 'prefs must also be untouched by an uncommitted tap',
      );
    },
  );

  testWidgets(
    'double-tapping "Use this avatar" back-to-back commits exactly once '
    '(re-entrancy guard)',
    (tester) async {
      late _CountingAvatarRepository fakeRepo;
      final container = await pumpPicker(
        tester,
        initialPrefs: {kKeyAvatarId: 0},
        overridesBuilder: (service) {
          fakeRepo = _CountingAvatarRepository(service);
          return [avatarRepositoryProvider.overrideWithValue(fakeRepo)];
        },
      );

      final tileToTap = tilesInGrid(tester).firstWhere((t) => t.spec.id == 2);
      await tester.tap(find.byWidget(tileToTap));
      await tester.pump();

      final cta = find.text('Use this avatar');
      // Two taps back-to-back with no pump in between -- the second call
      // must hit the `_committing` guard synchronously, before the first
      // commit's artificially-delayed write ever resolves.
      await tester.tap(cta);
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(
        fakeRepo.callCount,
        1,
        reason: 'a double-tap on the commit CTA must only persist once',
      );
      expect(container.read(selectedAvatarProvider), 2);
    },
  );

  testWidgets(
    'gender toggle switches the visible grid between the two 6-tile sets',
    (tester) async {
      await pumpPicker(tester);

      expect(
        tilesInGrid(tester).map((t) => t.spec.id).toList(),
        [0, 1, 2, 3, 4, 5],
        reason: 'default/fallback selection is male; grid should start on '
            'the male 6',
      );

      await tester.tap(find.text('Female'));
      await tester.pumpAndSettle();

      expect(tilesInGrid(tester).map((t) => t.spec.id).toList(), [6, 7, 8, 9, 10, 11]);
      // §5.2: switching gender must also reset the staged selection -- no
      // tile in the new grid should show as selected, and the CTA should be
      // disabled again.
      expect(tilesInGrid(tester).any((t) => t.selected), isFalse);

      await tester.tap(find.text('Male'));
      await tester.pumpAndSettle();
      expect(tilesInGrid(tester).map((t) => t.spec.id).toList(), [0, 1, 2, 3, 4, 5]);
    },
  );

  testWidgets(
    'an out-of-range persisted avatar_id is clamped to the fallback, not '
    'carried into the picker raw',
    (tester) async {
      await pumpPicker(tester, initialPrefs: {kKeyAvatarId: 999});

      // Fallback is male id 0 -- grid should start on Male with tile 0
      // pre-selected.
      final tiles = tilesInGrid(tester);
      expect(tiles.map((t) => t.spec.id).toList(), [0, 1, 2, 3, 4, 5]);
      expect(tiles.firstWhere((t) => t.spec.id == 0).selected, isTrue);
      expect(tiles.where((t) => t.selected).length, 1);
    },
  );

  testWidgets(
    'the never-picked sentinel (-1) also clamps to the fallback on open',
    (tester) async {
      await pumpPicker(tester); // no kKeyAvatarId written -> defaults to -1

      final tiles = tilesInGrid(tester);
      expect(tiles.map((t) => t.spec.id).toList(), [0, 1, 2, 3, 4, 5]);
      expect(tiles.firstWhere((t) => t.spec.id == 0).selected, isTrue);
    },
  );
}

class _CountingAvatarRepository extends AvatarRepository {
  _CountingAvatarRepository(super.prefs);

  int callCount = 0;
  int? lastId;

  @override
  Future<void> setAvatarId(int id) async {
    callCount++;
    lastId = id;
    // Widens the async race window a real double-tap could otherwise slip
    // through, so this test would actually catch a missing/broken guard
    // instead of passing by timing luck.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await super.setAvatarId(id);
  }
}
