import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'profile_repository.dart';

/// Hive-backed [ProfileRepository] (docs/architecture/v1.md §1.4: "Hive,
/// wrapped behind a ProfileRepository interface so the storage engine is
/// swappable and mockable in tests"). A single untyped box keyed by field
/// name — no custom `TypeAdapter`/codegen needed for a handful of primitive
/// fields.
class HiveProfileRepository implements ProfileRepository {
  HiveProfileRepository(this._box);

  static const String boxName = 'profile';
  static const String _keyOnboardingComplete = 'isOnboardingComplete';
  static const String _keyName = 'name';
  static const String _keyDeathCount = 'deathCount';

  final Box<dynamic> _box;

  /// Opens (initializing Hive if needed) and returns the shared profile
  /// box wrapped in a repository. This is the real, variable-latency async
  /// init work that `SplashScreen` races against its min/ceiling timers
  /// (docs/design/onboarding-flow-v1.md §3.2).
  static Future<HiveProfileRepository> open() async {
    await Hive.initFlutter();
    final Box<dynamic> box = await Hive.openBox<dynamic>(boxName);
    return HiveProfileRepository(box);
  }

  @override
  bool get isOnboardingComplete =>
      (_box.get(_keyOnboardingComplete) as bool?) ?? false;

  @override
  String? get name => _box.get(_keyName) as String?;

  @override
  Future<void> markOnboardingComplete({String? name}) async {
    await _box.put(_keyOnboardingComplete, true);
    if (name != null) {
      await _box.put(_keyName, name);
    }
  }

  @override
  int get deathCount => (_box.get(_keyDeathCount) as int?) ?? 0;

  @override
  Future<void> incrementDeathCount() async {
    await _box.put(_keyDeathCount, deathCount + 1);
  }
}

/// Resolves once Hive is initialized and the profile box is open. Cached by
/// Riverpod for the life of the `ProviderContainer` — once `SplashScreen`
/// has awaited this the first time, every later `ref.read`/`ref.watch`
/// (e.g. from `OnboardingController`) sees the already-resolved value
/// synchronously via `AsyncData`, no re-opening the box.
final profileRepositoryProvider = FutureProvider<ProfileRepository>((ref) {
  return HiveProfileRepository.open();
});
