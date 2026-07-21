// Test-only in-memory stand-in for `ProfileRepository`
// (lib/features/persistence/profile_repository.dart) — avoids touching real
// Hive/platform-channel storage in unit/widget tests, same seam-over-mock
// philosophy as `FakeMonotonicClock`.
//
// ignore_for_file: prefer_initializing_formals — the public constructor
// params intentionally keep their public names distinct from the private
// backing fields below; an initializing formal would force the parameter
// itself to be private too.

import 'package:timing_tap/features/persistence/profile_repository.dart';

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({
    bool isOnboardingComplete = false,
    String? name,
  })  : _isOnboardingComplete = isOnboardingComplete,
        _name = name;

  bool _isOnboardingComplete;
  String? _name;

  /// Number of times `markOnboardingComplete` was called — lets tests
  /// assert persistence happened exactly once, not merely that state ended
  /// up correct.
  int markOnboardingCompleteCallCount = 0;

  @override
  bool get isOnboardingComplete => _isOnboardingComplete;

  @override
  String? get name => _name;

  @override
  Future<void> markOnboardingComplete({String? name}) async {
    markOnboardingCompleteCallCount++;
    _isOnboardingComplete = true;
    if (name != null) {
      _name = name;
    }
  }
}
