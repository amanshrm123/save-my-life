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

    // WhatsApp's shape is deliberately different from Instagram/Facebook's
    // above (ground truth: `fbsamples/whatsapp_status_api_ios`'s
    // `ContentViewModel.swift`): the install probe is the bare `whatsapp://`
    // scheme, NOT a `-stories://share`-style scheme, and the actual launch
    // afterwards is a `https://` universal link, not a custom-scheme deep
    // link — [whatsappProbeScheme] and [whatsappLaunchURLString] are
    // deliberately different strings; don't conflate them.
    private static let whatsappProbeScheme = "whatsapp://"
    private static let whatsappLaunchURLString = "https://wa.me/media-share-external"
    private static let whatsappPasteboardKey = "com.whatsapp.media-share-external.data"

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
    /// WhatsApp IS included here — reversing an earlier, incorrect
    /// assumption that it had no iOS share path. It has a real one (see
    /// [shareToWhatsAppStatus]); its install probe is just a different shape
    /// from Instagram/Facebook's: the bare `whatsapp://` scheme rather than
    /// a `<brand>-stories://share`-style scheme.
    private func installedTargets() -> [String] {
        var targets: [String] = []
        if let url = URL(string: Self.schemeInstagram), UIApplication.shared.canOpenURL(url) {
            targets.append(Self.targetInstagram)
        }
        if let url = URL(string: Self.whatsappProbeScheme), UIApplication.shared.canOpenURL(url) {
            targets.append(Self.targetWhatsApp)
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
            shareToWhatsAppStatus(
                stickerPath: stickerPath,
                topColor: topColor,
                bottomColor: bottomColor,
                result: result
            )
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
            // The `com.facebook.sharedSticker.*` pasteboard key spelling
            // below is confirmed against Meta's official "Sharing to Stories
            // — iOS developers" documentation
            // (developers.facebook.com/docs/sharing/sharing-to-stories/ios-developers/),
            // not just inferred from the Android extras' naming.
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

    /// WhatsApp's iOS "Sharing to Status" mechanism (ground truth:
    /// `fbsamples/whatsapp_status_api_ios`'s `ContentViewModel.swift`) — a
    /// deliberately different pasteboard/launch shape from
    /// [shareViaPasteboard]'s Instagram/Facebook contract above: ONE
    /// pasteboard item under [whatsappPasteboardKey], whose value is a
    /// single `[String: Any]` dictionary (not one pasteboard entry per key),
    /// and a `https://` universal-link launch
    /// ([whatsappLaunchURLString]) rather than a custom-scheme deep link —
    /// note this is NOT the same URL as [whatsappProbeScheme], used only for
    /// the `canOpenURL` install probe.
    private func shareToWhatsAppStatus(
        stickerPath: String,
        topColor: String,
        bottomColor: String,
        result: @escaping FlutterResult
    ) {
        guard
            let probeUrl = URL(string: Self.whatsappProbeScheme),
            UIApplication.shared.canOpenURL(probeUrl)
        else {
            // Defence-in-depth only, mirroring shareViaPasteboard()'s own
            // comment — only reachable via a race (the app was removed
            // between the probe and the tap).
            result(FlutterError(code: "NOT_INSTALLED", message: "\(Self.whatsappProbeScheme) did not resolve", details: nil))
            return
        }

        guard let launchUrl = URL(string: Self.whatsappLaunchURLString) else {
            result(FlutterError(code: "BAD_ARGS", message: "Malformed deep link", details: nil))
            return
        }

        guard let imageData = FileManager.default.contents(atPath: stickerPath) else {
            result(FlutterError(code: "BAD_FILE", message: "Could not read sticker file", details: nil))
            return
        }

        guard
            let topComponents = rgbaComponents(fromHex: topColor),
            let bottomComponents = rgbaComponents(fromHex: bottomColor)
        else {
            result(FlutterError(code: "BAD_ARGS", message: "Malformed color", details: nil))
            return
        }

        let payload: [String: Any] = [
            "bundle_id": Bundle.main.bundleIdentifier ?? "",
            "foreground_media": imageData,
            "foreground_media_type": "png",
            // WhatsApp's contract wants one flat RGBA fallback color
            // alongside the 2-stop gradient below; the top gradient stop is
            // the natural choice since it's this app's "primary" tier color.
            "background_color": topComponents,
            "background_gradient": [topComponents, bottomComponents],
        ]

        // WhatsApp's own sample uses a 2-minute pasteboard expiration —
        // deliberately different from Instagram/Facebook's 5 minutes above,
        // not unified. `.localOnly` for the same privacy reasoning as
        // [shareViaPasteboard]: never syncs to Universal Clipboard/Handoff.
        let expiration = Date().addingTimeInterval(120)
        UIPasteboard.general.setItems(
            [[Self.whatsappPasteboardKey: payload]],
            options: [
                .expirationDate: expiration,
                .localOnly: true,
            ]
        )

        // `.universalLinksOnly: true` (code-reviewer flag): without it, a
        // device where WhatsApp hasn't (or can no longer) claim the
        // `wa.me` universal link falls back to opening the URL in Safari
        // instead — and the completion handler still reports `success ==
        // true`, since *opening a URL* succeeded even though the intended
        // app never launched. That would make this method report success
        // back to the Dart layer (sheet dismisses silently) while the
        // player actually lands in a browser with the card sitting unread
        // in the pasteboard. Failing closed here converts that into the
        // same `NOT_INSTALLED`-equivalent `false` the [shareViaPasteboard]
        // Instagram/Facebook path already reports for its own "app didn't
        // actually open" case.
        UIApplication.shared.open(launchUrl, options: [.universalLinksOnly: true]) { success in
            if !success {
                // The share never actually launched — don't leave the card
                // image sitting in the general pasteboard for the full
                // 2-minute expiration when nothing is going to consume it
                // (same privacy reasoning as shareViaPasteboard()).
                UIPasteboard.general.items = []
            }
            result(success)
        }
    }

    /// Parses a `#RRGGBB` hex string (this channel's one canonical
    /// wire-format color — see `share_composition.dart`'s `shareColorHex`)
    /// into an RGBA `[CGFloat]` component array, alpha hardcoded to `1.0` —
    /// the shape WhatsApp's iOS Status pasteboard contract expects for both
    /// `background_color` and each entry of `background_gradient`. Internal
    /// (not `private`), not `fileprivate`/exposed further than needed: kept
    /// directly unit-testable from `RunnerTests` via `@testable import
    /// Runner` — this is the one helper in this file where a silent
    /// off-by-one/format bug would corrupt a shared card's background color
    /// on a real device with no crash to catch it (code-reviewer flag).
    func rgbaComponents(fromHex hex: String) -> [CGFloat]? {
        var sanitized = hex
        if sanitized.hasPrefix("#") {
            sanitized.removeFirst()
        }
        guard sanitized.count == 6, let value = UInt32(sanitized, radix: 16) else {
            return nil
        }
        let r = CGFloat((value & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((value & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(value & 0x0000FF) / 255.0
        return [r, g, b, 1.0]
    }
}
