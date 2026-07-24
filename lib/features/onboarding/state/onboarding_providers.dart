import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/preferences_service.dart';
import '../data/player_profile_repository.dart';
import '../domain/player_profile.dart';

/// Overridden in `main()` with the already-initialized [PreferencesService]
/// instance before `runApp` (architecture v1 §3).
final Provider<PreferencesService> preferencesServiceProvider =
    Provider<PreferencesService>((ref) {
      throw UnimplementedError(
        'preferencesServiceProvider must be overridden in main() before runApp().',
      );
    });

final Provider<PlayerProfileRepository> playerProfileRepositoryProvider =
    Provider<PlayerProfileRepository>((ref) {
      return PlayerProfileRepository(ref.watch(preferencesServiceProvider));
    });

/// Holds the single authoritative, in-memory copy of the [PlayerProfile].
/// SharedPreferences is a write-through durability backup, not the runtime
/// source of truth (architecture v1 §1) — this loads once, then serves the
/// profile from RAM until a terminal onboarding action mutates it.
class PlayerProfileNotifier extends AsyncNotifier<PlayerProfile> {
  @override
  Future<PlayerProfile> build() {
    return ref.watch(playerProfileRepositoryProvider).load();
  }

  Future<PlayerProfile> completeWithName(String name) async {
    final repo = ref.read(playerProfileRepositoryProvider);
    final profile = await repo.completeWithName(name);
    state = AsyncData(profile);
    return profile;
  }

  Future<PlayerProfile> completeAnonymous() async {
    final repo = ref.read(playerProfileRepositoryProvider);
    final profile = await repo.completeAnonymous();
    state = AsyncData(profile);
    return profile;
  }
}

final AsyncNotifierProvider<PlayerProfileNotifier, PlayerProfile>
playerProfileProvider =
    AsyncNotifierProvider<PlayerProfileNotifier, PlayerProfile>(
      PlayerProfileNotifier.new,
    );
