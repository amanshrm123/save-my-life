import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/name_validator.dart';
import '../state/onboarding_providers.dart';
import 'widgets/name_capture_view.dart';
import 'widgets/teach_card.dart';

/// Hosts the single `PageController` driving the 4-page `PageView`
/// (architecture v1 §2): 3 teach cards + name capture. One controller /
/// one text controller for the whole flow keeps the memory-safety surface
/// small (architecture v1 §8.2).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  static const int _lastPage = 3;
  static const NameValidator _validator = NameValidator();

  late final PageController _pageController;
  late final TextEditingController _nameController;
  late final AnimationController _shakeController;
  late final Animation<double> _shake;

  int _currentPage = 0;
  bool _pageAnimating = false;
  bool _submitting = false;
  bool _nameRejected = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _nameController = TextEditingController();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0), weight: 1),
    ]).animate(_shakeController);
    // Clear a stale rejection banner the moment the player edits the name
    // again. Removed in dispose() per architecture v1 §8.8.
    _nameController.addListener(_clearRejectionOnEdit);
  }

  void _clearRejectionOnEdit() {
    if (_nameRejected) {
      setState(() => _nameRejected = false);
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_clearRejectionOnEdit);
    _pageController.dispose();
    _nameController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _goToPage(int target) async {
    final clamped = target.clamp(0, _lastPage);
    if (_pageAnimating || clamped == _currentPage) return;
    _pageAnimating = true;
    await _pageController.animateToPage(
      clamped,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
    _pageAnimating = false;
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  Future<void> _finishOnboarding(Future<void> Function() writeProfile) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await writeProfile();
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save that — try again.")),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  Future<void> _onStartPlaying() async {
    if (_submitting) return;
    final result = _validator.validate(_nameController.text);
    if (!result.isValid) {
      HapticFeedback.mediumImpact();
      setState(() => _nameRejected = true);
      _shakeController.forward(from: 0);
      return;
    }
    await _finishOnboarding(
      () => ref.read(playerProfileProvider.notifier).completeWithName(
        result.sanitized,
      ),
    );
  }

  Future<void> _onSkip() async {
    if (_submitting) return;
    await _finishOnboarding(
      () => ref.read(playerProfileProvider.notifier).completeAnonymous(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goToPage(_currentPage - 1);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          children: [
            TeachCard(
              emoji: '👆',
              emojiSemanticLabel: 'pointing finger',
              headline: 'Tap on the number',
              body: 'A target time appears. Tap the instant it hits.',
              dotIndex: 0,
              buttonLabel: 'Next',
              onButtonPressed: () => _goToPage(1),
            ),
            TeachCard(
              emoji: '❤️',
              emojiSemanticLabel: 'red heart',
              headline: 'Mind your life',
              body:
                  'Nail it, gain life. Miss, lose it. Hit 0% and you\'re gone.',
              dotIndex: 1,
              buttonLabel: 'Next',
              onButtonPressed: () => _goToPage(2),
            ),
            TeachCard(
              emoji: '🔀',
              emojiSemanticLabel: 'shuffle',
              headline: 'Three ways it ends',
              body: 'Die, survive a last save, or go Eternal. All shareable.',
              dotIndex: 2,
              buttonLabel: 'Got it',
              onButtonPressed: () => _goToPage(3),
            ),
            NameCaptureView(
              controller: _nameController,
              rejected: _nameRejected,
              submitting: _submitting,
              onStartPlaying: _onStartPlaying,
              onSkip: _onSkip,
              shakeAnimation: _shake,
            ),
          ],
        ),
      ),
    );
  }
}
