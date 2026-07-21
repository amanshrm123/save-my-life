// Tests for `OnboardingController` (lib/features/onboarding/
// onboarding_controller.dart) — the state machine driving 1.2-1.5
// (docs/design/onboarding-flow-v1.md §3.3).
//
// `profileRepositoryProvider`/`nameValidatorProvider` are overridden with
// test doubles (a `FakeProfileRepository` and an explicit-word-list
// `NameValidator`) so these tests never touch real Hive storage or the
// bundled asset file — same seam-over-mock approach as
// `test/support/fake_monotonic_clock.dart`.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timing_tap/features/onboarding/name_validator.dart';
import 'package:timing_tap/features/onboarding/onboarding_controller.dart';
import 'package:timing_tap/features/persistence/hive_profile_repository.dart';
import 'package:timing_tap/features/persistence/profile_repository.dart';

import '../../support/fake_profile_repository.dart';

void main() {
  late FakeProfileRepository repository;
  late ProviderContainer container;

  ProviderContainer buildContainer(FakeProfileRepository repo) {
    return ProviderContainer(
      overrides: [
        profileRepositoryProvider
            .overrideWith((ref) async => repo as ProfileRepository),
        nameValidatorProvider.overrideWith(
          (ref) async => NameValidator(['damn']),
        ),
      ],
    );
  }

  setUp(() {
    repository = FakeProfileRepository();
    container = buildContainer(repository);
  });

  tearDown(() {
    container.dispose();
  });

  group('initial state', () {
    test('starts at teach1 with no name error', () {
      final OnboardingState state = container.read(onboardingControllerProvider);
      expect(state.step, OnboardingStep.teach1);
      expect(state.nameError, isFalse);
    });
  });

  group('next()', () {
    test('advances teach1 -> teach2 -> teach3', () {
      final notifier = container.read(onboardingControllerProvider.notifier);

      notifier.next();
      expect(container.read(onboardingControllerProvider).step, OnboardingStep.teach2);

      notifier.next();
      expect(container.read(onboardingControllerProvider).step, OnboardingStep.teach3);
    });

    test('is a no-op from teach3 (finishTeaching() owns that transition)', () {
      final notifier = container.read(onboardingControllerProvider.notifier);
      notifier.next();
      notifier.next();
      expect(container.read(onboardingControllerProvider).step, OnboardingStep.teach3);

      notifier.next();
      expect(container.read(onboardingControllerProvider).step, OnboardingStep.teach3);
    });

    test('is a no-op from name', () {
      final notifier = container.read(onboardingControllerProvider.notifier);
      notifier.skipToName();
      expect(container.read(onboardingControllerProvider).step, OnboardingStep.name);

      notifier.next();
      expect(container.read(onboardingControllerProvider).step, OnboardingStep.name);
    });
  });

  group('finishTeaching()', () {
    test('teach3 -> name', () {
      final notifier = container.read(onboardingControllerProvider.notifier);
      notifier.next();
      notifier.next();
      expect(container.read(onboardingControllerProvider).step, OnboardingStep.teach3);

      notifier.finishTeaching();
      expect(container.read(onboardingControllerProvider).step, OnboardingStep.name);
    });
  });

  group('skipToName()', () {
    test('jumps straight from teach1 to name', () {
      final notifier = container.read(onboardingControllerProvider.notifier);
      notifier.skipToName();
      expect(container.read(onboardingControllerProvider).step, OnboardingStep.name);
    });

    test('jumps straight from teach2 to name', () {
      final notifier = container.read(onboardingControllerProvider.notifier);
      notifier.next();
      expect(container.read(onboardingControllerProvider).step, OnboardingStep.teach2);

      notifier.skipToName();
      expect(container.read(onboardingControllerProvider).step, OnboardingStep.name);
    });
  });

  group('submitName()', () {
    test('a clean name persists via ProfileRepository and returns true '
        '(caller navigates to Play)', () async {
      final notifier = container.read(onboardingControllerProvider.notifier);

      final bool accepted = await notifier.submitName('Aman');

      expect(accepted, isTrue);
      expect(repository.isOnboardingComplete, isTrue);
      expect(repository.name, 'Aman');
      expect(repository.markOnboardingCompleteCallCount, 1);
      expect(container.read(onboardingControllerProvider).nameError, isFalse);
    });

    test('an empty name is a valid submission — treated as "no name", still '
        'persists and navigates', () async {
      final notifier = container.read(onboardingControllerProvider.notifier);

      final bool accepted = await notifier.submitName('');

      expect(accepted, isTrue);
      expect(repository.isOnboardingComplete, isTrue);
      expect(repository.name, isNull);
    });

    test('whitespace-only input is treated as empty/no-name', () async {
      final notifier = container.read(onboardingControllerProvider.notifier);
      final bool accepted = await notifier.submitName('   ');
      expect(accepted, isTrue);
      expect(repository.name, isNull);
    });

    test('a profanity match sets nameError and returns false without '
        'persisting (8.1, does not navigate)', () async {
      final notifier = container.read(onboardingControllerProvider.notifier);

      final bool accepted = await notifier.submitName('damn');

      expect(accepted, isFalse);
      expect(container.read(onboardingControllerProvider).nameError, isTrue);
      expect(repository.isOnboardingComplete, isFalse);
      expect(repository.markOnboardingCompleteCallCount, 0);
    });

    test('clearNameError() resets a stale error (any onChanged fire, §5.6)',
        () async {
      final notifier = container.read(onboardingControllerProvider.notifier);
      await notifier.submitName('damn');
      expect(container.read(onboardingControllerProvider).nameError, isTrue);

      notifier.clearNameError();
      expect(container.read(onboardingControllerProvider).nameError, isFalse);
    });

    test('a corrected resubmission after a rejection succeeds', () async {
      final notifier = container.read(onboardingControllerProvider.notifier);
      expect(await notifier.submitName('damn'), isFalse);
      expect(await notifier.submitName('Aman'), isTrue);
      expect(repository.isOnboardingComplete, isTrue);
      expect(repository.name, 'Aman');
    });
  });

  group('skipNaming()', () {
    test('bypasses validation and persists "no name"', () async {
      final notifier = container.read(onboardingControllerProvider.notifier);
      await notifier.skipNaming();

      expect(repository.isOnboardingComplete, isTrue);
      expect(repository.name, isNull);
      expect(container.read(onboardingControllerProvider).nameError, isFalse);
    });

    test('a profanity-looking string never reaches validation via skip',
        () async {
      // skipNaming() takes no argument at all — there is no text input to
      // validate; this documents that contract rather than testing a
      // reachable failure path.
      final notifier = container.read(onboardingControllerProvider.notifier);
      await notifier.skipNaming();
      expect(container.read(onboardingControllerProvider).nameError, isFalse);
    });
  });

  group('restart-from-teach1 on interruption (§3.3)', () {
    test('a fresh OnboardingController always starts at teach1 regardless '
        'of how far a previous (now-discarded) instance got — modeling '
        'the force-quit-mid-teaching restart behavior, since there is no '
        'persisted mid-flow resume position', () {
      // Simulate "force-quit mid-teaching": advance a controller instance
      // partway, then discard its container entirely (as a process kill
      // would) without ever calling markOnboardingComplete.
      final notifier = container.read(onboardingControllerProvider.notifier);
      notifier.next(); // teach1 -> teach2
      expect(container.read(onboardingControllerProvider).step, OnboardingStep.teach2);
      expect(repository.isOnboardingComplete, isFalse);
      container.dispose();

      // "Next launch": a brand-new container/controller reading the same
      // (still-incomplete) repository restarts at teach1, not teach2.
      final ProviderContainer relaunchContainer = buildContainer(repository);
      addTearDown(relaunchContainer.dispose);

      expect(
        relaunchContainer.read(onboardingControllerProvider).step,
        OnboardingStep.teach1,
      );
    });

    test('isOnboardingComplete only ever flips true from inside '
        'submitName/skipNaming, never merely by advancing steps', () {
      final notifier = container.read(onboardingControllerProvider.notifier);
      notifier.next();
      notifier.next();
      notifier.finishTeaching();
      expect(container.read(onboardingControllerProvider).step, OnboardingStep.name);
      expect(repository.isOnboardingComplete, isFalse);
    });
  });
}
