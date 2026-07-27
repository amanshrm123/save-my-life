import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sticker_button.dart';
import '../../domain/name_validator.dart';

/// Page 3 body (design spec v1 §2.5): name input + "Start playing" (primary,
/// coral) / "Skip for now" (secondary, bare text link) + the inline
/// profanity-rejection state.
///
/// Ephemeral text state stays in the [controller] the parent
/// (`OnboardingScreen`) owns and disposes (architecture v1 §8.2) — this
/// widget only reads it via a [ValueListenableBuilder] so per-keystroke
/// rebuilds stay scoped to this subtree and no manual listener teardown is
/// needed (architecture v1 §8.8).
class NameCaptureView extends StatelessWidget {
  const NameCaptureView({
    super.key,
    required this.controller,
    required this.rejected,
    required this.submitting,
    required this.onStartPlaying,
    required this.onSkip,
    required this.shakeAnimation,
  });

  final TextEditingController controller;
  final bool rejected;
  final bool submitting;
  final VoidCallback onStartPlaying;
  final VoidCallback onSkip;
  final Animation<double> shakeAnimation;

  static const int _maxLength = NameValidator.maxLength;

  /// Live gate for "Start playing": non-empty and passing the character-set
  /// rule (architecture §5 rules 1-3). Profanity (rule 4) is deliberately
  /// checked only on submit, not live, per architecture v1 §5.
  bool _liveValid(String text) {
    final result = const NameValidator().validate(text);
    return result.isValid || result.reason == NameRejectReason.disallowedWord;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: 'writing hand',
                  excludeSemantics: true,
                  child: const Text('✍️', style: TextStyle(fontSize: 38)),
                ),
                const SizedBox(height: 10),
                Text(
                  rejected ? 'Pick another name' : 'What should we call you?',
                  textAlign: TextAlign.center,
                  style: AppTypography.headline,
                ),
                const SizedBox(height: 10),
                Text(
                  'Goes on your cards.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body,
                ),
                const SizedBox(height: 10),
                AnimatedBuilder(
                  animation: shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(shakeAnimation.value, 0),
                      child: child,
                    );
                  },
                  child: _NameInput(
                    controller: controller,
                    rejected: rejected,
                    maxLength: _maxLength,
                  ),
                ),
                if (rejected) ...[
                  const SizedBox(height: 8),
                  _RejectionNote(),
                ],
                const SizedBox(height: 16),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final enabled =
                        !submitting && _liveValid(value.text);
                    return StickerButton(
                      label: rejected ? 'Try again' : 'Start playing',
                      fill: AppColors.coral,
                      labelShadow: AppColors.coralDark,
                      enabled: enabled,
                      onPressed: onStartPlaying,
                    );
                  },
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: submitting ? null : onSkip,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Skip for now', style: AppTypography.ghostLink),
                  ),
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NameInput extends StatelessWidget {
  const _NameInput({
    required this.controller,
    required this.rejected,
    required this.maxLength,
  });

  final TextEditingController controller;
  final bool rejected;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    final borderColor = rejected ? AppColors.red : AppColors.ink;
    final textColor = rejected ? AppColors.red : AppColors.ink;

    return Column(
      children: [
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 2.5),
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.words,
            maxLength: maxLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            style: AppTypography.inputText.copyWith(color: textColor),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              isCollapsed: true,
              hintText: 'e.g. Aman',
              hintStyle: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.mute,
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final count = value.text.characters.length;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('On your cards', style: AppTypography.helper),
                  Text('$count/$maxLength', style: AppTypography.helper),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RejectionNote extends StatelessWidget {
  const _RejectionNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        "That word isn't allowed — it shows on shared cards",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.red,
        ),
      ),
    );
  }
}
