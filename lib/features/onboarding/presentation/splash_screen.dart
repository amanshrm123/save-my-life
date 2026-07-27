import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/app_page_transitions.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/presentation/home_screen.dart';
import '../../notifications/state/reminder_providers.dart';
import '../domain/player_profile.dart';
import '../state/onboarding_providers.dart';
import 'onboarding_screen.dart';

/// Screen 1.1 — brand mark + preload bar (design spec v1 §2.1).
///
/// Reads the profile once via the provider, holds a short brand beat (a
/// `Future.delayed`, not a bare `Timer`), then branches on
/// `onboarding_complete` — with a `mounted` check before navigating
/// (architecture v1 §8.6).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _progressDuration = Duration(milliseconds: 1400);
  static const Duration _holdDuration = Duration(milliseconds: 175);

  late final AnimationController _progressController;
  late final CurvedAnimation _progress;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: _progressDuration,
    );
    _progress = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOut,
    );
    _runSplash();
  }

  Future<void> _runSplash() async {
    final profileFuture = ref.read(playerProfileProvider.future);
    _progressController.forward();

    // App-start reconciliation (architecture v3 §11 risk 1) — fire-and-
    // forget, never gates navigation; a failed/no-op reschedule is swallowed
    // by `ReminderController`/`ReminderService` themselves.
    unawaited(ref.read(reminderControllerProvider.notifier).reconcile());

    final results = await Future.wait<Object?>([
      profileFuture,
      Future<void>.delayed(_progressDuration + _holdDuration),
    ]);

    // The user may have backgrounded/killed the app while the brand beat or
    // the prefs read was in flight — never navigate a dead tree.
    if (!mounted) return;

    final profile = results[0] as PlayerProfile;
    final goingHome = profile.onboardingComplete;
    Navigator.of(context).pushReplacement(
      fadeSlideRoute(
        settings: RouteSettings(
          name: goingHome ? AppRoutes.home : AppRoutes.onboarding,
        ),
        builder: (context) => goingHome
            ? const HomeScreen()
            : const OnboardingScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _progress.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: 'beating heart',
                  excludeSemantics: true,
                  child: const Text('💓', style: TextStyle(fontSize: 38)),
                ),
                const SizedBox(height: 10),
                const Text('Stay', style: AppTypography.wordmark),
                Text(
                  'Alive!',
                  style: AppTypography.wordmark.copyWith(
                    color: AppColors.coral,
                    shadows: const [
                      Shadow(
                        color: AppColors.coralDark,
                        offset: Offset(0, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: (MediaQuery.sizeOf(context).width * 0.78)
                        .clamp(0, 320)
                        .toDouble(),
                  ),
                  child: const Text(
                    'One tap. A thousand ways to go.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body,
                  ),
                ),
                const SizedBox(height: 14),
                _ProgressBar(progress: _progress),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final Animation<double> progress;

  static const double _width = 110;
  static const double _height = 8;
  static const double _inset = 1.5;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _width,
      height: _height,
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(_height / 2),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: progress,
            builder: (context, _) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: constraints.maxWidth * progress.value,
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(
                      (_height - _inset * 2) / 2,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
