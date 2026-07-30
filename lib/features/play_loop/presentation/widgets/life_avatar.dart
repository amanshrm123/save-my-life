import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../avatar/domain/avatar_catalog.dart';
import '../../../avatar/presentation/widgets/avatar_figure.dart';
import '../../../avatar/state/avatar_providers.dart';

/// The in-run life-meter (design spec v2 §1.2): the player's own avatar
/// figure, reused from Home, doubling as the top HUD row's life gauge.
///
/// The fill color is driven **purely** by [lifePercent] via `AvatarFigure`'s
/// existing `avatarFillColorForPercent` band function — no tier-tint flash,
/// no final-band-forced-red override (design spec v2 §1.1/§1.2: an explicit,
/// founder-confirmed simplification). `AvatarCatalog.byId` already falls
/// back safely for a never-picked player (`-1`), so no empty/error state is
/// needed here.
///
/// Deliberately no `RepaintBoundary` — product-architect rejected one for
/// this rarely-changing, non-60fps element on memory-cost grounds.
class LifeAvatar extends ConsumerWidget {
  const LifeAvatar({super.key, required this.lifePercent});

  /// 0-100. Forwarded straight to `AvatarFigure.fillPercent`.
  final int lifePercent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarId = ref.watch(selectedAvatarProvider);
    final spec = AvatarCatalog.byId(avatarId);

    // CRITICAL: `AvatarFigure`'s intrinsic paint size is 84x104 — this
    // SizedBox+FittedBox wrapping is load-bearing (design spec v2 §1.2),
    // otherwise the figure renders at the wrong size and blows the HUD
    // row's 72dp height budget.
    return SizedBox(
      width: 58,
      height: 72,
      child: FittedBox(
        fit: BoxFit.contain,
        child: AvatarFigure(spec: spec, fillPercent: lifePercent, shouldAnimate: true),
      ),
    );
  }
}
