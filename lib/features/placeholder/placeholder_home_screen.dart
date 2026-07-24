import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sticker_button.dart';
import '../onboarding/state/onboarding_providers.dart';

/// Home screen: proof that the profile survived the onboarding flow (or was
/// already complete on a prior launch) and is readable from RAM, plus the
/// entry point into the Play Loop (architecture v2 §8).
class PlaceholderHomeScreen extends ConsumerWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(playerProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                profileAsync.when(
                  data: (profile) => Text(
                    profile.isAnonymous
                        ? "You're in"
                        : "You're in, ${profile.name}",
                    textAlign: TextAlign.center,
                    style: AppTypography.headline,
                  ),
                  loading: () => const CircularProgressIndicator(
                    color: AppColors.green,
                  ),
                  error: (error, stackTrace) => const Text(
                    "You're in",
                    textAlign: TextAlign.center,
                    style: AppTypography.headline,
                  ),
                ),
                const SizedBox(height: 24),
                StickerButton(
                  label: 'Play',
                  fill: AppColors.coral,
                  labelShadow: AppColors.coralDark,
                  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.play),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
