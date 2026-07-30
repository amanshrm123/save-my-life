import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/avatar_spec.dart';

const double _kToggleHeight = 40;
const double _kToggleInset = 2;

/// The Male/Female segmented toggle (design `home-avatars-v1.md` §5.2) — a
/// genuinely new component, no existing segmented-control precedent in this
/// codebase. Local, uncommitted UI state only; the picker screen owns the
/// actual `AvatarGender` value and passes it down.
class AvatarGenderToggle extends StatelessWidget {
  const AvatarGenderToggle({super.key, required this.value, required this.onChanged});

  final AvatarGender value;
  final ValueChanged<AvatarGender> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kToggleHeight,
      padding: const EdgeInsets.all(_kToggleInset),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(_kToggleHeight / 2),
        border: Border.all(color: AppColors.ink, width: 2.5),
        boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(0, 3), blurRadius: 0)],
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: 'Male',
              active: value == AvatarGender.male,
              onTap: () => onChanged(AvatarGender.male),
            ),
          ),
          Expanded(
            child: _Segment(
              label: 'Female',
              active: value == AvatarGender.female,
              onTap: () => onChanged(AvatarGender.female),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.coral : Colors.transparent,
            borderRadius: BorderRadius.circular((_kToggleHeight - _kToggleInset * 2) / 2),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
