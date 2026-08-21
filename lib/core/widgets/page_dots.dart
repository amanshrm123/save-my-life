import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Page-indicator dots — originally the onboarding teach cards' 3-dot
/// indicator (design spec v1 §1.5); promoted here once the Home tour
/// (onboarding-tour v1 §7) became a second consumer with `count: 4`. Reused
/// across more than one feature, so it lives in `core/widgets/` per this
/// codebase's convention (`sticker_button.dart`, `toast_pill.dart`). No
/// behavior or visual change from the original.
///
/// Renders nothing meaningful on a lone page — callers simply don't build
/// this widget where it doesn't apply, rather than hiding it.
class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.activeIndex, this.count = 3});

  final int activeIndex;
  final int count;

  static const double _diameter = 7;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'page ${activeIndex + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          final isActive = i == activeIndex;
          return Padding(
            padding: EdgeInsets.only(right: i == count - 1 ? 0 : _gap),
            child: Container(
              width: _diameter,
              height: _diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? AppColors.coral : AppColors.dotInactive,
                border: Border.all(color: AppColors.ink, width: 1.5),
              ),
            ),
          );
        }),
      ),
    );
  }
}
