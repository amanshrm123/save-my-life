import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The Run chip + pause icon button (design spec v2 §1.2/§1.3, §2.1's
/// "revision summary") — row a of the new combined `PlayHudBar`. The Deaths
/// chip is gone entirely (design spec v2 §1.1: a deletion, not a swap — no
/// replacement counter). `RunState.deaths` itself is untouched; it's simply
/// no longer rendered here.
class RunChips extends StatelessWidget {
  const RunChips({super.key, required this.runNumber, required this.onPause});

  final int runNumber;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip(label: 'Run #', value: '$runNumber'),
        const Spacer(),
        _PauseIconButton(onPressed: onPause),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value});

  /// The label span, rendered verbatim (design spec v2 §1.3: "Run #", with
  /// the `#` immediately followed by the bare number span, no extra space).
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
            TextSpan(text: label),
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
