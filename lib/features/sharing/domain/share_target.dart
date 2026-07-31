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

/// True when [target] should render in the sheet's dimmed/"not installed"
/// visual state (design share-target-sheet-v1 §5): either a genuine
/// not-installed target, OR (Instagram/Facebook only) when [kFbAppId] is
/// empty at build time — architecture §9 treats an empty App ID identically
/// to "not installed" from a UI perspective. The tile stays fully tappable
/// either way (§5's load-bearing divergence from `StickerButton.enabled`);
/// this only decides which value the caller passes as `dimmed:`.
///
/// [fbAppId] defaults to the compile-time [kFbAppId] constant for
/// production call sites (unchanged behavior); it exists as a parameter
/// purely so tests can pass a non-empty value directly to exercise the
/// "App ID IS configured" un-dimmed Instagram/Facebook path (architecture
/// §9 Phase 5b) without needing an actual `--dart-define` at test-run time.
bool isShareTargetDimmed(
  ShareTarget target,
  List<ShareTarget> installedTargets, {
  String fbAppId = kFbAppId,
}) {
  final needsAppId = target == ShareTarget.instagramStory || target == ShareTarget.facebookStory;
  if (needsAppId && fbAppId.isEmpty) return true;
  return !installedTargets.contains(target);
}

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
