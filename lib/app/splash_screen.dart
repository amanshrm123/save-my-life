import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../features/onboarding/name_validator.dart';
import '../features/persistence/hive_profile_repository.dart';
import '../features/persistence/profile_repository.dart';
import 'router.dart';

/// Minimum Splash display duration (§3.2) — shared by [_SplashScreenState]'s
/// navigation gating and [_PreloadBar]'s sweep animation, which must run
/// the same 900ms window.
const Duration _splashMinDuration = Duration(milliseconds: 900);

/// 1.1 Splash (docs/design/onboarding-flow-v1.md §3.2/§5.2).
///
/// Runs on **every** cold start, not just the first (§3.2) — this is app-
/// boot chrome (Hive init + `ProfileRepository` load) that happens to carry
/// the brand, not onboarding content. Only the chain into 1.2-1.5 is gated
/// by the first-launch flag, decided the instant this screen's real init
/// work resolves (`routeAfterSplash`, `router.dart`).
///
/// Auto-advances, no tap target, no Skip, no error surface of its own
/// (§3.2) — timing is exact: 900ms minimum display, 3000ms ceiling.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const Duration _minDuration = _splashMinDuration;
  static const Duration _ceiling = Duration(milliseconds: 3000);

  bool _initDone = false;
  bool _minDurationElapsed = false;
  bool _navigated = false;

  /// Best-effort default if the 3000ms ceiling fires before init resolves
  /// (§3.2) — `false` is the safer default (shows onboarding) for a
  /// genuine first-time player rather than silently skipping it.
  bool _isOnboardingComplete = false;

  Timer? _minDurationTimer;
  Timer? _ceilingTimer;

  @override
  void initState() {
    super.initState();

    _minDurationTimer = Timer(_minDuration, () {
      if (!mounted) return;
      setState(() => _minDurationElapsed = true);
      _maybeNavigate();
    });

    _ceilingTimer = Timer(_ceiling, () {
      if (!mounted) return;
      _maybeNavigate(force: true);
    });

    _runInit();
  }

  Future<void> _runInit() async {
    // Warm the profanity word list cache too (name capture is a few
    // screens away) — fire-and-forget; it never gates Splash's own timing,
    // only `ProfileRepository` does (§3.2: "Splash's only job is the brand
    // beat + routing decision").
    unawaited(ref.read(nameValidatorProvider.future));

    final ProfileRepository repository =
        await ref.read(profileRepositoryProvider.future);
    if (!mounted) return;
    setState(() {
      _initDone = true;
      _isOnboardingComplete = repository.isOnboardingComplete;
    });
    _maybeNavigate();
  }

  void _maybeNavigate({bool force = false}) {
    if (_navigated) return;
    if (!force && !(_initDone && _minDurationElapsed)) return;

    _navigated = true;
    _minDurationTimer?.cancel();
    _ceilingTimer?.cancel();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            routeAfterSplash(isOnboardingComplete: _isOnboardingComplete),
      ),
    );
  }

  @override
  void dispose() {
    _minDurationTimer?.cancel();
    _ceilingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💓', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 34,
                    color: AppColors.ink,
                  ),
                  children: [
                    const TextSpan(text: 'Stay '),
                    TextSpan(
                      text: 'Alive!',
                      style: TextStyle(
                        color: AppColors.coral,
                        shadows: [
                          Shadow(
                            color: AppColors.coralDark,
                            offset: const Offset(0, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'One tap. A thousand\nways to go.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.splashTagline,
                ),
              ),
              const SizedBox(height: 14),
              _PreloadBar(initDone: _initDone),
            ],
          ),
        ),
      ),
    );
  }
}

/// The mockup's static 70%-filled bar, made real (§3.2): sweeps 0->1 over
/// the 900ms minimum window via `TweenAnimationBuilder`, but the *displayed*
/// fraction is clamped to ~90% until [initDone] flips true, at which point
/// it snaps straight to 100% for one frame before Splash navigates away —
/// never letting the bar visually claim 100% while init is still pending.
class _PreloadBar extends StatelessWidget {
  const _PreloadBar({required this.initDone});

  final bool initDone;

  static const double _holdFraction = 0.9;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.all(1.5),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: _splashMinDuration,
        curve: Curves.linear,
        builder: (context, value, _) {
          final double displayFraction =
              initDone ? 1.0 : math.min(value, _holdFraction);
          return Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: displayFraction,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
