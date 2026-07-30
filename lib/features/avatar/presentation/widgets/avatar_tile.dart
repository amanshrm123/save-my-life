import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/avatar_spec.dart';
import 'avatar_figure.dart';

/// One grid tile in `AvatarPickerScreen` (design `home-avatars-v1.md` §5.3):
/// same sticker weight as `StatTile`/`HomeAvatarCard` (2.5dp/4dp) but a
/// tighter 10dp radius, since a grid of small tiles reads closer to the stat
/// tiles than to a single hero card. Always previews at a fixed demo
/// `fillPercent: 100` (§3.4) — the picker is about choosing a look, not
/// reporting the player's actual life stat.
class AvatarTile extends StatelessWidget {
  const AvatarTile({super.key, required this.spec, required this.selected, required this.onTap});

  final AvatarSpec spec;
  final bool selected;
  final VoidCallback onTap;

  static const int _demoFillPercent = 100;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.coral : AppColors.ink;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor, width: 2.5),
                boxShadow: [BoxShadow(color: borderColor, offset: const Offset(0, 4), blurRadius: 0)],
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: AvatarFigure(spec: spec, fillPercent: _demoFillPercent),
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(color: AppColors.coral, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
