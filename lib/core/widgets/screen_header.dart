import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The `.scrhead` header bar (design v3 §5.4/§6.1), shared by Stats and
/// Settings: emoji + title, padding 10/16/0. Adds a standard leading back
/// chevron — the mockup's screenshots crop it out, but every sub-screen
/// reached from Home needs one (design v3 §5.4/§9's resolved recommendation).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.emoji, required this.title});

  final String emoji;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 16, top: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.ink),
            tooltip: 'Back',
          ),
          const SizedBox(width: 2),
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
