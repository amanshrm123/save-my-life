import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/features/outcome/application/story_cycle_store.dart';
import 'package:timing_tap/features/outcome/domain/story_beat.dart';
import 'package:timing_tap/features/outcome/domain/story_pool.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';

/// Coverage for `StoryCycleStore` (remote-story-config-implementation-spec
/// §2.5 / §9.2).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PreferencesService> buildPrefs(
    Map<String, Object> initialValues,
  ) async {
    SharedPreferences.setMockInitialValues(initialValues);
    return PreferencesService.create();
  }

  StoryBeat beat(String id) =>
      StoryBeat(id: id, headline: 'H', named: '{name} n', anonymous: 'a');

  StoryPool poolWith({
    required List<String> deathIds,
    required List<String> survivedIds,
    required List<String> eternalIds,
  }) {
    return StoryPool(
      contentVersion: 1,
      death: StoryTierPool(
        beats: deathIds.map(beat).toList(),
        icons: const ['💀'],
      ),
      survived: StoryTierPool(
        beats: survivedIds.map(beat).toList(),
        icons: const ['🆘'],
      ),
      eternal: StoryTierPool(
        beats: eternalIds.map(beat).toList(),
        icons: const ['✨'],
      ),
    );
  }

  group('hydration', () {
    test(
      'constructor reads all six keys; absent keys default to {} / \'\'',
      () async {
        final prefs = await buildPrefs({});
        final store = StoryCycleStore(prefs);

        expect(store.seenFor(RunOutcome.death), isEmpty);
        expect(store.seenFor(RunOutcome.survived), isEmpty);
        expect(store.seenFor(RunOutcome.eternal), isEmpty);
        expect(store.lastShownFor(RunOutcome.death), '');
        expect(store.lastShownFor(RunOutcome.survived), '');
        expect(store.lastShownFor(RunOutcome.eternal), '');
      },
    );

    test('constructor reads previously-persisted values', () async {
      final prefs = await buildPrefs({
        kKeySeenStoryIdsDeath: ['death_001', 'death_002'],
        kKeyLastStoryIdDeath: 'death_002',
      });
      final store = StoryCycleStore(prefs);

      expect(store.seenFor(RunOutcome.death), {'death_001', 'death_002'});
      expect(store.lastShownFor(RunOutcome.death), 'death_002');
    });
  });

  group('write-through', () {
    test('record updates memory synchronously and prefs eventually', () async {
      final prefs = await buildPrefs({});
      final store = StoryCycleStore(prefs);

      // In production, `StoryCycleSelector.pick` mutates the live Set
      // returned by `seenFor` in place before the caller invokes `record`.
      // Simulate that hand-off here.
      store.seenFor(RunOutcome.death).add('death_005');
      store.record(RunOutcome.death, 'death_005');

      expect(store.seenFor(RunOutcome.death), contains('death_005'));
      expect(store.lastShownFor(RunOutcome.death), 'death_005');

      // Let the unawaited prefs writes land.
      await Future<void>.delayed(Duration.zero);
      expect(prefs.seenStoryIdsDeath, contains('death_005'));
      expect(prefs.lastStoryIdDeath, 'death_005');
    });

    test('record only touches the given tier', () async {
      final prefs = await buildPrefs({});
      final store = StoryCycleStore(prefs);

      store.seenFor(RunOutcome.survived).add('survived_001');
      store.record(RunOutcome.survived, 'survived_001');

      expect(store.seenFor(RunOutcome.death), isEmpty);
      expect(store.seenFor(RunOutcome.eternal), isEmpty);
      expect(store.seenFor(RunOutcome.survived), {'survived_001'});
    });

    // NEW: adversarial cross-tier concurrency check. The single-call test
    // above proves one `record()` doesn't touch other tiers; this proves
    // RAPID INTERLEAVED calls across all three tiers -- even reusing the
    // exact same ID string per tier, which a naive shared-Set bug would
    // conflate -- never cross-contaminate each tier's independent seen-set
    // or lastShown pointer.
    test('rapid interleaved record() calls across all three tiers, even '
        'reusing the SAME id string per tier, never cross-contaminate '
        'seen-sets or lastShown', () async {
      final prefs = await buildPrefs({});
      final store = StoryCycleStore(prefs);

      for (final id in ['shared_001', 'shared_002', 'shared_003']) {
        store.seenFor(RunOutcome.death).add(id);
        store.record(RunOutcome.death, id);
        store.seenFor(RunOutcome.survived).add(id);
        store.record(RunOutcome.survived, id);
        store.seenFor(RunOutcome.eternal).add(id);
        store.record(RunOutcome.eternal, id);
      }

      const expectedShared = {'shared_001', 'shared_002', 'shared_003'};
      expect(store.seenFor(RunOutcome.death), expectedShared);
      expect(store.seenFor(RunOutcome.survived), expectedShared);
      expect(store.seenFor(RunOutcome.eternal), expectedShared);
      expect(store.lastShownFor(RunOutcome.death), 'shared_003');
      expect(store.lastShownFor(RunOutcome.survived), 'shared_003');
      expect(store.lastShownFor(RunOutcome.eternal), 'shared_003');

      await Future<void>.delayed(Duration.zero);
      expect(prefs.seenStoryIdsDeath.toSet(), expectedShared);
      expect(prefs.seenStoryIdsSurvived.toSet(), expectedShared);
      expect(prefs.seenStoryIdsEternal.toSet(), expectedShared);

      // Definitive cross-contamination check: a tier-exclusive ID recorded
      // afterwards must not leak into the other two tiers' in-memory sets.
      store.seenFor(RunOutcome.death).add('death_only');
      store.record(RunOutcome.death, 'death_only');
      expect(store.seenFor(RunOutcome.death), contains('death_only'));
      expect(store.seenFor(RunOutcome.survived), isNot(contains('death_only')));
      expect(store.seenFor(RunOutcome.eternal), isNot(contains('death_only')));
      expect(store.lastShownFor(RunOutcome.survived), 'shared_003');
      expect(store.lastShownFor(RunOutcome.eternal), 'shared_003');
    });
  });

  group('pruneAgainst', () {
    test('stale-ID pruning: seen IDs absent from the live pool are dropped, '
        'and the pruned value is persisted', () async {
      final prefs = await buildPrefs({
        kKeySeenStoryIdsDeath: [
          'death_001',
          'death_002',
          'stale_a',
          'stale_b',
          'stale_c',
        ],
      });
      final store = StoryCycleStore(prefs);
      final pool = poolWith(
        deathIds: ['death_001', 'death_002', 'death_003'],
        survivedIds: ['survived_001'],
        eternalIds: ['eternal_001'],
      );

      store.pruneAgainst(pool);

      expect(store.seenFor(RunOutcome.death), {'death_001', 'death_002'});
      await Future<void>.delayed(Duration.zero);
      expect(prefs.seenStoryIdsDeath.toSet(), {'death_001', 'death_002'});
    });

    test('clears a dead lastShownId', () async {
      final prefs = await buildPrefs({kKeyLastStoryIdDeath: 'removed_beat'});
      final store = StoryCycleStore(prefs);
      final pool = poolWith(
        deathIds: ['death_001'],
        survivedIds: ['survived_001'],
        eternalIds: ['eternal_001'],
      );

      store.pruneAgainst(pool);

      expect(store.lastShownFor(RunOutcome.death), '');
      await Future<void>.delayed(Duration.zero);
      expect(prefs.lastStoryIdDeath, '');
    });

    test('a live lastShownId survives pruning untouched', () async {
      final prefs = await buildPrefs({kKeyLastStoryIdDeath: 'death_001'});
      final store = StoryCycleStore(prefs);
      final pool = poolWith(
        deathIds: ['death_001'],
        survivedIds: ['survived_001'],
        eternalIds: ['eternal_001'],
      );

      store.pruneAgainst(pool);

      expect(store.lastShownFor(RunOutcome.death), 'death_001');
    });

    // NEW: a single pruneAgainst call is proven correct above; this proves
    // the seen-set stays correct across MULTIPLE successive prune cycles
    // against pools that shrink and then grow -- not just after the first
    // call. Guards against a bug where pruning only correctly narrows the
    // set once (e.g. an accidental one-shot flag) or where a later cycle's
    // intersection is computed against a stale live-ID snapshot.
    test('repeated pruneAgainst calls across a shrinking-then-growing pool '
        'reflect only currently-valid IDs after EACH cycle, not just the '
        'first', () async {
      final prefs = await buildPrefs({});
      final store = StoryCycleStore(prefs);

      // Cycle 1: seed seen with three death IDs, all currently valid.
      for (final id in ['death_001', 'death_002', 'death_003']) {
        store.seenFor(RunOutcome.death).add(id);
        store.record(RunOutcome.death, id);
      }
      store.pruneAgainst(
        poolWith(
          deathIds: ['death_001', 'death_002', 'death_003'],
          survivedIds: ['survived_001'],
          eternalIds: ['eternal_001'],
        ),
      );
      expect(store.seenFor(RunOutcome.death), {
        'death_001',
        'death_002',
        'death_003',
      });

      // Cycle 2: shrink -- death_003 is removed from the live pool.
      store.pruneAgainst(
        poolWith(
          deathIds: ['death_001', 'death_002'],
          survivedIds: ['survived_001'],
          eternalIds: ['eternal_001'],
        ),
      );
      expect(store.seenFor(RunOutcome.death), {'death_001', 'death_002'});
      await Future<void>.delayed(Duration.zero);
      expect(prefs.seenStoryIdsDeath.toSet(), {'death_001', 'death_002'});

      // Cycle 3: grow -- two brand-new IDs (death_004, death_005) enter the
      // pool and death_001 is removed. `pruneAgainst` only ever intersects,
      // never adds, so the new IDs must NOT appear in the seen-set merely
      // because they now exist in the pool.
      store.pruneAgainst(
        poolWith(
          deathIds: ['death_002', 'death_004', 'death_005'],
          survivedIds: ['survived_001'],
          eternalIds: ['eternal_001'],
        ),
      );
      expect(store.seenFor(RunOutcome.death), {'death_002'});

      // Now genuinely pick/record one of the newly-added IDs, then run a
      // fourth prune cycle against a pool that keeps both -- both must
      // survive this and only this cycle's intersection.
      store.seenFor(RunOutcome.death).add('death_004');
      store.record(RunOutcome.death, 'death_004');
      store.pruneAgainst(
        poolWith(
          deathIds: ['death_002', 'death_004'],
          survivedIds: ['survived_001'],
          eternalIds: ['eternal_001'],
        ),
      );
      expect(store.seenFor(RunOutcome.death), {'death_002', 'death_004'});
      await Future<void>.delayed(Duration.zero);
      expect(prefs.seenStoryIdsDeath.toSet(), {'death_002', 'death_004'});
    });
  });

  group('corrupt prefs', () {
    test('a wrong-typed stored value (getStringList throwing at the plugin '
        'level) defaults to {}, never propagates', () async {
      // Storing a String under a key StoryCycleStore reads as a StringList
      // reproduces the real-world "written by an incompatible type" corruption.
      final prefs = await buildPrefs({kKeySeenStoryIdsDeath: 'not-a-list'});

      expect(() => StoryCycleStore(prefs), returnsNormally);
      final store = StoryCycleStore(prefs);
      expect(store.seenFor(RunOutcome.death), isEmpty);
    });
  });

  group('reset()', () {
    test(
      'clears all six in-memory values (the Settings-reset bug fix)',
      () async {
        final prefs = await buildPrefs({
          kKeySeenStoryIdsDeath: ['death_001'],
          kKeyLastStoryIdDeath: 'death_001',
        });
        final store = StoryCycleStore(prefs);
        store.record(RunOutcome.survived, 'survived_002');

        store.reset();

        expect(store.seenFor(RunOutcome.death), isEmpty);
        expect(store.seenFor(RunOutcome.survived), isEmpty);
        expect(store.seenFor(RunOutcome.eternal), isEmpty);
        expect(store.lastShownFor(RunOutcome.death), '');
        expect(store.lastShownFor(RunOutcome.survived), '');
        expect(store.lastShownFor(RunOutcome.eternal), '');
      },
    );
  });
}
