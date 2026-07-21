import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../persistence/hive_profile_repository.dart';
import '../persistence/profile_repository.dart';
import 'name_validator.dart';

/// docs/design/onboarding-flow-v1.md §3.3. Splash is *not* a step here — it
/// is routed by `app.dart`/`router.dart` directly, since it runs regardless
/// of onboarding status.
enum OnboardingStep { teach1, teach2, teach3, name }

/// In-flow onboarding state: which step is showing, and whether the last
/// `submitName` attempt was rejected (8.1, §5.6). Does **not** own the
/// persisted `isOnboardingComplete` flag — that lives on [ProfileRepository]
/// and is only ever flipped from inside `submitName`/`skipNaming`.
class OnboardingState {
  const OnboardingState({
    required this.step,
    this.nameError = false,
  });

  final OnboardingStep step;
  final bool nameError;

  OnboardingState copyWith({OnboardingStep? step, bool? nameError}) {
    return OnboardingState(
      step: step ?? this.step,
      nameError: nameError ?? this.nameError,
    );
  }
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
  OnboardingController.new,
);

/// Owns the onboarding in-flow state machine (§3.3). Always starts fresh at
/// `teach1` — there is deliberately no persisted mid-flow resume position
/// (see the class doc on "restart behavior" in the spec): a force-quit
/// mid-teaching simply restarts from `teach1` next launch, since
/// `isOnboardingComplete` only ever flips inside `markOnboardingComplete`.
class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    return const OnboardingState(step: OnboardingStep.teach1);
  }

  /// Advances `teach1 -> teach2 -> teach3`. Called from teach1/teach2's
  /// "Next" button. A no-op from `teach3`/`name` — `teach3`'s advance is
  /// `finishTeaching()`, a deliberately distinct method (§3.3).
  void next() {
    switch (state.step) {
      case OnboardingStep.teach1:
        state = state.copyWith(step: OnboardingStep.teach2);
      case OnboardingStep.teach2:
        state = state.copyWith(step: OnboardingStep.teach3);
      case OnboardingStep.teach3:
      case OnboardingStep.name:
        break;
    }
  }

  /// `teach3 -> name`. Called from teach3's "Got it" button.
  void finishTeaching() {
    state = state.copyWith(step: OnboardingStep.name);
  }

  /// Jumps straight from any teach step to `name` — called by the "Skip"
  /// link on 1.2/1.3/1.4 (§3.4: skipping teaching content and skipping
  /// naming are separable decisions, so this stops at name-capture rather
  /// than going straight to Play).
  void skipToName() {
    state = state.copyWith(step: OnboardingStep.name);
  }

  /// Reconciles `state.step` with a teach card the player reached by
  /// manually swiping the `PageView` rather than tapping Next/Got it/Skip.
  /// Without this, a manual swipe moves the visible page but not
  /// `state.step` — the next button tap then reads the stale step and
  /// fires the wrong transition (e.g. skipping a card, or appearing to do
  /// nothing). A no-op if already on that step, so this never fights with
  /// the button-driven transitions above. Only valid for the 3 teach
  /// pages — never called for `name` (that screen isn't part of the
  /// swipeable `PageView`, §3.5).
  void syncStepFromPage(int pageIndex) {
    final OnboardingStep step = switch (pageIndex) {
      0 => OnboardingStep.teach1,
      1 => OnboardingStep.teach2,
      2 => OnboardingStep.teach3,
      _ => state.step,
    };
    if (step != state.step) {
      state = state.copyWith(step: step);
    }
  }

  /// Clears a stale 8.1 error the moment the player starts editing again
  /// (§5.6) — any `onChanged` fire should clear it, not require another
  /// explicit dismiss tap.
  void clearNameError() {
    if (state.nameError) {
      state = state.copyWith(nameError: false);
    }
  }

  /// Runs `name_validator.dart` against [raw]. Valid (including empty —
  /// empty is a valid "no name" submission, §5.5) persists via
  /// `ProfileRepository.markOnboardingComplete` and returns `true` so the
  /// caller (the name-capture widget) knows to navigate to Play. Invalid
  /// (profanity match) sets `nameError` and returns `false` without
  /// navigating.
  Future<bool> submitName(String raw) async {
    final NameValidator validator =
        await ref.read(nameValidatorProvider.future);

    if (validator.containsProfanity(raw)) {
      state = state.copyWith(nameError: true);
      return false;
    }

    state = state.copyWith(nameError: false);
    final String trimmed = raw.trim();
    final ProfileRepository repository =
        await ref.read(profileRepositoryProvider.future);
    await repository.markOnboardingComplete(
      name: trimmed.isEmpty ? null : trimmed,
    );
    return true;
  }

  /// "Skip for now" — bypasses validation entirely (an intentionally
  /// skipped name can't be "invalid", §5.5) and persists "no name".
  Future<void> skipNaming() async {
    final ProfileRepository repository =
        await ref.read(profileRepositoryProvider.future);
    await repository.markOnboardingComplete(name: null);
  }
}
