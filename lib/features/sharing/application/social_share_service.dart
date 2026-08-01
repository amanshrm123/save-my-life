import 'package:flutter/services.dart';

import '../domain/share_composition.dart';
import '../domain/share_target.dart';

/// Distinguishes the three outcomes a direct-intent share attempt can reach
/// (design share-target-sheet-v1 §7/§8): a launched composer is NOT the same
/// as a completed post, so this is deliberately never conflated with the
/// existing "✓ Shared" (`ShareResultStatus.success`) concept — that toast
/// stays exclusively on the "More…" -> real `share_plus` path.
enum SocialShareOutcome {
  /// The native `startActivity` call returned without throwing — the
  /// composer opened. Callers dismiss the sheet with no toast.
  success,

  /// Native `resolveActivity` found nothing for this target at the moment
  /// of the actual call — a race against the sheet's own pre-check (the app
  /// was uninstalled between `installedTargets()` and the tap). Rare;
  /// surfaced with the same "Couldn't open X" copy as [activityNotFound]
  /// rather than the dimmed-tile "isn't installed" copy, which is reserved
  /// for the pre-check path in `ShareTargetSheet` itself.
  notInstalled,

  /// `startActivity` threw `ActivityNotFoundException`.
  activityNotFound,
}

class SocialShareResult {
  const SocialShareResult(this.outcome);

  final SocialShareOutcome outcome;

  bool get isSuccess => outcome == SocialShareOutcome.success;
}

/// Thin wrapper over the native `com.timingtap.timing_tap/social_share`
/// `MethodChannel` (architecture v5 §5/§10) — one `MethodChannel` covering
/// exactly two responsibilities: probing which of the 3 targets are
/// currently resolvable, and firing a single target's direct Story/Status
/// share (an Android `Intent` via `SocialSharePlugin.kt`, or an iOS
/// pasteboard-write + custom-scheme deep link via `SocialSharePlugin.swift`
/// — both ship today; this wrapper's own contract doesn't change per
/// platform). No listener/receiver/callback is ever registered on the Dart
/// side either — both calls are one-shot request/response (§11).
class SocialShareService {
  const SocialShareService();

  static const MethodChannel _channel = MethodChannel(
    'com.timingtap.timing_tap/social_share',
  );

  /// Which of the 3 targets currently resolve on-device. Callers
  /// (`installedTargetsProvider`) re-probe on every sheet open rather than
  /// caching — install state can change between sessions (architecture
  /// §11). Fails soft (empty list, i.e. "all dimmed") rather than throwing,
  /// matching this method's own "probe, don't crash the sheet" purpose.
  Future<List<ShareTarget>> installedTargets() async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('installedTargets');
      if (raw == null) return const <ShareTarget>[];
      return raw
          .whereType<String>()
          .map(shareTargetFromWireName)
          .whereType<ShareTarget>()
          .toList(growable: false);
    } on PlatformException {
      return const <ShareTarget>[];
    } on MissingPluginException {
      return const <ShareTarget>[];
    }
  }

  /// Fires [target]'s direct Story/Status intent with [stickerPath] (a
  /// plain filesystem path — the native side owns turning it into a
  /// `content://` `FileProvider` URI) composited over the [topColor]/
  /// [bottomColor] gradient. [fbAppId] is threaded through even for
  /// WhatsApp (ignored natively there) to keep this call's shape uniform
  /// across all 3 targets.
  Future<SocialShareResult> shareToStory({
    required ShareTarget target,
    required String stickerPath,
    required Color topColor,
    required Color bottomColor,
    String fbAppId = kFbAppId,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('shareToStory', <String, Object?>{
        'target': target.name,
        'stickerPath': stickerPath,
        'topColor': shareColorHex(topColor),
        'bottomColor': shareColorHex(bottomColor),
        'fbAppId': fbAppId,
      });
      return SocialShareResult(
        ok == true ? SocialShareOutcome.success : SocialShareOutcome.activityNotFound,
      );
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'NOT_INSTALLED':
          return const SocialShareResult(SocialShareOutcome.notInstalled);
        default:
          return const SocialShareResult(SocialShareOutcome.activityNotFound);
      }
    } on MissingPluginException {
      return const SocialShareResult(SocialShareOutcome.activityNotFound);
    }
  }
}
