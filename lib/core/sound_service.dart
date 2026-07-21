import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The one-sound feel addition for Gate 1
/// (docs/design/play-screen-gate1-v1.md §4): two short one-shot cues,
/// hit and miss, played fire-and-forget.
///
/// `playHit()`/`playMiss()` must never be awaited from the tap callback —
/// sound must never add latency near the tap-capture/timing path. Each
/// exposed method starts playback and returns immediately; playback
/// failures (e.g. no audio output) are swallowed rather than surfaced,
/// since a missing SFX cue is not a condition the run needs to react to.
class SoundService {
  SoundService()
      : _hitPlayer = AudioPlayer(),
        _missPlayer = AudioPlayer();

  final AudioPlayer _hitPlayer;
  final AudioPlayer _missPlayer;

  /// Plays the hit cue. Used for both Perfect and On-point taps — collapsed
  /// to one treatment per spec §4 (no separate "Perfect" fanfare).
  void playHit() {
    unawaited(_play(_hitPlayer, 'sfx/hit.mp3'));
  }

  /// Plays the miss cue.
  void playMiss() {
    unawaited(_play(_missPlayer, 'sfx/miss.mp3'));
  }

  Future<void> _play(AudioPlayer player, String assetPath) async {
    try {
      await player.play(AssetSource(assetPath));
    } catch (_) {
      // A missing/failed SFX cue (e.g. no audio output, or no platform
      // plugin available as in widget tests) is not a condition the run
      // needs to react to — swallow rather than surface.
    }
  }

  void dispose() {
    unawaited(_disposePlayer(_hitPlayer));
    unawaited(_disposePlayer(_missPlayer));
  }

  Future<void> _disposePlayer(AudioPlayer player) async {
    try {
      await player.dispose();
    } catch (_) {
      // Ignore disposal errors from an unavailable platform plugin (e.g.
      // widget/unit tests with no audio engine).
    }
  }
}

/// One shared [SoundService] for the app session.
final soundServiceProvider = Provider<SoundService>((ref) {
  final SoundService service = SoundService();
  ref.onDispose(service.dispose);
  return service;
});
