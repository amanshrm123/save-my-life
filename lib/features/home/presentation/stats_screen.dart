import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/screen_header.dart';
import '../../progression/state/stats_providers.dart';

/// 6.4 Stats — full lifetime list (design v3 §5.4), the first document-flow
/// screen family alongside Home/Settings (16dp horizontal / 14dp vertical
/// `.pad` inset).
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(statsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenHeader(emoji: '📊', title: 'Your stats'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  _StatRow(emoji: '📈', label: 'Best life', value: '${snap.bestLifePercent}%'),
                  _StatRow(emoji: '💀', label: 'Total deaths', value: '${snap.totalDeaths}'),
                  _StatRow(emoji: '🛟', label: 'Survives', value: '${snap.totalSurvives}'),
                  _StatRow(emoji: '✨', label: 'Eternal Humans', value: '${snap.totalEternal}', valueColor: AppColors.goldDark),
                  _StatRow(
                    emoji: '🔥',
                    label: 'Best streak',
                    value: snap.streak.best == 1 ? '1 day' : '${snap.streak.best} days',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.emoji,
    required this.label,
    required this.value,
    this.valueColor = AppColors.ink,
  });

  final String emoji;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink, width: 2.5),
        boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(0, 4), blurRadius: 0)],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.paper2,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.ink, width: 2),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
