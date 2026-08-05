import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/monitoring/sentry_config.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/screen_header.dart';
import '../../avatar/state/avatar_providers.dart';
import '../../notifications/state/reminder_providers.dart';
import '../../onboarding/state/onboarding_providers.dart';
import '../../outcome/state/outcome_providers.dart';
import '../../progression/state/stats_providers.dart';
import 'widgets/edit_name_dialog.dart';
import 'widgets/reset_confirm_dialog.dart';
import 'widgets/settings_toggle.dart';
import '../state/settings_providers.dart';

/// Founder-provided URLs don't exist yet — clearly-marked placeholders per
/// architecture v3 §1 item 6 / §12 flag 6. Swap for real content whenever
/// it's provided; no code change needed beyond these constants. The actual
/// content for the first two already exists (repo-root PRIVACY.md/TERMS.md)
/// — only hosting them at these URLs (or an equivalent real host) remains.
const String _kPrivacyUrl = 'https://stayalive.app/privacy';
const String _kTermsUrl = 'https://stayalive.app/terms';
const String _kRateUrl = 'https://stayalive.app/rate';

/// One scrollable Settings screen (design v3 §6.1) — the mockup's two
/// phone-frame screenshots (7.1 toggles/name, 7.2 legal/reset) are a
/// paginated-reference-sheet artifact, not two real screens (architecture's
/// module layout lists exactly one `settings_screen.dart`).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _resetting = false;

  Future<void> _onReminderToggle(bool value) async {
    if (value) {
      final granted = await ref.read(reminderControllerProvider.notifier).enable();
      if (!mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't turn on reminders — check notification permission in system settings.",
            ),
          ),
        );
      }
    } else {
      await ref.read(reminderControllerProvider.notifier).disable();
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open that link.")),
      );
    }
  }

  Future<void> _onResetProgressTap() async {
    if (_resetting) return;
    final confirmed = await showResetConfirmDialog(context);
    if (!confirmed || _resetting) return;
    _resetting = true;

    // Architecture v3 §7/§11 risk 6: cancel any scheduled reminder, clear
    // every prefs key, invalidate every RAM provider, then wipe the whole
    // nav stack back to splash (which re-runs onboarding) — after which no
    // old screen can reference cleared state.
    try {
      await ref.read(reminderControllerProvider.notifier).disable();
      await ref.read(preferencesServiceProvider).clearAll();
      // §6.2 "Settings-reset bug" fix: `clearAll()` wipes the nine
      // remote-story-config prefs keys, but `StoryCycleStore` hydrated once
      // in its constructor and is session-scoped, so its in-memory copy
      // would otherwise stay stale-but-nonempty after this reset.
      ref.read(storyCycleStoreProvider).reset();
    } catch (_) {
      // Swallow — still proceed to the teardown navigation regardless.
    }

    // `ref`/`context` may already be disposed if this screen was torn down
    // during the awaits above — check before touching either, not after
    // (architecture v1 §8 / v2 §9 convention).
    if (!mounted) return;
    ref.invalidate(playerProfileProvider);
    ref.invalidate(statsProvider);
    ref.invalidate(settingsProvider);
    ref.invalidate(selectedAvatarProvider);

    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.splash, (route) => false);
  }

  /// Sentry's own "Verify Setup" example (docs/SENTRY.md) — throws
  /// intentionally so a developer can confirm an event actually lands in
  /// the dashboard after wiring a real DSN. Debug-only (`kDebugMode`) AND
  /// only rendered when a DSN is actually configured (`kSentryEnabled`) —
  /// this must never ship a "crash the app" button to a real player.
  void _onVerifySentrySetup() {
    throw StateError('This is test exception');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final profileAsync = ref.watch(playerProfileProvider);
    final name = profileAsync.maybeWhen(data: (p) => p.isAnonymous ? 'Anonymous' : p.name, orElse: () => '…');

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenHeader(emoji: '⚙️', title: 'Settings'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  _SettingsRow(
                    emoji: '🔊',
                    label: 'Sound',
                    trailing: SettingsToggle(
                      value: settings.sound,
                      onChanged: (v) => ref.read(settingsProvider.notifier).setSound(v),
                    ),
                  ),
                  _SettingsRow(
                    emoji: '📳',
                    label: 'Haptics',
                    trailing: SettingsToggle(
                      value: settings.haptics,
                      onChanged: (v) => ref.read(settingsProvider.notifier).setHaptics(v),
                    ),
                  ),
                  _SettingsRow(
                    emoji: '✍️',
                    label: 'Name',
                    trailing: Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.coral,
                      ),
                    ),
                    onTap: () => showEditNameDialog(
                      context,
                      initialName: profileAsync.maybeWhen(data: (p) => p.name, orElse: () => ''),
                    ),
                  ),
                  _SettingsRow(
                    emoji: '🔔',
                    label: 'Daily reminder',
                    trailing: SettingsToggle(value: settings.reminder, onChanged: _onReminderToggle),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(color: AppColors.dotInactive, height: 1),
                  ),
                  _SettingsRow(
                    emoji: '📄',
                    label: 'Privacy policy',
                    chevron: true,
                    onTap: () => _openUrl(_kPrivacyUrl),
                  ),
                  _SettingsRow(
                    emoji: '📃',
                    label: 'Terms',
                    chevron: true,
                    onTap: () => _openUrl(_kTermsUrl),
                  ),
                  if (!kIsWeb)
                    _SettingsRow(
                      emoji: '⭐',
                      label: 'Rate the game',
                      chevron: true,
                      onTap: () => _openUrl(_kRateUrl),
                    ),
                  _SettingsRow(
                    emoji: '🗑',
                    label: 'Reset progress',
                    chevron: true,
                    danger: true,
                    onTap: _onResetProgressTap,
                  ),
                  if (kDebugMode && kSentryEnabled) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: AppColors.dotInactive, height: 1),
                    ),
                    _SettingsRow(
                      emoji: '🐞',
                      label: 'Verify Sentry setup',
                      chevron: true,
                      danger: true,
                      onTap: _onVerifySentrySetup,
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Text(
                    'v1.0.0 · stayalive.app',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mute,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plain tappable list row (design v3 §6.1/§9) — standard platform press
/// feedback, deliberately not the sticker-button juice (these are
/// navigational/toggle rows, not primary actions).
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.emoji,
    required this.label,
    this.trailing,
    this.chevron = false,
    this.danger = false,
    this.onTap,
  });

  final String emoji;
  final String label;
  final Widget? trailing;
  final bool chevron;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.red : AppColors.ink;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: danger ? AppColors.red : AppColors.ink, width: 2.5),
        boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(0, 4), blurRadius: 0)],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                ?trailing,
                if (chevron)
                  Icon(Icons.chevron_right, size: 18, color: danger ? AppColors.red : AppColors.mute),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
