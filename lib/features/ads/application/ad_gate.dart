import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session-only interstitial cadence counter (architecture v3 §5/§11 risk
/// 3): lives in a **kept-alive** provider (never `.autoDispose`) so it
/// survives the whole app session; resets only on relaunch (an explicit,
/// deliberate choice — persisting the cadence across relaunches would just
/// annoy on the player's very first run back). Never touches `BuildContext`.
class AdGate extends Notifier<int> {
  static const int cadence = 3;

  @override
  int build() => 0;

  /// Call once per completed run (any outcome), from the outcome screen —
  /// this is the "every 3 completed runs" counter (architecture §5).
  void registerRunCompleted() {
    state = state + 1;
  }

  /// Whether an interstitial is due right now. Read-only — does not itself
  /// advance the counter.
  bool get isDue => state > 0 && state % cadence == 0;
}

final NotifierProvider<AdGate, int> adGateProvider = NotifierProvider<AdGate, int>(AdGate.new);
