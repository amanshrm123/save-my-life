import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/note_chip.dart';
import '../../../../core/widgets/sticker_button.dart';
import '../../../onboarding/domain/name_validator.dart';
import '../../../onboarding/state/onboarding_providers.dart';

/// Settings' "edit name" dialog (design v3 §6.3) — not shown anywhere in the
/// mockup, spec'd there: Play Loop's pause-modal container convention (scrim
/// + `bg` card, 3dp border, 22dp radius, 8dp shadow) + onboarding's exact
/// name-input styling and inline-rejection treatment, reused verbatim.
Future<void> showEditNameDialog(
  BuildContext context, {
  required String initialName,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.ink.withValues(alpha: 0.55),
    builder: (context) => EditNameDialog(initialName: initialName),
  );
}

class EditNameDialog extends ConsumerStatefulWidget {
  const EditNameDialog({super.key, required this.initialName});

  final String initialName;

  @override
  ConsumerState<EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends ConsumerState<EditNameDialog> {
  static const NameValidator _validator = NameValidator();
  static const int _maxLength = NameValidator.maxLength;

  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  NameRejectReason? _rejectReason;
  bool _submitting = false;

  bool get _rejected => _rejectReason != null;

  /// Per-[NameRejectReason] copy — bug fix: this dialog used to show the
  /// profanity-specific "That word isn't allowed" note for every rejection
  /// reason (too short, too long, illegal characters, empty), which is
  /// actively misleading for e.g. a 1-character name. Onboarding's
  /// `NameCaptureView` avoids this by live-disabling its submit button for
  /// every reason except [NameRejectReason.disallowedWord] (checked only on
  /// submit, per architecture v1 §5) — this dialog has no live gate, so it
  /// needs its own accurate message per reason instead.
  String _messageFor(NameRejectReason reason) {
    switch (reason) {
      case NameRejectReason.empty:
        return 'Enter a name first';
      case NameRejectReason.tooShort:
        return 'Too short — at least ${NameValidator.minLength} characters';
      case NameRejectReason.tooLong:
        return 'Too long — ${NameValidator.maxLength} characters max';
      case NameRejectReason.illegalChars:
        return 'Only letters, numbers, spaces, and emoji are allowed';
      case NameRejectReason.disallowedWord:
        return "That word isn't allowed — it shows on shared cards";
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (_submitting) return;
    final result = _validator.validate(_controller.text);
    if (!result.isValid) {
      HapticFeedback.mediumImpact();
      setState(() => _rejectReason = result.reason);
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(playerProfileProvider.notifier)
          .updateName(result.sanitized);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _onCancel() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    // `showDialog`'s route doesn't itself provide a `Material` ancestor —
    // only `AlertDialog`/`Dialog` do that, and this deliberately isn't one
    // (a custom `bg`-card look, not Material's default shape). The
    // `TextField` below needs a `Material` ancestor regardless, so this
    // supplies one transparently rather than pulling in Material's own
    // dialog chrome.
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.ink, width: 3),
            boxShadow: const [
              BoxShadow(
                color: AppColors.ink,
                offset: Offset(0, 8),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _rejected ? 'Pick another name' : 'Edit name',
                style: const TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _rejected ? AppColors.red : AppColors.ink,
                    width: 2.5,
                  ),
                ),
                alignment: Alignment.center,
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.words,
                  maxLength: _maxLength,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  style: AppTypography.inputText.copyWith(
                    color: _rejected ? AppColors.red : AppColors.ink,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                  onChanged: (_) {
                    if (_rejected) setState(() => _rejectReason = null);
                  },
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${value.text.characters.length}/$_maxLength',
                          style: AppTypography.helper,
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (_rejectReason case final reason?) ...[
                const SizedBox(height: 8),
                NoteChip.error(text: _messageFor(reason)),
              ],
              const SizedBox(height: 16),
              StickerButton(
                label: _rejected ? 'Try again' : 'Save',
                fill: AppColors.coral,
                labelShadow: AppColors.coralDark,
                enabled: !_submitting,
                onPressed: _onSave,
              ),
              const SizedBox(height: 10),
              StickerButton(
                label: 'Cancel',
                fill: AppColors.paper,
                labelShadow: AppColors.ink,
                textColor: AppColors.ink,
                showLabelTextShadow: false,
                height: 40,
                borderRadius: 14,
                fontSize: 13,
                restShadowOffset: 4,
                onPressed: _onCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
