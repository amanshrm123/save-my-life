import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../play_loop/domain/run_state.dart';
import '../../state/outcome_providers.dart';
import 'outcome_badge.dart';

/// Per-tier visual config (design v3 §2.2's table), resolved once per
/// `RunOutcome` — kept private, this file is the single source of truth for
/// tier colors so `OutcomeCardScreen` never duplicates the table.
class _TierStyle {
  const _TierStyle({
    required this.badgeLabel,
    required this.badgeFill,
    required this.badgeText,
    required this.cardFill,
    required this.catalogColor,
    required this.flavorColor,
    required this.nameSpanColor,
    required this.subColor,
    required this.markColor,
    required this.shareLabel,
    required this.shareFill,
    required this.shareText,
  });

  final String badgeLabel;
  final Color badgeFill;
  final Color badgeText;
  final Color cardFill;
  final Color catalogColor;
  final Color flavorColor;
  final Color nameSpanColor;
  final Color subColor;
  final Color markColor;
  final String shareLabel;
  final Color shareFill;
  final Color shareText;

  static const death = _TierStyle(
    badgeLabel: '💀 You died',
    badgeFill: AppColors.red,
    badgeText: Colors.white,
    cardFill: AppColors.paper,
    catalogColor: AppColors.red,
    flavorColor: AppColors.ink,
    nameSpanColor: AppColors.coral,
    subColor: AppColors.mute,
    markColor: AppColors.mute,
    shareLabel: 'Share →',
    shareFill: AppColors.red,
    shareText: Colors.white,
  );

  static const survived = _TierStyle(
    badgeLabel: '🛟 Survived',
    badgeFill: AppColors.green,
    badgeText: Colors.white,
    cardFill: AppColors.cardSurviveBg,
    catalogColor: AppColors.greenDark,
    flavorColor: AppColors.ink,
    nameSpanColor: AppColors.greenDark,
    subColor: AppColors.mute,
    markColor: AppColors.mute,
    shareLabel: 'Share →',
    shareFill: AppColors.green,
    shareText: Colors.white,
  );

  static const eternal = _TierStyle(
    badgeLabel: '✨ Eternal Human',
    badgeFill: AppColors.gold,
    badgeText: AppColors.ink,
    cardFill: AppColors.gold,
    catalogColor: AppColors.eternalNo,
    flavorColor: AppColors.eternalWay,
    nameSpanColor: AppColors.eternalName,
    subColor: AppColors.eternalWay,
    markColor: AppColors.eternalNo,
    shareLabel: 'Flex it →',
    shareFill: AppColors.gold,
    shareText: AppColors.ink,
  );

  static _TierStyle of(RunOutcome outcome) {
    switch (outcome) {
      case RunOutcome.death:
        return death;
      case RunOutcome.survived:
        return survived;
      case RunOutcome.eternal:
        return eternal;
    }
  }
}

/// The outcome-card body (design v3 §2.1/§2.2) — badge + cardbox, the exact
/// composition captured by the sharing `RepaintBoundary` (architecture §3/
/// §4). Deliberately excludes the actions row (Share/Again), which lives
/// outside the shareable capture.
class OutcomeCard extends StatelessWidget {
  const OutcomeCard({super.key, required this.outcome, required this.playerName, required this.content});

  final RunOutcome outcome;
  final String playerName;
  final OutcomeCardContent content;

  _TierStyle get _style => _TierStyle.of(outcome);

  @override
  Widget build(BuildContext context) {
    final style = _style;
    return Column(
      children: [
        OutcomeBadge(label: style.badgeLabel, fill: style.badgeFill, textColor: style.badgeText),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: style.cardFill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.ink, width: 2.5),
              boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(0, 5), blurRadius: 0)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.catalogLine,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: style.catalogColor,
                    height: 1.1,
                  ),
                ),
                // Flexible spacer: the empty space lives ABOVE the
                // flavor-line group, which stays bottom-anchored (design v3
                // §2.1's `margin-top: auto` behavior) — never an evenly
                // distributed gap.
                const Expanded(child: SizedBox.shrink()),
                _FlavorGroup(
                  playerName: playerName,
                  content: content,
                  style: style,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FlavorGroup extends StatelessWidget {
  const _FlavorGroup({
    required this.playerName,
    required this.content,
    required this.style,
  });

  final String playerName;
  final OutcomeCardContent content;
  final _TierStyle style;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _flavorText(),
        const SizedBox(height: 6),
        Text(
          content.subLine,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: style.subColor,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'stayalive.app'.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: style.markColor,
            letterSpacing: 0.04 * 9,
            height: 1,
          ),
        ),
      ],
    );
  }

  /// Design v3 §2.2's "3.4 is not a fourth content pool" resolution, applied
  /// generically to every tier: when `playerName` is empty, render the
  /// anonymous template plainly (no colored name span at all); otherwise
  /// split the named template on its literal `{name}` placeholder and color
  /// just the name span per the tier's own color.
  Widget _flavorText() {
    const baseStyle = TextStyle(fontFamily: 'Fredoka', fontSize: 13, fontWeight: FontWeight.w600, height: 1.35);

    if (playerName.isEmpty) {
      return Text(content.flavorEntryAnonymous, style: baseStyle.copyWith(color: style.flavorColor));
    }

    final parts = content.flavorEntryName.split('{name}');
    final before = parts.isNotEmpty ? parts[0] : '';
    final after = parts.length > 1 ? parts[1] : '';
    return Text.rich(
      TextSpan(
        style: baseStyle.copyWith(color: style.flavorColor),
        children: [
          if (before.isNotEmpty) TextSpan(text: before),
          TextSpan(text: playerName, style: TextStyle(color: style.nameSpanColor)),
          if (after.isNotEmpty) TextSpan(text: after),
        ],
      ),
    );
  }
}
