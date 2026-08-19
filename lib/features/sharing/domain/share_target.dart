/// The 3 restricted social share destinations (architecture v5 §4/§10) —
/// the founder's ask ("Instagram story, WhatsApp status and Facebook story")
/// closed to a fixed, curated set rather than the generic OS share sheet.
///
/// Order matters: `ShareTarget.values` is iterated to build the sheet's tile
/// row, and must render Instagram -> WhatsApp -> Facebook, fixed regardless
/// of install state (architecture §4/§8) — don't reorder this enum.
enum ShareTarget { instagramStory, whatsappStatus, facebookStory }

/// Per-tile copy (design share-target-sheet-v1 §4) — brand name (line 1) +
/// surface (line 2, "Story"/"Status" — load-bearing: sets the expectation
/// this lands in a Story/Status composer, not a DM).
extension ShareTargetLabels on ShareTarget {
  String get brandName {
    switch (this) {
      case ShareTarget.instagramStory:
        return 'Instagram';
      case ShareTarget.whatsappStatus:
        return 'WhatsApp';
      case ShareTarget.facebookStory:
        return 'Facebook';
    }
  }

  String get surfaceLabel {
    switch (this) {
      case ShareTarget.instagramStory:
        return 'Story';
      case ShareTarget.whatsappStatus:
        return 'Status';
      case ShareTarget.facebookStory:
        return 'Story';
    }
  }
}

/// Facebook App ID (architecture v5 §9) — injected at build time only via
/// `--dart-define=FB_APP_ID=...`, read with `String.fromEnvironment`. Empty
/// by default; NEVER hardcode a real value here or anywhere else. A dev
/// build with no define degrades gracefully (Instagram/Facebook simply read
/// as "not installed") instead of firing a native composer that then shows
/// Meta's own "doesn't currently support sharing to Stories" error dialog.
const String kFbAppId = String.fromEnvironment('FB_APP_ID');

/// Why a tile renders in the sheet's dimmed/"not installed" visual state
/// (design share-target-sheet-v1 §5), replacing a plain bool so the toast
/// copy can tell the two genuinely different causes apart instead of
/// collapsing both into a misleading "isn't installed" (bug fix: an
/// Instagram/Facebook tile dimmed purely because [kFbAppId] is empty at
/// build time used to show "Instagram isn't installed" even when Instagram
/// genuinely IS installed — misleading to whoever's debugging a field
/// report).
enum ShareTileState {
  /// Installed (or needs no App ID check) and ready to share to.
  ready,

  /// Not resolvable on-device — the genuine "isn't installed" case.
  notInstalled,

  /// Installed, but (Instagram/Facebook only) [kFbAppId] is empty at build
  /// time — architecture §9's "empty App ID == not shareable" case, which is
  /// NOT the same thing as the app being missing.
  notConfigured,
}

/// Resolves [target]'s tile state (design share-target-sheet-v1 §5,
/// architecture §9) — either a genuine not-installed target, OR
/// (Instagram/Facebook only) [notConfigured] when [fbAppId] is empty at
/// build time, checked BEFORE the installed-targets lookup so a genuinely
/// installed Instagram/Facebook with no configured App ID reads as
/// [notConfigured], never [notInstalled]. The tile stays fully tappable in
/// every non-[ready] state (§5's load-bearing divergence from
/// `StickerButton.enabled`); this only decides which copy/dimmed-visual the
/// caller uses.
///
/// [fbAppId] defaults to the compile-time [kFbAppId] constant for
/// production call sites (unchanged behavior); it exists as a parameter
/// purely so tests can pass a non-empty value directly to exercise the
/// "App ID IS configured" [ready] Instagram/Facebook path (architecture §9
/// Phase 5b) without needing an actual `--dart-define` at test-run time.
ShareTileState shareTileStateFor(
  ShareTarget target,
  List<ShareTarget> installedTargets, {
  String fbAppId = kFbAppId,
}) {
  final needsAppId = target == ShareTarget.instagramStory || target == ShareTarget.facebookStory;
  if (needsAppId && fbAppId.isEmpty) return ShareTileState.notConfigured;
  return installedTargets.contains(target) ? ShareTileState.ready : ShareTileState.notInstalled;
}

/// True when [target] should render in the sheet's dimmed visual state
/// (design share-target-sheet-v1 §5) — a thin backward-compatible wrapper
/// over [shareTileStateFor] for call sites/tests that only care about the
/// dimmed/not-dimmed visual, not which of the two non-[ShareTileState.ready]
/// reasons caused it.
bool isShareTargetDimmed(
  ShareTarget target,
  List<ShareTarget> installedTargets, {
  String fbAppId = kFbAppId,
}) => shareTileStateFor(target, installedTargets, fbAppId: fbAppId) != ShareTileState.ready;

/// Parses the raw wire-format strings the native `installedTargets()` probe
/// returns (architecture §10 — one `String` per resolvable target,
/// `ShareTarget.name` verbatim) back into [ShareTarget] values. Returns
/// `null` for anything unrecognised rather than throwing — defensive against
/// a future Dart/Kotlin naming drift, not a case expected to occur today.
ShareTarget? shareTargetFromWireName(String name) {
  for (final target in ShareTarget.values) {
    if (target.name == name) return target;
  }
  return null;
}
