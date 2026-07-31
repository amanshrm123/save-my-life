import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/card_renderer.dart';
import '../application/share_service.dart';
import '../application/social_share_service.dart';
import '../domain/share_target.dart';

final Provider<CardRenderer> cardRendererProvider = Provider<CardRenderer>(
  (ref) => const CardRenderer(),
);

final Provider<ShareService> shareServiceProvider = Provider<ShareService>(
  (ref) => const ShareService(),
);

final Provider<SocialShareService> socialShareServiceProvider = Provider<SocialShareService>(
  (ref) => const SocialShareService(),
);

/// The installed-targets probe (architecture v5 §10/§11): `autoDispose`
/// rather than kept alive, and re-read (not watched-and-cached) on every
/// Share tap via `ref.read(installedTargetsProvider.future)` in
/// `OutcomeCardScreen._onShare` — install state can change between
/// sessions, so this must never serve a stale cached result across two
/// different sheet openings.
final installedTargetsProvider = FutureProvider.autoDispose<List<ShareTarget>>((ref) {
  final service = ref.watch(socialShareServiceProvider);
  return service.installedTargets();
});
