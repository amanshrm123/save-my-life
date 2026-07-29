import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/state/onboarding_providers.dart' show preferencesServiceProvider;
import '../data/avatar_repository.dart';

final Provider<AvatarRepository> avatarRepositoryProvider = Provider<AvatarRepository>(
  (ref) => AvatarRepository(ref.watch(preferencesServiceProvider)),
);

/// RAM source of truth for the player's committed avatar id (design
/// `home-avatars-v1.md` §5.4), write-through to prefs. A sync `Notifier`
/// (the prefs read is synchronous), deliberately **not** `.autoDispose` —
/// same session-scoped-cache discipline as `statsProvider`/`settingsProvider`
/// so Home's avatar card never re-reads the repository on every rebuild.
class AvatarController extends Notifier<int> {
  @override
  int build() => ref.watch(avatarRepositoryProvider).avatarId;

  /// The picker's single write path (design §5.4's "draft-then-commit"):
  /// only ever called from the CTA tap, never per grid-tap.
  Future<void> commit(int id) async {
    state = id;
    await ref.read(avatarRepositoryProvider).setAvatarId(id);
  }
}

final NotifierProvider<AvatarController, int> selectedAvatarProvider =
    NotifierProvider<AvatarController, int>(AvatarController.new);
