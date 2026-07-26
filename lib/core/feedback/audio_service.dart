import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'feedback.dart';

/// The 3 short SFX shipped at `assets/sfx/*.wav` (architecture v3 §12 flag 3
/// — synthesized, zero licensing risk): `tap` (arm/UI feedback), `hit`
/// (Perfect/Hit stop, doubles for Perfect), `miss` (Miss stop).
abstract class AudioService {
  Future<void> playTap();
  Future<void> playHit();
  Future<void> playMiss();

  /// Releases the underlying player resources. Safe to call multiple times.
  void dispose();
}

/// Real `audioplayers`-backed implementation. One dedicated low-latency
/// player per clip (rather than one shared player) so a rapid tap-then-hit
/// sequence can't cut a still-playing clip short by reusing its player.
/// Every play call is gated by `Feedback.soundEnabled` (architecture §7) and
/// wrapped so a platform-channel failure never throws into the UI/gameplay
/// path (same swallow-on-write discipline as the rest of this app).
class RealAudioService implements AudioService {
  RealAudioService()
    : _tapPlayer = AudioPlayer(playerId: 'sfx_tap'),
      _hitPlayer = AudioPlayer(playerId: 'sfx_hit'),
      _missPlayer = AudioPlayer(playerId: 'sfx_miss') {
    for (final p in [_tapPlayer, _hitPlayer, _missPlayer]) {
      unawaited(p.setPlayerMode(PlayerMode.lowLatency));
      unawaited(p.setReleaseMode(ReleaseMode.stop));
    }
  }

  final AudioPlayer _tapPlayer;
  final AudioPlayer _hitPlayer;
  final AudioPlayer _missPlayer;
  bool _disposed = false;

  Future<void> _play(AudioPlayer player, String assetPath) async {
    if (_disposed) return;
    if (!AppFeedback.soundEnabled.value) return;
    try {
      await player.play(AssetSource(assetPath));
    } catch (_) {
      // Swallow — a failed SFX playback is never fatal to gameplay.
    }
  }

  @override
  Future<void> playTap() => _play(_tapPlayer, 'sfx/tap.wav');

  @override
  Future<void> playHit() => _play(_hitPlayer, 'sfx/hit.wav');

  @override
  Future<void> playMiss() => _play(_missPlayer, 'sfx/miss.wav');

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_tapPlayer.dispose());
    unawaited(_hitPlayer.dispose());
    unawaited(_missPlayer.dispose());
  }
}

/// Kept-alive for the whole app session (mirrors `Feedback`'s singleton
/// discipline) — never `.autoDispose`, since gameplay audio must survive the
/// Home<->Play navigation cycle without re-initializing players every run.
final Provider<AudioService> audioServiceProvider = Provider<AudioService>((ref) {
  final service = RealAudioService();
  ref.onDispose(service.dispose);
  return service;
});
