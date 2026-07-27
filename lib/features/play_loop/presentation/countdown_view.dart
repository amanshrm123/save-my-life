import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../onboarding/state/onboarding_providers.dart';
import '../domain/run_config.dart';
import '../state/play_loop_providers.dart';

/// Screen 2.2 — the 3-2-1 countdown. A pure timer, no player input: ticks
/// down automatically, then arms the run the instant it hits zero
/// (architecture v2 §5). Named "Hey `<name>`, get ready..." reusing the
/// existing `PlayerProfile.isAnonymous` pattern from onboarding, falling
/// back to "Get ready..." for anonymous players (design spec v1 §2.2).
class CountdownView extends ConsumerStatefulWidget {
  const CountdownView({super.key});

  @override
  ConsumerState<CountdownView> createState() => _CountdownViewState();
}

class _CountdownViewState extends ConsumerState<CountdownView>
    with SingleTickerProviderStateMixin {
  static const RunConfig _config = RunConfig.defaults;

  late final AnimationController _popController;
  late final Animation<double> _pop;

  int _step = _config.countdownSteps;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _pop = Tween<double>(
      begin: 1.15,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _popController, curve: Curves.easeOut));
    _popController.forward(from: 0);
    _scheduleNextStep();
  }

  void _scheduleNextStep() {
    Future.delayed(Duration(milliseconds: _config.countdownStepMs), () {
      if (_disposed || !mounted) return;
      if (_step <= 1) {
        ref.read(runControllerProvider.notifier).arm();
        return;
      }
      setState(() => _step -= 1);
      HapticFeedback.lightImpact();
      _popController.forward(from: 0);
      _scheduleNextStep();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(playerProfileProvider);
    final name = profileAsync.maybeWhen(
      data: (profile) => profile.isAnonymous ? null : profile.name,
      orElse: () => null,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Greeting(name: name),
            const SizedBox(height: 20),
            ScaleTransition(
              scale: _pop,
              child: Container(
                width: 96,
                height: 96,
                margin: const EdgeInsets.only(top: 6, bottom: 6),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold,
                  border: Border.fromBorderSide(BorderSide(color: AppColors.ink, width: 3)),
                  boxShadow: [BoxShadow(color: AppColors.ink, offset: Offset(0, 6))],
                ),
                alignment: Alignment.center,
                child: Text(
                  '$_step',
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 50,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    height: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'First target drops when it hits zero.',
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});

  final String? name;

  static const TextStyle _style = TextStyle(
    fontFamily: 'Fredoka',
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.1,
  );

  @override
  Widget build(BuildContext context) {
    if (name == null) {
      return const Text('Get ready…', style: _style);
    }
    return Text.rich(
      TextSpan(
        style: _style,
        children: [
          const TextSpan(text: 'Hey '),
          TextSpan(text: name, style: const TextStyle(color: AppColors.coral)),
          const TextSpan(text: ', get ready…'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
