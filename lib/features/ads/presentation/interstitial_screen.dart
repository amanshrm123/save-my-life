import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The 5.1 interstitial placeholder creative (design v3 §4.1/§4.2) —
/// deliberately off-palette dark-navy "someone else's ad" chrome, entirely
/// decorative (not a real ad-network creative, architecture v3 §5).
///
/// Close (✕) is immediately effective at any time; the countdown
/// auto-advances if the player doesn't close it first — both paths call
/// [onDone] exactly once (guarded by `_handedOff` + `mounted`, architecture
/// §11 risk 3), since nothing is being earned here (unlike rewarded).
class InterstitialScreen extends StatefulWidget {
  const InterstitialScreen({super.key, required this.onDone, this.durationSeconds = 4});

  final VoidCallback onDone;
  final int durationSeconds;

  @override
  State<InterstitialScreen> createState() => _InterstitialScreenState();
}

class _InterstitialScreenState extends State<InterstitialScreen> {
  late int _secondsLeft = widget.durationSeconds;
  Timer? _timer;
  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTick(Timer timer) {
    if (!mounted) return;
    setState(() => _secondsLeft -= 1);
    if (_secondsLeft <= 0) {
      _finish();
    }
  }

  void _finish() {
    if (_handedOff) return;
    _handedOff = true;
    _timer?.cancel();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _finish();
      },
      child: Scaffold(
        backgroundColor: AppColors.adBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _ChipLabel(text: 'AD'),
                    _CloseButton(onTap: _finish),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.coral, AppColors.gold],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Semantics(
                            label: 'video game controller',
                            excludeSemantics: true,
                            child: Text('🎮', style: TextStyle(fontSize: 40)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Puzzle Quest 3',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '#1 match-3 adventure',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.adSubtext,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _InstallButton(),
                      ],
                    ),
                  ),
                ),
                Text(
                  'Next run loading… · closes in ${_secondsLeft}s',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: AppColors.adFootText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.adChipBg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close ad',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.adChipBg),
          alignment: Alignment.center,
          child: const Icon(Icons.close, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

class _InstallButton extends StatelessWidget {
  const _InstallButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.adInstallFill,
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Text(
        'Install',
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.adInstallText,
        ),
      ),
    );
  }
}
