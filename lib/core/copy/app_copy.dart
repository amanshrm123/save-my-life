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

/// Pre-checked not-configured (dimmed tile tap, Instagram/Facebook only —
/// `kFbAppId` empty at build time). Deliberately distinct copy from the
/// "isn't installed" strings above: this is the exact bug being fixed —
/// don't reuse "isn't installed" for this case, the app genuinely may be
/// installed.
const String kToastInstagramNotConfigured = "Instagram sharing isn't set up yet";
const String kToastFacebookNotConfigured = "Facebook sharing isn't set up yet";
