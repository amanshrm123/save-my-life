import 'dart:async';

import '../../../core/persistence/preferences_service.dart';
import '../../play_loop/domain/run_state.dart';
import '../domain/story_pool.dart';

/// Holds the ID-keyed dedup-cycle state (remote-story-config-
/// implementation-spec §2.5): three seen-ID sets and three last-shown IDs,
/// one pair per `RunOutcome` tier. Exists as its own class rather than as
/// fields on the service for one concrete reason: **pruning is a pool-load
/// concern and selection is a per-card concern**, and both need the same
/// three sets. Separating it keeps `StoryPoolRepository` free of dedup
/// knowledge and keeps this class unit-testable against a fake
/// `PreferencesService` without any HTTP in the picture.
class StoryCycleStore {
  /// Hydrates all six values synchronously from prefs. Safe in a
  /// constructor: `PreferencesService`'s getters are all synchronous over an
  /// already-loaded `SharedPreferences` instance.
  StoryCycleStore(this._prefs)
    : _seenDeath = _prefs.seenStoryIdsDeath.toSet(),
      _seenSurvived = _prefs.seenStoryIdsSurvived.toSet(),
      _seenEternal = _prefs.seenStoryIdsEternal.toSet(),
      _lastShownDeath = _prefs.lastStoryIdDeath,
      _lastShownSurvived = _prefs.lastStoryIdSurvived,
      _lastShownEternal = _prefs.lastStoryIdEternal;

  final PreferencesService _prefs;

  Set<String> _seenDeath;
  Set<String> _seenSurvived;
  Set<String> _seenEternal;
  String _lastShownDeath;
  String _lastShownSurvived;
  String _lastShownEternal;

  Set<String> seenFor(RunOutcome outcome) {
    switch (outcome) {
      case RunOutcome.death:
        return _seenDeath;
      case RunOutcome.survived:
        return _seenSurvived;
      case RunOutcome.eternal:
        return _seenEternal;
    }
  }

  String lastShownFor(RunOutcome outcome) {
    switch (outcome) {
      case RunOutcome.death:
        return _lastShownDeath;
      case RunOutcome.survived:
        return _lastShownSurvived;
      case RunOutcome.eternal:
        return _lastShownEternal;
    }
  }

  /// Called by the selector's caller after a successful pick. Updates
  /// memory first, then fires the two prefs writes `unawaited` (write-through
  /// backup only, matching `PreferencesService`'s documented contract). A
  /// dropped write costs at most one duplicate story after a crash; blocking
  /// the card render on a disk write costs every player a frame. Never
  /// throws.
  void record(RunOutcome outcome, String beatId) {
    switch (outcome) {
      case RunOutcome.death:
        _lastShownDeath = beatId;
        unawaited(_prefs.setSeenStoryIdsDeath(_seenDeath.toList()));
        unawaited(_prefs.setLastStoryIdDeath(beatId));
      case RunOutcome.survived:
        _lastShownSurvived = beatId;
        unawaited(_prefs.setSeenStoryIdsSurvived(_seenSurvived.toList()));
        unawaited(_prefs.setLastStoryIdSurvived(beatId));
      case RunOutcome.eternal:
        _lastShownEternal = beatId;
        unawaited(_prefs.setSeenStoryIdsEternal(_seenEternal.toList()));
        unawaited(_prefs.setLastStoryIdEternal(beatId));
    }
  }

  /// Intersects each tier's seen-set with that tier's live ID set and
  /// persists the pruned result — meant to be called **once per pool
  /// install, never per card** (options §8.3 "Pruning"). Also clears
  /// `lastShown` for a tier whose last-shown ID is no longer in the pool.
  /// Never throws.
  void pruneAgainst(StoryPool pool) {
    final deathIds = pool.death.beats.map((b) => b.id).toSet();
    final survivedIds = pool.survived.beats.map((b) => b.id).toSet();
    final eternalIds = pool.eternal.beats.map((b) => b.id).toSet();

    _seenDeath = _seenDeath.intersection(deathIds);
    _seenSurvived = _seenSurvived.intersection(survivedIds);
    _seenEternal = _seenEternal.intersection(eternalIds);

    if (!deathIds.contains(_lastShownDeath)) _lastShownDeath = '';
    if (!survivedIds.contains(_lastShownSurvived)) _lastShownSurvived = '';
    if (!eternalIds.contains(_lastShownEternal)) _lastShownEternal = '';

    unawaited(_prefs.setSeenStoryIdsDeath(_seenDeath.toList()));
    unawaited(_prefs.setSeenStoryIdsSurvived(_seenSurvived.toList()));
    unawaited(_prefs.setSeenStoryIdsEternal(_seenEternal.toList()));
    unawaited(_prefs.setLastStoryIdDeath(_lastShownDeath));
    unawaited(_prefs.setLastStoryIdSurvived(_lastShownSurvived));
    unawaited(_prefs.setLastStoryIdEternal(_lastShownEternal));
  }

  /// Clears all six in-memory values (the §6.2 "Settings-reset bug" fix):
  /// `PreferencesService.clearAll()` wipes the nine prefs keys, but this
  /// store hydrates once in its constructor and is session-scoped, so
  /// without this call its in-memory copy stays stale-but-nonempty after a
  /// "Reset progress". Callers must call this immediately after
  /// `clearAll()`.
  void reset() {
    _seenDeath = {};
    _seenSurvived = {};
    _seenEternal = {};
    _lastShownDeath = '';
    _lastShownSurvived = '';
    _lastShownEternal = '';
  }
}
