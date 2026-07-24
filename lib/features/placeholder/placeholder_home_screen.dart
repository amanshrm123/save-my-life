import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../onboarding/state/onboarding_providers.dart';

/// Temporary handoff target for the future Play Loop feature. Genuinely
/// minimal — just proof that the profile survived the onboarding flow (or
/// was already complete on a prior launch) and is readable from RAM.
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
            child: profileAsync.when(
              data: (profile) => Text(
                profile.isAnonymous
                    ? "You're in — Play Loop coming soon"
                    : "You're in, ${profile.name} — Play Loop coming soon",
                textAlign: TextAlign.center,
                style: AppTypography.headline,
              ),
              loading: () => const CircularProgressIndicator(
                color: AppColors.green,
              ),
              error: (error, stackTrace) => const Text(
                "You're in — Play Loop coming soon",
                textAlign: TextAlign.center,
                style: AppTypography.headline,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
