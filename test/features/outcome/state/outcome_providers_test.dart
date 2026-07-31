import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/outcome/application/outcome_story_service.dart';
import 'package:timing_tap/features/outcome/domain/outcome_story_content.dart';
import 'package:timing_tap/features/outcome/state/outcome_providers.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/domain/run_summary.dart';

/// Coverage for `outcomeStoryProvider` (architecture v4 §2/§3) — replaces the
/// deleted `outcome_providers_test.dart`'s coverage of the old
/// `outcomeCardContentProvider` (which built the now-removed
/// catalog/sub-line content synchronously). The new provider's whole job is
/// the `kMinStoryLoadDuration` `Future.wait` floor and family-identity
/// caching, both regression-critical per this session's design/architecture
/// docs.
///
/// Timings below are expressed relative to `kMinStoryLoadDuration` (1000ms
/// as of remote-story-config-implementation-spec §5.1, down from the
/// original 2s) rather than a hardcoded literal, so this file keeps its
/// meaning if the floor is ever tuned again.
///
/// These use `testWidgets` (not plain `test()`) even though no widget is
/// pumped, specifically to run inside `flutter_test`'s fake-async test zone
/// so `tester.pump(duration)` can deterministically advance the
/// `Future.delayed` floor without genuinely waiting that long in real time
/// per test — the same technique `test/integration/*_test.dart` relies on
/// implicitly via `pumpAndSettle`.
void main() {
  // Deliberately NOT `const`: `RunSummary`'s constructor is const-capable,
  // and two `const` calls with identical arguments would canonicalize to
  // the exact same object (Dart's constant-canonicalization) — which would
  // silently defeat the "two different instances" identity test below. A
  // plain (non-const) call always allocates a fresh, distinct instance,
  // matching what `RunController` actually hands `OutcomeCardScreen` in
  // production (never a compile-time constant).
  RunSummary summary() {
    return RunSummary(
      outcome: RunOutcome.death,
      runNumber: 1,
      lifetimeDeaths: 1,
      peakLifePercent: 90,
      minLifePercent: 2,
      attemptCount: 0,
      playerName: 'Aman',
    );
  }

  testWidgets('an instant-resolving fetch still does not resolve before the '
      'kMinStoryLoadDuration floor (max(fetch, floor), not near-instant)', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        outcomeStoryServiceProvider.overrideWithValue(_InstantFakeService()),
      ],
    );
    addTearDown(container.dispose);

    var resolved = false;
    final sub = container.listen<AsyncValue<OutcomeStoryContent>>(
      outcomeStoryProvider(summary()),
      (previous, next) {
        if (next is AsyncData<OutcomeStoryContent>) resolved = true;
      },
    );
    addTearDown(sub.close);

    await tester.pump(); // let the fetch's own (instant) future settle
    expect(
      resolved,
      isFalse,
      reason: 'the fetch resolved instantly, but the floor must still hold',
    );

    await tester.pump(
      kMinStoryLoadDuration - const Duration(milliseconds: 100),
    );
    expect(resolved, isFalse, reason: 'still short of the floor');

    await tester.pump(const Duration(milliseconds: 150));
    expect(resolved, isTrue, reason: 'now past the floor');
  });

  testWidgets('total resolve time is max(fetchTime, kMinStoryLoadDuration), not '
      'fetchTime + floor — a fetch that itself takes 500ms still resolves by '
      '~the floor, not floor + 500ms', (tester) async {
    final container = ProviderContainer(
      overrides: [
        outcomeStoryServiceProvider.overrideWithValue(
          _DelayedFakeService(const Duration(milliseconds: 500)),
        ),
      ],
    );
    addTearDown(container.dispose);

    var resolved = false;
    final sub = container.listen<AsyncValue<OutcomeStoryContent>>(
      outcomeStoryProvider(summary()),
      (previous, next) {
        if (next is AsyncData<OutcomeStoryContent>) resolved = true;
      },
    );
    addTearDown(sub.close);

    // If this were fetch + floor (1500ms), pumping only floor + 100ms would
    // leave it unresolved. Under the correct max() semantics it must
    // already be resolved by then (the fetch's own 500ms ran concurrently
    // with, and finished well inside, the 1000ms floor).
    await tester.pump(
      kMinStoryLoadDuration + const Duration(milliseconds: 100),
    );
    expect(
      resolved,
      isTrue,
      reason:
          'Future.wait must run the fetch and the floor delay concurrently, not '
          'sequentially — a summed wait would still be pending here',
    );
  });

  testWidgets(
    'a slow fetch (3s, well past kMinStoryLoadDuration) still governs the '
    'total time — the floor never truncates a legitimately slower real fetch',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          outcomeStoryServiceProvider.overrideWithValue(
            _DelayedFakeService(const Duration(seconds: 3)),
          ),
        ],
      );
      addTearDown(container.dispose);

      var resolved = false;
      final sub = container.listen<AsyncValue<OutcomeStoryContent>>(
        outcomeStoryProvider(summary()),
        (previous, next) {
          if (next is AsyncData<OutcomeStoryContent>) resolved = true;
        },
      );
      addTearDown(sub.close);

      // Past the floor (1200ms) but well short of the 3s fetch.
      await tester.pump(
        kMinStoryLoadDuration + const Duration(milliseconds: 900),
      );
      expect(
        resolved,
        isFalse,
        reason: 'the fetch itself has not completed yet',
      );

      await tester.pump(const Duration(milliseconds: 2100));
      expect(resolved, isTrue, reason: 'now past the slower 3s fetch time');
    },
  );

  testWidgets(
    'the family caches by RunSummary identity — the same instance resolves '
    'once, and rewatching/re-reading never re-fetches or re-rolls',
    (tester) async {
      final fake = _CountingFakeService();
      final container = ProviderContainer(
        overrides: [outcomeStoryServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final theSummary = summary();
      final sub = container.listen<AsyncValue<OutcomeStoryContent>>(
        outcomeStoryProvider(theSummary),
        (previous, next) {},
      );
      addTearDown(sub.close);

      await tester.pump(const Duration(seconds: 3));
      expect(fake.calls, 1);

      final first = container.read(outcomeStoryProvider(theSummary)).value;
      expect(first, isNotNull);

      // Re-reading (simulating a rebuild, e.g. the share toast toggling)
      // must not trigger a second fetch/roll.
      final second = container.read(outcomeStoryProvider(theSummary)).value;
      expect(second, same(first));
      expect(
        fake.calls,
        1,
        reason: 'rewatching the same RunSummary instance must not re-fetch',
      );

      // A second, separately-listened read (as a different consumer would
      // do) must also see the cached value, not trigger another fetch.
      final third = container.read(outcomeStoryProvider(theSummary)).value;
      expect(third, same(first));
      expect(fake.calls, 1);
    },
  );

  testWidgets(
    'two different RunSummary instances (even with identical field values) '
    'are cached and fetched independently — the family keys by instance, '
    'per architecture v4 §3',
    (tester) async {
      final fake = _CountingFakeService();
      final container = ProviderContainer(
        overrides: [outcomeStoryServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final summaryA = summary();
      final summaryB = summary();

      final subA = container.listen<AsyncValue<OutcomeStoryContent>>(
        outcomeStoryProvider(summaryA),
        (previous, next) {},
      );
      addTearDown(subA.close);
      final subB = container.listen<AsyncValue<OutcomeStoryContent>>(
        outcomeStoryProvider(summaryB),
        (previous, next) {},
      );
      addTearDown(subB.close);

      await tester.pump(const Duration(seconds: 3));
      expect(
        fake.calls,
        2,
        reason: 'two distinct RunSummary instances -> two independent fetches',
      );
    },
  );
}

class _InstantFakeService implements OutcomeStoryService {
  @override
  Future<OutcomeStoryContent> fetchStory(RunSummary summary) async {
    return OutcomeStoryContent.naFor;
  }
}

class _DelayedFakeService implements OutcomeStoryService {
  _DelayedFakeService(this.delay);
  final Duration delay;

  @override
  Future<OutcomeStoryContent> fetchStory(RunSummary summary) async {
    await Future<void>.delayed(delay);
    return OutcomeStoryContent.naFor;
  }
}

class _CountingFakeService implements OutcomeStoryService {
  int calls = 0;

  @override
  Future<OutcomeStoryContent> fetchStory(RunSummary summary) async {
    calls++;
    return OutcomeStoryContent(
      headline: 'H$calls',
      storyNamed: 'S$calls {name}',
      storyAnonymous: 'A$calls',
      icon: 'I$calls',
      isFallback: false,
    );
  }
}
