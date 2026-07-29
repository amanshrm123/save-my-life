import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/sticker_button.dart';
import '../domain/avatar_catalog.dart';
import '../domain/avatar_constants.dart';
import '../domain/avatar_spec.dart';
import '../state/avatar_providers.dart';
import 'widgets/avatar_gender_toggle.dart';
import 'widgets/avatar_tile.dart';

/// The avatar picker (design `home-avatars-v1.md` §5) — pushed from Home's
/// avatar card. Draft-then-commit (§5.4): the gender tab and grid selection
/// are local `State` only, initialized from the currently-committed
/// `selectedAvatarProvider` value; nothing is written back to the
/// repository until "Use this avatar" is tapped.
class AvatarPickerScreen extends ConsumerStatefulWidget {
  const AvatarPickerScreen({super.key});

  @override
  ConsumerState<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends ConsumerState<AvatarPickerScreen> {
  late AvatarGender _gender;
  int? _selectedId;
  bool _committing = false;

  @override
  void initState() {
    super.initState();
    // `AvatarCatalog.byId` already clamps/falls back for any id outside the
    // valid 0-11 range (including the never-picked `-1` sentinel *and* any
    // other out-of-range int, e.g. from a corrupted/tampered prefs value) —
    // deriving both fields from its returned spec avoids re-implementing
    // that same clamping (badly, via `< 6` gender math and a bare `-1`
    // check) here.
    final spec = AvatarCatalog.byId(ref.read(selectedAvatarProvider));
    _gender = spec.gender;
    _selectedId = spec.id;
  }

  void _onGenderChanged(AvatarGender gender) {
    if (gender == _gender) return;
    // §5.2: switching gender resets the grid selection — never carry a
    // variant index across onto a visually different id the player never
    // looked at.
    setState(() {
      _gender = gender;
      _selectedId = null;
    });
  }

  Future<void> _onCommit() async {
    if (_committing) return;
    final id = _selectedId;
    if (id == null) return;
    setState(() => _committing = true);
    await ref.read(selectedAvatarProvider.notifier).commit(id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tiles = AvatarCatalog.forGender(_gender);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenHeader(emoji: '🧑', title: 'Choose your avatar'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: AvatarGenderToggle(value: _gender, onChanged: _onGenderChanged),
            ),
            Expanded(
              child: GridView.count(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: kAvatarCardAspectRatio,
                children: [
                  for (final spec in tiles)
                    AvatarTile(
                      spec: spec,
                      selected: spec.id == _selectedId,
                      onTap: () => setState(() => _selectedId = spec.id),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: StickerButton(
                label: 'Use this avatar',
                fill: AppColors.coral,
                labelShadow: AppColors.coralDark,
                height: 50,
                enabled: _selectedId != null && !_committing,
                onPressed: _selectedId == null || _committing ? null : _onCommit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
