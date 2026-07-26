import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../play_loop/domain/run_config.dart';
import '../../play_loop/domain/run_state.dart';
import '../../play_loop/domain/run_summary.dart';
import '../domain/death_lines.dart';
import '../domain/eternal_lines.dart';
import '../domain/flavor_selector.dart';
import '../domain/survived_lines.dart';

/// Fully-resolved, ready-to-render card copy for one `RunSummary` (design v1
/// §2.2/§2.3): the catalog line, the (possibly name-spanned) flavor line,
/// and the sub-line — each tier already reconciled per the design doc's
/// per-tier table.
class OutcomeCardContent {
  const OutcomeCardContent({required this.catalogLine, required this.flavorEntryName, required this.flavorEntryAnonymous, required this.subLine});

  final String catalogLine;

  /// The named-template flavor line, still containing the literal `{name}`
  /// placeholder — the widget layer splits on it to color just the name
  /// span, per design v1 §2.2's per-tier name-span colors.
  final String flavorEntryName;

  final String flavorEntryAnonymous;
  final String subLine;
}

final Provider<Random> outcomeRandomProvider = Provider<Random>((ref) => Random());

final Provider<FlavorSelector> flavorSelectorProvider = Provider<FlavorSelector>(
  (ref) => const FlavorSelector(),
);

/// Last-shown pool index per tier, for `FlavorSelector`'s immediate-repeat
/// avoidance. A plain mutable holder (not a `Notifier`) is deliberate: this
/// is bookkeeping the UI never needs to react to, not observable state —
/// lives for the app session via this un-autoDisposed `Provider`, the same
/// lifetime as `outcomeRandomProvider` above.
class _LastFlavorIndices {
  int? death;
  int? survived;
  int? eternal;
}

final Provider<_LastFlavorIndices> _lastFlavorIndicesProvider =
    Provider<_LastFlavorIndices>((ref) => _LastFlavorIndices());

/// Picks + assembles this run's card content exactly once per `RunSummary`
/// instance (family-cached by object identity) so screen rebuilds — e.g.
/// the share-toast appearing/disappearing — never re-roll the flavor line.
final outcomeCardContentProvider =
    Provider.autoDispose.family<OutcomeCardContent, RunSummary>((ref, summary) {
      final selector = ref.watch(flavorSelectorProvider);
      final random = ref.watch(outcomeRandomProvider);
      final lastIndices = ref.watch(_lastFlavorIndicesProvider);

      switch (summary.outcome) {
        case RunOutcome.death:
          final (entry, index) = selector.pick(
            deathLines,
            random,
            avoidIndex: lastIndices.death,
          );
          lastIndices.death = index;
          // `lifetimeDeaths` already counts *this* death (incremented before
          // `buildSummary()` runs) -- subtract 1 for "how many deaths came
          // before this one", and skip the clause entirely on a player's
          // very first-ever death rather than reading "Survived 0 deaths
          // first" (technically true, but odd copy for a first death).
          final priorDeaths = summary.lifetimeDeaths - 1;
          final priorDeathsClause = priorDeaths > 0
              ? 'Survived ${priorDeaths == 1 ? '1 death' : '$priorDeaths deaths'} first. '
              : '';
          return OutcomeCardContent(
            catalogLine: 'Death #${entry.catalogNo} of 1000',
            flavorEntryName: entry.named,
            flavorEntryAnonymous: entry.anonymous,
            subLine: '${priorDeathsClause}Peaked at ${summary.peakLifePercent}%.',
          );
        case RunOutcome.survived:
          final (entry, index) = selector.pick(
            survivedLines,
            random,
            avoidIndex: lastIndices.survived,
          );
          lastIndices.survived = index;
          return OutcomeCardContent(
            catalogLine: 'Last-second save',
            flavorEntryName: entry.named,
            flavorEntryAnonymous: entry.anonymous,
            subLine:
                'Down to ${summary.minLifePercent}% — one perfect press '
                'back from the edge.',
          );
        case RunOutcome.eternal:
          final (entry, index) = selector.pick(
            eternalLines,
            random,
            avoidIndex: lastIndices.eternal,
          );
          lastIndices.eternal = index;
          return OutcomeCardContent(
            catalogLine:
                'Perfect start · ${summary.perfectCount}/${RunConfig.defaults.eternalPerfectCount}',
            flavorEntryName: entry.named,
            flavorEntryAnonymous: entry.anonymous,
            subLine: entry.sub,
          );
      }
    });
