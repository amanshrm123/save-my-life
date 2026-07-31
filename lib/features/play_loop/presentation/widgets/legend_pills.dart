import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/run_config.dart';

/// The 2-tier legend row ("Hit: safe / Miss: -10%", design spec v3 §3 —
/// architecture v6 D14 reverting to the mock's literal 2-pill layout). The
/// 3-pill layout this row used to have was itself the extrapolation beyond
/// the mock; the 2-pill layout is canonical again.
///
/// In the final band this row is fully replaced by a single "Nail it ->
/// Survive" pill (design spec v1 §2.7) — never both together.
class LegendPills extends StatelessWidget {
  const LegendPills({super.key, required this.finalBand, this.config = RunConfig.defaults});

  final bool finalBand;
  final RunConfig config;

  @override
  Widget build(BuildContext context) {
    if (finalBand) {
      return const Center(child: _Pill(label: 'Nail it → Survive'));
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        const _Pill(label: 'Hit: safe'),
        _Pill(label: 'Miss: ${config.missDelta}%'),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          height: 1,
        ),
      ),
    );
  }
}
