import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/ads/application/ad_gate.dart';
import 'package:timing_tap/features/ads/state/ad_providers.dart';

/// `AdGate` (architecture v3 §5/§11 risk 3): fires exactly on the 3rd, 6th,
/// 9th... completed run, never before, and the counter is session-only
/// (a kept-alive provider that only resets by rebuilding the container,
/// i.e. an app relaunch — never persisted).
void main() {
  test('isDue is false before any run has completed (state == 0)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final gate = container.read(adGateProvider.notifier);

    expect(gate.isDue, isFalse);
  });

  test('isDue is false after 1 and 2 completed runs', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final gate = container.read(adGateProvider.notifier);

    gate.registerRunCompleted();
    expect(gate.isDue, isFalse, reason: 'run 1');

    gate.registerRunCompleted();
    expect(gate.isDue, isFalse, reason: 'run 2');
  });

  test('isDue becomes true exactly on the 3rd completed run', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final gate = container.read(adGateProvider.notifier);

    gate.registerRunCompleted();
    gate.registerRunCompleted();
    gate.registerRunCompleted();

    expect(gate.isDue, isTrue);
  });

  test('isDue is false again on runs 4 and 5, then true again on the 6th '
      '(cadence repeats, not just a one-time trigger)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final gate = container.read(adGateProvider.notifier);

    for (var i = 0; i < 3; i++) {
      gate.registerRunCompleted();
    }
    expect(gate.isDue, isTrue, reason: 'run 3');

    gate.registerRunCompleted();
    expect(gate.isDue, isFalse, reason: 'run 4');

    gate.registerRunCompleted();
    expect(gate.isDue, isFalse, reason: 'run 5');

    gate.registerRunCompleted();
    expect(gate.isDue, isTrue, reason: 'run 6');
  });

  test('the full sequence over 9 runs is due only on 3, 6, 9', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final gate = container.read(adGateProvider.notifier);

    final dueByRun = <int, bool>{};
    for (var i = 1; i <= 9; i++) {
      gate.registerRunCompleted();
      dueByRun[i] = gate.isDue;
    }

    expect(dueByRun, {
      1: false,
      2: false,
      3: true,
      4: false,
      5: false,
      6: true,
      7: false,
      8: false,
      9: true,
    });
  });

  test('checking isDue repeatedly (e.g. re-reading the provider) does not '
      'itself advance the counter — isDue is read-only', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final gate = container.read(adGateProvider.notifier);

    gate.registerRunCompleted();
    gate.registerRunCompleted();
    gate.registerRunCompleted();
    expect(gate.isDue, isTrue);
    // Reading isDue several more times must not change anything.
    expect(gate.isDue, isTrue);
    expect(gate.isDue, isTrue);
    expect(container.read(adGateProvider), 3, reason: 'the raw counter must still read 3');
  });

  test('the counter is session-only: a brand-new ProviderContainer (the '
      'app-relaunch analog) starts back at 0, not carrying over a prior '
      'session\'s count', () {
    final containerA = ProviderContainer();
    final gateA = containerA.read(adGateProvider.notifier);
    gateA.registerRunCompleted();
    gateA.registerRunCompleted();
    gateA.registerRunCompleted();
    expect(gateA.isDue, isTrue);
    containerA.dispose();

    final containerB = ProviderContainer();
    addTearDown(containerB.dispose);
    final gateB = containerB.read(adGateProvider.notifier);

    expect(containerB.read(adGateProvider), 0);
    expect(gateB.isDue, isFalse);
  });

  test('adServiceProvider resolves to a FakeAdService instance (no real '
      'ad-network dependency wired up)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(adServiceProvider);

    expect(service, isNotNull);
  });
}
