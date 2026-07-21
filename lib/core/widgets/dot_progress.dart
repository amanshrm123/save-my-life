import 'package:flutter/material.dart';

import '../theme.dart';

/// The mockup's `.dots`/`.dots i.on` progress indicator
/// (docs/design/onboarding-flow-v1.md §5.4). Fixed 3-dot row for the
/// teaching-card sequence — no dynamic count needed this pass.
class DotProgress extends StatelessWidget {
  const DotProgress({
    super.key,
    required this.activeIndex,
    this.count = 3,
  });

  /// 0-based index of the current/filled dot.
  final int activeIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (int i) {
        final bool isActive = i == activeIndex;
        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: 1.5),
              color: isActive ? AppColors.coral : AppColors.paper2,
            ),
          ),
        );
      }),
    );
  }
}
