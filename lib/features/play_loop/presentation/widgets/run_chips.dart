import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Persistent gameplay topbar: Run chip + Deaths chip + pause icon button,
/// all three, present throughout Armed/Running/Stopped/FinalBand (design
/// spec v1 §3.6 — reconciles the mock's two inconsistent topbar frames via
/// architecture's own file-layout hint that this is a single combined
/// widget). Chips never reskin, even in the final band (§2.7 table).
class RunChips extends StatelessWidget {
  const RunChips({
    super.key,
    required this.runNumber,
    required this.deaths,
    required this.onPause,
  });

  final int runNumber;
  final int deaths;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip(label: 'Run', value: '$runNumber'),
        const SizedBox(width: 8),
        _Chip(label: 'Deaths', value: '$deaths'),
        const Spacer(),
        _PauseIconButton(onPressed: onPause),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            height: 1,
          ),
          children: [
            TextSpan(text: '$label '),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _PauseIconButton extends StatelessWidget {
  const _PauseIconButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Pause',
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.paper,
            border: Border.all(color: AppColors.ink, width: 2),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.pause, size: 12, color: AppColors.ink),
        ),
      ),
    );
  }
}
