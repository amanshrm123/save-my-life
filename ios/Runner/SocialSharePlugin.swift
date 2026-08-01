import Flutter
import UIKit

/// Native side of `com.timingtap.timing_tap/social_share` (architecture v5
/// §5/§10) — the iOS mirror of `SocialSharePlugin.kt`. Same wire contract
/// (channel name, method names, argument keys, error codes) as the Android
/// side, so the Dart-side `SocialShareService`/`ShareTargetSheet` need zero
/// changes to work on either platform.
///
/// iOS has no `Intent`/`resolveActivity` equivalent: the install probe is
/// `canOpenURL` against each app's own custom URL scheme, and the actual
/// share is Meta's documented "Sharing to Stories" mechanism — write the
/// sticker image + background colors to `UIPasteboard`, then deep-link into
/// the app via that same scheme. No listener/callback registered here
/// either, matching the Android side's one-shot-only shape (architecture
/// §11).
final class SocialSharePlugin: NSObject {

    static let channelName = "com.timingtap.timing_tap/social_share"

    // Wire-format target names — must match `ShareTarget.name` verbatim on
    // the Dart side (`lib/features/sharing/domain/share_target.dart`) and
    // the `TARGET_*` constants in Android's `SocialSharePlugin.kt`.
    private static let targetInstagram = "instagramStory"
    private static let targetWhatsApp = "whatsappStatus"
    private static let targetFacebook = "facebookStory"

    // Custom URL schemes, used both as the install probe (`canOpenURL`) and
    // as the actual deep link fired after the pasteboard write.
    private static let schemeInstagram = "instagram-stories://share"
    private static let schemeFacebook = "facebook-stories://share"

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "installedTargets":
            result(installedTargets())
        case "shareToStory":
            shareToStory(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Which of the 3 targets currently resolve on-device.
    ///
    /// WhatsApp is deliberately never included here — this is a product
    /// decision, not an oversight: unlike Instagram/Facebook, WhatsApp has
    /// no documented iOS Status-sharing API (no custom URL scheme, no
    /// pasteboard contract to write into), so there is no real share path to
    /// probe for. Omitting it here is exactly what makes the sheet's
    /// existing dimmed-tile treatment kick in for WhatsApp on iOS with no
    /// Dart-side change.
    private func installedTargets() -> [String] {
        var targets: [String] = []
        if let url = URL(string: Self.schemeInstagram), UIApplication.shared.canOpenURL(url) {
            targets.append(Self.targetInstagram)
        }
        if let url = URL(string: Self.schemeFacebook), UIApplication.shared.canOpenURL(url) {
            targets.append(Self.targetFacebook)
        }
        return targets
    }

    private func shareToStory(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard
            let args = call.arguments as? [String: Any],
            let target = args["target"] as? String,
            let stickerPath = args["stickerPath"] as? String,
            let topColor = args["topColor"] as? String,
            let bottomColor = args["bottomColor"] as? String
        else {
            result(FlutterError(code: "BAD_ARGS", message: "Missing required argument", details: nil))
            return
        }
        let fbAppId = (args["fbAppId"] as? String) ?? ""

        switch target {
        case Self.targetWhatsApp:
            // No real iOS share path — see the comment on installedTargets()
            // above. Same error code Android returns for a genuinely
            // not-installed target, so the Dart-side mapping
            // (`SocialShareOutcome.notInstalled`) needs no iOS-specific
            // branch.
            result(FlutterError(code: "NOT_INSTALLED", message: "WhatsApp Status has no iOS share path", details: nil))
        case Self.targetInstagram:
            shareViaPasteboard(
                scheme: Self.schemeInstagram,
                fbAppId: fbAppId,
                stickerPath: stickerPath,
                topColor: topColor,
                bottomColor: bottomColor,
                stickerImageKey: "com.instagram.sharedSticker.stickerImage",
                topColorKey: "com.instagram.sharedSticker.backgroundTopColor",
                bottomColorKey: "com.instagram.sharedSticker.backgroundBottomColor",
                appIdPasteboardKey: nil,
                result: result
            )
        case Self.targetFacebook:
            // TODO(verify-during-implementation): the `com.facebook.sharedSticker.*`
            // pasteboard key spelling below matches Meta's "Sharing to
            // Facebook Stories" docs to the best of available knowledge at
            // authoring time, but — like the Android side's own
            // "verify-during-implementation" note on the WhatsApp Status
            // extras — hasn't been confirmed against a real device with the
            // Facebook app installed. Re-check against the live Meta
            // developer docs if Facebook Story sharing misbehaves.
            //
            // Unlike Instagram, Facebook's contract takes the app ID via a
            // pasteboard key (`com.facebook.sharedSticker.appID`), not a
            // `source_application` URL query param — the deep link itself is
            // the bare `facebook-stories://share` with no query string
            // (code-reviewer flag: the two were wrongly given the same
            // shape in an earlier pass, which would have silently failed).
            shareViaPasteboard(
                scheme: Self.schemeFacebook,
                fbAppId: fbAppId,
                stickerPath: stickerPath,
                topColor: topColor,
                bottomColor: bottomColor,
                stickerImageKey: "com.facebook.sharedSticker.stickerImage",
                topColorKey: "com.facebook.sharedSticker.backgroundTopColor",
                bottomColorKey: "com.facebook.sharedSticker.backgroundBottomColor",
                appIdPasteboardKey: "com.facebook.sharedSticker.appID",
                result: result
            )
        default:
            result(FlutterError(code: "UNKNOWN_TARGET", message: "Unrecognized target: \(target)", details: nil))
        }
    }

    /// Shared by Instagram/Facebook (architecture §3: the outcome card PNG
    /// is always the STICKER layer over a tier-colored gradient background,
    /// never the background asset itself, for every target on both
    /// platforms) — the pasteboard-based equivalent of the Android side's
    /// `TARGET_INSTAGRAM`/`TARGET_FACEBOOK` Intent-extra branches.
    ///
    /// [appIdPasteboardKey] distinguishes the two targets' genuinely
    /// different app-ID contracts (code-reviewer flag — these are NOT the
    /// same shape): Instagram takes the app ID as a `source_application`
    /// query param on the deep-link URL itself (`appIdPasteboardKey ==
    /// nil`); Facebook instead expects it written into the pasteboard item
    /// under `com.facebook.sharedSticker.appID`, with a bare
    /// `facebook-stories://share` URL and no query string.
    private func shareViaPasteboard(
        scheme: String,
        fbAppId: String,
        stickerPath: String,
        topColor: String,
        bottomColor: String,
        stickerImageKey: String,
        topColorKey: String,
        bottomColorKey: String,
        appIdPasteboardKey: String?,
        result: @escaping FlutterResult
    ) {
        guard let probeUrl = URL(string: scheme), UIApplication.shared.canOpenURL(probeUrl) else {
            // Defence-in-depth only, mirroring the Android side's own
            // comment: `ShareTargetSheet` already pre-checks install state
            // before a tile can reach here — only reachable via a race (the
            // app was removed between the probe and the tap).
            result(FlutterError(code: "NOT_INSTALLED", message: "\(scheme) did not resolve", details: nil))
            return
        }

        // Constructed and validated BEFORE anything touches the pasteboard
        // (code-reviewer fix): a malformed link must fail here with nothing
        // written, not after the card image is already sitting in the
        // general pasteboard for no reason. Instagram's app ID rides the
        // URL itself; Facebook's rides the pasteboard item instead (see the
        // doc comment above), so the bare scheme needs no query string.
        let deepLinkString = appIdPasteboardKey == nil
            ? "\(scheme)?source_application=\(fbAppId)"
            : scheme
        guard let deepLink = URL(string: deepLinkString) else {
            result(FlutterError(code: "BAD_ARGS", message: "Malformed deep link", details: nil))
            return
        }

        // Bounded, short-lived allocation on the main thread: card PNGs are
        // small and Share is a rare, user-initiated action, so this doesn't
        // conflict with the app's RAM-resident design principle enough to
        // warrant dispatching the read off-thread.
        guard let imageData = FileManager.default.contents(atPath: stickerPath) else {
            result(FlutterError(code: "BAD_FILE", message: "Could not read sticker file", details: nil))
            return
        }

        var pasteboardItem: [String: Any] = [
            stickerImageKey: imageData,
            topColorKey: topColor,
            bottomColorKey: bottomColor,
        ]
        if let appIdPasteboardKey {
            pasteboardItem[appIdPasteboardKey] = fbAppId
        }
        // Meta's documented convention for both Instagram and Facebook
        // Stories sharing: a short-lived pasteboard write (5 minutes), not a
        // persistent one — this is share-once, ephemeral data, not
        // something that should linger in the general pasteboard
        // indefinitely. `.localOnly` keeps it off Universal Clipboard/
        // Handoff too, so the card image never syncs to the player's other
        // Apple devices (code-reviewer privacy flag).
        let expiration = Date().addingTimeInterval(5 * 60)
        UIPasteboard.general.setItems(
            [pasteboardItem],
            options: [
                .expirationDate: expiration,
                .localOnly: true,
            ]
        )

        UIApplication.shared.open(deepLink, options: [:]) { success in
            if !success {
                // The share never actually launched (e.g. a race where the
                // app was removed between the probe above and this call) —
                // don't leave the card image sitting in the general
                // pasteboard for the full 5-minute expiration when nothing
                // is going to consume it (code-reviewer privacy flag).
                UIPasteboard.general.items = []
            }
            // Mirrors the Android side's `result.success(true)`/
            // `ACTIVITY_NOT_FOUND` shape closely enough for the Dart-side
            // contract: `SocialShareService` already treats any non-`true`
            // return the same as an activity-not-found failure, so a plain
            // `false` here (rather than a synthesized error code) is enough
            // — there's no iOS equivalent of a thrown
            // `ActivityNotFoundException` to catch.
            result(success)
        }
    }
}
