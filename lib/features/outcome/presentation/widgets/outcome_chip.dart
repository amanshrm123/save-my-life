import 'package:flutter/material.dart';

/// Top-left status chip (design v1 §3 anatomy / §5 typography) — replaces
/// `OutcomeBadge`. A plain pill, uppercase, 10dp/700/.12em letter-spacing;
/// no border, no shadow — the sticker pattern doesn't extend inside this
/// card shell (design v1 §2.1). All dimensions scale by [k] (design v1 §2.2).
class OutcomeChip extends StatelessWidget {
  const OutcomeChip({
    super.key,
    required this.label,
    required this.fill,
    required this.textColor,
    required this.k,
  });

  final String label;
  final Color fill;
  final Color textColor;
  final double k;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * k, vertical: 5 * k),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(99)),
      // `FittedBox` so a caller that bounds this chip's width (e.g. the top
      // row's `Flexible`, when a tier's copy runs long — Eternal's "✨
      // Eternal · Top 0.3%") gets a scaled-down label instead of an
      // overflowing one; a no-op when there's already enough room.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 10 * k,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2 * k,
            color: textColor,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
