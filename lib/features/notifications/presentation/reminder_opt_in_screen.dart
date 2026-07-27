import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sticker_button.dart';
import '../../settings/state/settings_providers.dart';
import '../state/reminder_providers.dart';

/// 8.4 Notification opt-in (design v3 §7) — shown once, in context, after
/// the streak reaches day 2 (architecture §8), reached via a push from Home
/// (unlike 6.2/6.3, this is a real route, not a Home-body-replacement
/// state). "No thanks" here is a proper boxed `.ghostbtn` — not a bare text
/// link like onboarding's "Skip for now" (design v3 §7's explicit call-out).
class ReminderOptInScreen extends ConsumerStatefulWidget {
  const ReminderOptInScreen({super.key});

  @override
  ConsumerState<ReminderOptInScreen> createState() => _ReminderOptInScreenState();
}

class _ReminderOptInScreenState extends ConsumerState<ReminderOptInScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Marked shown the instant this screen is displayed, regardless of
    // which choice the player makes — the once-only gate is about ever
    // having been shown, not about the outcome (architecture §8).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(settingsRepositoryProvider).setReminderOptInShown(true);
    });
  }

  Future<void> _onRemindMe() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(reminderControllerProvider.notifier).enable();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _onNoThanks() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: 'bell',
                  excludeSemantics: true,
                  child: Text('🔔', style: TextStyle(fontSize: 34)),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Keep your streak alive?',
                  textAlign: TextAlign.center,
                  style: AppTypography.headline,
                ),
                const SizedBox(height: 10),
                const Text(
                  "A daily nudge so you don't lose your streak. No spam.",
                  textAlign: TextAlign.center,
                  style: AppTypography.body,
                ),
                const SizedBox(height: 22),
                StickerButton(
                  label: 'Remind me daily',
                  fill: AppColors.coral,
                  labelShadow: AppColors.coralDark,
                  enabled: !_busy,
                  onPressed: _onRemindMe,
                ),
                const SizedBox(height: 10),
                StickerButton(
                  label: 'No thanks',
                  fill: AppColors.paper,
                  labelShadow: AppColors.ink,
                  textColor: AppColors.ink,
                  showLabelTextShadow: false,
                  height: 40,
                  borderRadius: 14,
                  fontSize: 13,
                  restShadowOffset: 4,
                  enabled: !_busy,
                  onPressed: _onNoThanks,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
