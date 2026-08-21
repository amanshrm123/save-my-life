import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../../onboarding/state/onboarding_providers.dart' show preferencesServiceProvider;
import '../data/tour_repository.dart';

final Provider<TourRepository> tourRepositoryProvider = Provider<TourRepository>(
  (ref) => TourRepository(ref.watch(preferencesServiceProvider)),
);

/// Transient in-RAM replay request from Settings' "Replay tour" row (design
/// v1 §2.3): Home reads it in `_onBecameVisible()` and immediately resets it
/// to false. Deliberately a plain `StateProvider<bool>`, not a persisted
/// flag — a queued replay must not survive an app kill.
final StateProvider<bool> pendingHomeTourProvider = StateProvider<bool>((ref) => false);
