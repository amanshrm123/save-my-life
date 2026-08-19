import Flutter
import UIKit
import XCTest

@testable import Runner

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

  // MARK: - Wire-contract coverage (code-reviewer flag: the previous pass
  // only tested the WhatsApp-always-unavailable branch, which the Dart side
  // can never even reach — dimmed tiles aren't tappable. These cover the
  // actual risk: the channel name and error-code contract
  // `SocialShareService`/`ShareTargetSheet` depend on.

  /// `SocialShareService` on the Dart side hard-codes this exact string —
  /// any drift here silently breaks every call on iOS with no compile-time
  /// signal on either side.
  func testChannelNameMatchesWireContract() {
    XCTAssertEqual(SocialSharePlugin.channelName, "com.timingtap.timing_tap/social_share")
  }

  func testShareToStoryMissingStickerPathReturnsBadArgs() {
    let plugin = SocialSharePlugin()
    let expectation = expectation(description: "shareToStory result")
    var reportedError: FlutterError?
    plugin.handle(
      FlutterMethodCall(
        methodName: "shareToStory",
        arguments: [
          "target": "instagramStory",
          "topColor": "#ff0000",
          "bottomColor": "#000000",
          "fbAppId": "",
        ]
      )
    ) { result in
      reportedError = result as? FlutterError
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1)
    XCTAssertEqual(reportedError?.code, "BAD_ARGS")
  }

  func testShareToStoryMissingTopColorReturnsBadArgs() {
    let plugin = SocialSharePlugin()
    let expectation = expectation(description: "shareToStory result")
    var reportedError: FlutterError?
    plugin.handle(
      FlutterMethodCall(
        methodName: "shareToStory",
        arguments: [
          "target": "instagramStory",
          "stickerPath": "/tmp/does-not-matter.png",
          "bottomColor": "#000000",
          "fbAppId": "",
        ]
      )
    ) { result in
      reportedError = result as? FlutterError
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1)
    XCTAssertEqual(reportedError?.code, "BAD_ARGS")
  }

  /// A future Dart/Kotlin/Swift naming drift on `ShareTarget.name` must
  /// surface as this specific error code, not an unhandled crash or a
  /// silently-ignored no-op.
  func testShareToStoryUnknownTargetReturnsUnknownTarget() {
    let plugin = SocialSharePlugin()
    let expectation = expectation(description: "shareToStory result")
    var reportedError: FlutterError?
    plugin.handle(
      FlutterMethodCall(
        methodName: "shareToStory",
        arguments: [
          "target": "twitterStory",
          "stickerPath": "/tmp/does-not-matter.png",
          "topColor": "#ff0000",
          "bottomColor": "#000000",
          "fbAppId": "",
        ]
      )
    ) { result in
      reportedError = result as? FlutterError
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1)
    XCTAssertEqual(reportedError?.code, "UNKNOWN_TARGET")
  }

  /// Any method name other than the two this plugin actually implements
  /// must fall through to Flutter's own sentinel, matching every other
  /// MethodChannel handler in this app (and Android's `SocialSharePlugin.kt`
  /// equivalent).
  func testUnknownMethodReturnsNotImplemented() {
    let plugin = SocialSharePlugin()
    let expectation = expectation(description: "unknown method result")
    var reported: Any?
    plugin.handle(FlutterMethodCall(methodName: "notARealMethod", arguments: nil)) { result in
      reported = result
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1)
    XCTAssertTrue((reported as AnyObject) === FlutterMethodNotImplemented)
  }

  // MARK: - WhatsApp iOS coverage (reversing an earlier, incorrect
  // assumption that WhatsApp had no iOS share path — see
  // `SocialSharePlugin.swift`'s `installedTargets()`/`shareToWhatsAppStatus`
  // for the real implementation, ground truth
  // `fbsamples/whatsapp_status_api_ios`). Same real (non-mocked)
  // `canOpenURL` probe shape as the Instagram/Facebook coverage below: the
  // CI/dev simulator never has WhatsApp installed, so
  // `canOpenURL("whatsapp://")` deterministically returns `false` here.

  /// Real (non-mocked) `canOpenURL` probe: on a simulator without WhatsApp
  /// installed, the bare `whatsapp://` scheme fails to resolve, so the
  /// wire-format list must NOT contain `whatsappStatus` — the dimmed-tile
  /// path the Dart side relies on.
  func testInstalledTargetsExcludesWhatsAppWhenNotInstalled() {
    let plugin = SocialSharePlugin()
    let expectation = expectation(description: "installedTargets result")
    var reported: [String]?
    plugin.handle(FlutterMethodCall(methodName: "installedTargets", arguments: nil)) { result in
      reported = result as? [String]
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1)
    XCTAssertFalse(reported?.contains("whatsappStatus") ?? true)
  }

  /// Same real probe, exercised through the actual `shareToStory` call this
  /// time (not just the `installedTargets` list): with valid args but no
  /// WhatsApp on-device, the `canOpenURL` guard in `shareToWhatsAppStatus`
  /// must fail closed with `NOT_INSTALLED` BEFORE anything touches
  /// `UIPasteboard` (mirroring the Android side's own real
  /// `resolveActivity`/package-installed-returns-false case).
  ///
  /// Scope note (code-reviewer flag): this only proves the early
  /// `canOpenURL` guard fires — it cannot reach the actual payload-building
  /// logic below that guard on a simulator (WhatsApp is never installed
  /// there), so it would pass identically against the old hardcoded-
  /// `NOT_INSTALLED` implementation this branch replaced. Real coverage for
  /// the part that changed (the WhatsApp pasteboard payload's color
  /// components) lives in the `rgbaComponents(fromHex:)` tests below, since
  /// that pure helper doesn't need `canOpenURL` to succeed to exercise.
  func testShareToStoryWhatsAppNotInstalledReturnsNotInstalled() {
    let plugin = SocialSharePlugin()
    let expectation = expectation(description: "shareToStory result")
    var reportedError: FlutterError?
    plugin.handle(
      FlutterMethodCall(
        methodName: "shareToStory",
        arguments: [
          "target": "whatsappStatus",
          "stickerPath": "/tmp/does-not-matter.png",
          "topColor": "#ff0000",
          "bottomColor": "#000000",
          "fbAppId": "",
        ]
      )
    ) { result in
      reportedError = result as? FlutterError
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1)
    XCTAssertEqual(reportedError?.code, "NOT_INSTALLED")
  }

  // MARK: - Instagram/Facebook canOpenURL probe coverage. The CI/dev
  // simulator never has Instagram or Facebook installed, so `canOpenURL` for
  // both custom schemes deterministically returns `false` here — this is
  // exactly the "not installed" case the QA pass flagged (dimmed, not
  // crash/hang): `shareToStory` must fail closed with `NOT_INSTALLED`
  // (mirroring the Android side's own real `resolveActivity`-returns-null
  // case, exercised there via a genuinely-absent package), and
  // `installedTargets()` must correctly omit both rather than including them
  // or throwing.

  /// Real (non-mocked) `canOpenURL` probe: on a simulator with neither app
  /// installed, both custom schemes fail to resolve, so the wire-format list
  /// must contain neither `instagramStory` nor `facebookStory` — the
  /// dimmed-tile path the Dart side relies on to keep the sheet from
  /// crashing/hanging on a device with the App ID configured but the actual
  /// composer app missing.
  func testInstalledTargetsExcludesInstagramAndFacebookWhenNotInstalled() {
    let plugin = SocialSharePlugin()
    let expectation = expectation(description: "installedTargets result")
    var reported: [String]?
    plugin.handle(FlutterMethodCall(methodName: "installedTargets", arguments: nil)) { result in
      reported = result as? [String]
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1)
    XCTAssertFalse(reported?.contains("instagramStory") ?? true)
    XCTAssertFalse(reported?.contains("facebookStory") ?? true)
  }

  /// Same real probe, exercised through the actual `shareToStory` call this
  /// time (not just the `installedTargets` list): with valid args but no
  /// Instagram on-device, the `canOpenURL` guard in `shareViaPasteboard`
  /// must fail closed BEFORE anything touches `UIPasteboard` — asserting
  /// `NOT_INSTALLED` here is what proves that guard actually fires on a real
  /// probe result, not just on the mocked/unreachable defence-in-depth path
  /// the doc comment describes.
  func testShareToStoryInstagramNotInstalledReturnsNotInstalled() {
    let plugin = SocialSharePlugin()
    let expectation = expectation(description: "shareToStory result")
    var reportedError: FlutterError?
    plugin.handle(
      FlutterMethodCall(
        methodName: "shareToStory",
        arguments: [
          "target": "instagramStory",
          "stickerPath": "/tmp/does-not-matter.png",
          "topColor": "#ff0000",
          "bottomColor": "#000000",
          "fbAppId": "1234567890",
        ]
      )
    ) { result in
      reportedError = result as? FlutterError
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1)
    XCTAssertEqual(reportedError?.code, "NOT_INSTALLED")
  }

  /// Facebook's equivalent of the above — same real `canOpenURL` guard, same
  /// fail-closed contract, exercised with a non-empty `fbAppId` to confirm
  /// the guard fires before the appID-pasteboard-key branch is ever reached.
  func testShareToStoryFacebookNotInstalledReturnsNotInstalled() {
    let plugin = SocialSharePlugin()
    let expectation = expectation(description: "shareToStory result")
    var reportedError: FlutterError?
    plugin.handle(
      FlutterMethodCall(
        methodName: "shareToStory",
        arguments: [
          "target": "facebookStory",
          "stickerPath": "/tmp/does-not-matter.png",
          "topColor": "#ff0000",
          "bottomColor": "#000000",
          "fbAppId": "1234567890",
        ]
      )
    ) { result in
      reportedError = result as? FlutterError
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1)
    XCTAssertEqual(reportedError?.code, "NOT_INSTALLED")
  }

  // MARK: - rgbaComponents(fromHex:) coverage (code-reviewer flag: this is
  // the one helper in `SocialSharePlugin.swift` where a silent off-by-one or
  // format bug would corrupt a shared card's background color on a real
  // device with no crash to catch it — none of the canOpenURL-gated tests
  // above can reach it on a simulator, so it needs direct coverage as a pure
  // function).

  func testRgbaComponentsParsesValidHexWithHashPrefix() {
    let plugin = SocialSharePlugin()
    let components = plugin.rgbaComponents(fromHex: "#FF8800")
    XCTAssertEqual(components?.count, 4)
    XCTAssertEqual(components?[0] ?? -1, 1.0, accuracy: 0.001)
    XCTAssertEqual(components?[1] ?? -1, 136.0 / 255.0, accuracy: 0.001)
    XCTAssertEqual(components?[2] ?? -1, 0.0, accuracy: 0.001)
    XCTAssertEqual(components?[3] ?? -1, 1.0, accuracy: 0.001)
  }

  func testRgbaComponentsAcceptsHexWithoutHashPrefix() {
    let plugin = SocialSharePlugin()
    XCTAssertEqual(plugin.rgbaComponents(fromHex: "000000"), [0, 0, 0, 1.0])
  }

  func testRgbaComponentsRejectsMalformedHex() {
    let plugin = SocialSharePlugin()
    XCTAssertNil(plugin.rgbaComponents(fromHex: "#FFF"))
    XCTAssertNil(plugin.rgbaComponents(fromHex: "not-a-color"))
    XCTAssertNil(plugin.rgbaComponents(fromHex: ""))
    XCTAssertNil(plugin.rgbaComponents(fromHex: "#GGGGGG"))
  }

}
