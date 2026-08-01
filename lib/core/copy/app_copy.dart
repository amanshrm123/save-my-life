/// Shared marketing copy strings reused across more than one screen — kept
/// centralised so a single edit updates every call site instead of hunting
/// down duplicated string literals (design `home-avatars-v1.md` §1).
library;

/// The app's tagline, shown under the wordmark on both `SplashScreen` and
/// `HomeScreen`.
const String kAppTagline = 'One tap. From dust to forever.';

// --- ShareTargetSheet toast copy (design share-target-sheet-v1 §8.2) ---
// Reuses the existing `ToastPill` visual, plain text only (no leading glyph,
// this isn't the "✓ Shared" success case). Rendered inside the still-open
// sheet, not on the outcome screen underneath (§8.2/§7 — the sheet stays
// open for both cases so the player can try another tile).

/// `ActivityNotFoundException` on the direct-intent path.
const String kToastCouldNotOpenInstagram = "Couldn't open Instagram";
const String kToastCouldNotOpenWhatsApp = "Couldn't open WhatsApp";
const String kToastCouldNotOpenFacebook = "Couldn't open Facebook";

/// Pre-checked not-installed (dimmed tile tap).
const String kToastInstagramNotInstalled = "Instagram isn't installed";
const String kToastWhatsAppNotInstalled = "WhatsApp isn't installed";
const String kToastFacebookNotInstalled = "Facebook isn't installed";

/// iOS-specific WhatsApp copy (app-store-specialist flag): WhatsApp Status
/// has no documented iOS share path at all — the tile is always dimmed
/// there regardless of whether WhatsApp itself is installed on the device,
/// so "isn't installed" is factually wrong (WhatsApp may well be installed;
/// it's the Status-sharing capability that doesn't exist on this platform).
const String kToastWhatsAppNotSupportedOnIOS =
    "WhatsApp Status isn't supported on iPhone";
