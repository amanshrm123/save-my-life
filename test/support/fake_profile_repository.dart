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
    int deathCount = 0,
  })  : _isOnboardingComplete = isOnboardingComplete,
        _name = name,
        _deathCount = deathCount;

  bool _isOnboardingComplete;
  String? _name;
  int _deathCount;

  /// Number of times `markOnboardingComplete` was called — lets tests
  /// assert persistence happened exactly once, not merely that state ended
  /// up correct.
  int markOnboardingCompleteCallCount = 0;

  /// Number of times `incrementDeathCount` was called — mirrors
  /// `markOnboardingCompleteCallCount` so tests can assert a death was
  /// persisted exactly once (architecture v3 §3.4/§5).
  int incrementDeathCountCallCount = 0;

  @override
  bool get isOnboardingComplete => _isOnboardingComplete;

  @override
  String? get name => _name;

  @override
  int get deathCount => _deathCount;

  @override
  Future<void> markOnboardingComplete({String? name}) async {
    markOnboardingCompleteCallCount++;
    _isOnboardingComplete = true;
    if (name != null) {
      _name = name;
    }
  }

  @override
  Future<void> incrementDeathCount() async {
    incrementDeathCountCallCount++;
    _deathCount++;
  }
}
