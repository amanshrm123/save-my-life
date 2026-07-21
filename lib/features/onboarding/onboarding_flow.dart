import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/sticker_button.dart';
import '../run/play_screen.dart';
import 'onboarding_controller.dart';
import 'widgets/skip_link.dart';
import 'widgets/teach_card_layout.dart';

/// Routes/hosts 1.2-1.5 (docs/design/onboarding-flow-v1.md §3.5, §9): the 3
/// teach cards as a `PageView`, and the name-capture screen (with its
/// built-in 8.1 error state) outside it. The `PageView` contains **only**
/// the 3 teach cards — Splash and Name-capture are separate widgets/routes
/// so a stray swipe can never carry a player past "Got it" into name
/// capture or back out into Splash (§3.5).
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static int _pageIndexFor(OnboardingStep step) {
    return switch (step) {
      OnboardingStep.teach1 => 0,
      OnboardingStep.teach2 => 1,
      OnboardingStep.teach3 => 2,
      OnboardingStep.name => -1,
    };
  }

  Future<void> _syncPageTo(OnboardingStep step) async {
    final int index = _pageIndexFor(step);
    if (index < 0 || !_pageController.hasClients) return;
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // `next()`/`finishTeaching()`/`skipToName()` calls drive `PageView`'s
    // page via animateToPage (§3.5) — Flutter's built-in transition, not a
    // custom-tuned `AnimationController`.
    ref.listen<OnboardingState>(onboardingControllerProvider,
        (previous, next) {
      if (previous?.step != next.step) {
        unawaited(_syncPageTo(next.step));
      }
    });

    final OnboardingState onboardingState =
        ref.watch(onboardingControllerProvider);

    if (onboardingState.step == OnboardingStep.name) {
      return const NameCaptureScreen();
    }

    final OnboardingController controller =
        ref.read(onboardingControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: PageView(
        controller: _pageController,
        // Swiping works "for free" and is harmless to allow — Next/Got
        // it/Skip remain the primary, always-visible path (§3.5). Manual
        // swipes must still reconcile with the controller's state, or a
        // button tap after a swipe reads a stale step and fires the wrong
        // transition (skips a card, or appears to do nothing).
        onPageChanged: controller.syncStepFromPage,
        physics: const PageScrollPhysics(),
        children: [
          TeachCard(
            // Keys give each card an unambiguous identity to scope finders
            // against in widget tests — `PageView` may keep an adjacent
            // page alive just outside the viewport, so plain
            // `find.text('Next')` can otherwise match more than one card.
            key: const ValueKey('teachCard0'),
            icon: '👆',
            heading: 'Tap on the number',
            body: 'A target time appears. Tap the instant it hits.',
            buttonLabel: 'Next',
            dotIndex: 0,
            pageController: _pageController,
            onPrimary: controller.next,
            onSkip: controller.skipToName,
          ),
          TeachCard(
            key: const ValueKey('teachCard1'),
            icon: '❤️',
            heading: 'Mind your life',
            body: "Nail it, gain life. Miss, lose it. Hit 0% and you're gone.",
            buttonLabel: 'Next',
            dotIndex: 1,
            pageController: _pageController,
            onPrimary: controller.next,
            onSkip: controller.skipToName,
          ),
          TeachCard(
            key: const ValueKey('teachCard2'),
            icon: '💀',
            heading: 'Three ways it ends',
            body: 'Die, survive a last save, or go Eternal. All shareable.',
            buttonLabel: 'Got it',
            dotIndex: 2,
            pageController: _pageController,
            onPrimary: controller.finishTeaching,
            onSkip: controller.skipToName,
          ),
        ],
      ),
    );
  }
}

/// 1.5 Name capture + 8.1 Name-rejected, implemented as one state of the
/// same widget rather than a separate route (docs/design/
/// onboarding-flow-v1.md §5.5/§5.6 — see that section for the reasoning).
class NameCaptureScreen extends ConsumerStatefulWidget {
  const NameCaptureScreen({super.key});

  @override
  ConsumerState<NameCaptureScreen> createState() => _NameCaptureScreenState();
}

class _NameCaptureScreenState extends ConsumerState<NameCaptureScreen> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _goToPlay() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PlayScreen()),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    _submitting = true;
    final bool accepted = await ref
        .read(onboardingControllerProvider.notifier)
        .submitName(_textController.text);
    _submitting = false;
    if (!mounted) return;

    if (accepted) {
      _goToPlay();
      return;
    }

    // 8.1: text is retained (not cleared), field keeps focus with the
    // existing text selected so the next keystroke replaces it (§5.6).
    _textController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _textController.text.length,
    );
    _focusNode.requestFocus();
  }

  Future<void> _skip() async {
    if (_submitting) return;
    _submitting = true;
    await ref.read(onboardingControllerProvider.notifier).skipNaming();
    _submitting = false;
    if (!mounted) return;
    _goToPlay();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError =
        ref.watch(onboardingControllerProvider.select((s) => s.nameError));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                hasError ? 'Pick another name' : 'What should we call you?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: AppColors.ink,
                ),
              ),
              if (!hasError) ...[
                const SizedBox(height: 8),
                const Text(
                  'Goes on your cards',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.teachBody,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  border: Border.all(
                    color: hasError ? AppColors.red : AppColors.ink,
                    width: 2.5,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  autofocus: true,
                  maxLength: 12,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => ref
                      .read(onboardingControllerProvider.notifier)
                      .clearNameError(),
                  onSubmitted: (_) => _submit(),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: hasError ? AppColors.red : AppColors.ink,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '', // custom counter rendered below instead
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (!hasError)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'On your cards',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: AppColors.mute,
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _textController,
                      builder: (context, value, _) {
                        return Text(
                          '${value.text.length}/12',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            color: AppColors.mute,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              if (hasError) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.noteBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '⚠ That word isn\'t allowed — it shows on shared cards.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.red,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: StickerButton(
                  label: hasError ? 'Try again' : 'Start playing',
                  fillColor: AppColors.coral,
                  textShadowColor: AppColors.coralDark,
                  onPressed: _submit,
                ),
              ),
              const SizedBox(height: 16),
              SkipLink(label: 'Skip for now', onTap: _skip),
            ],
          ),
        ),
      ),
    );
  }
}
