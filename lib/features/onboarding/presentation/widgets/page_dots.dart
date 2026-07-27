import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// 3-dot page indicator for the teach cards (design spec v1 §1.5). Renders
/// nothing on the name-capture page — callers simply don't build this
/// widget on page 3 rather than hiding it, per architecture's PageView
/// table.
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
