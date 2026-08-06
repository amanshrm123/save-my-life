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
  // Android-only bug fix: `audioplayers`' default `AudioContext` requests
  // *exclusive* audio focus (`AndroidAudioFocus.gain`) per player. With three
  // separate `AudioPlayer`s here, every tap/hit/miss play call steals focus
  // from whichever of the other two last held it, which Android delivers as
  // a real `AUDIOFOCUS_LOSS` — silencing playback. iOS has no equivalent
  // exclusive-focus contention between `AVAudioPlayer` instances, which is
  // why this was iOS-only-audible before this fix. `mixWithOthers` is also
  // just the correct semantics for short SFX blips: they should never fight
  // each other, or the user's music, for focus in the first place.
  RealAudioService()
    : _tapPlayer = AudioPlayer(playerId: 'sfx_tap'),
      _hitPlayer = AudioPlayer(playerId: 'sfx_hit'),
      _missPlayer = AudioPlayer(playerId: 'sfx_miss') {
    final ctx = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();
    // Setting the *global* default only changes the context newly-created
    // players pick up from that point on — the Android plugin snapshots a
    // process-level default at player-creation time and never revisits it
    // (`AudioplayersPlugin.kt`: `players[playerId] = WrappedPlayer(...,
    // defaultAudioContext.copy(), ...)`). Since these 3 players already
    // exist by the time this constructor runs, the global set alone leaves
    // them on the exclusive-focus default. Setting it directly on each
    // player closes that race unconditionally, regardless of native-side
    // creation-order timing.
    _globalContextReady = Future.wait([
      AudioPlayer.global.setAudioContext(ctx),
      _tapPlayer.setAudioContext(ctx),
      _hitPlayer.setAudioContext(ctx),
      _missPlayer.setAudioContext(ctx),
    ]);
    for (final p in [_tapPlayer, _hitPlayer, _missPlayer]) {
      unawaited(p.setPlayerMode(PlayerMode.lowLatency));
      unawaited(p.setReleaseMode(ReleaseMode.stop));
    }
  }

  final AudioPlayer _tapPlayer;
  final AudioPlayer _hitPlayer;
  final AudioPlayer _missPlayer;
  bool _disposed = false;

  /// Awaited once, at the start of the very first `_play()` call — without
  /// this, the very first tap/hit/miss of a session could still race the
  /// (otherwise fire-and-forget) context updates above and briefly request
  /// exclusive focus before the mix-with-others override lands. A no-op
  /// await on every call after the first, since the future is already
  /// complete by then.
  late final Future<void> _globalContextReady;

  Future<void> _play(AudioPlayer player, String assetPath) async {
    if (_disposed) return;
    if (!AppFeedback.soundEnabled.value) return;
    try {
      await _globalContextReady;
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
