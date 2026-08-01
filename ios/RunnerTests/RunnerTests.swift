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

  // MARK: - WhatsApp product-decision coverage (kept from the previous
  // pass — still correct, just lower-signal than the above: the Dart side
  // can never actually tap through to these since a dimmed tile never
  // reaches `shareToStory` for WhatsApp).

  /// WhatsApp Status has no documented iOS share path (product decision,
  /// not an oversight — see `SocialSharePlugin.installedTargets()`'s own
  /// comment). Deterministic regardless of simulator/device install state:
  /// this only asserts the plugin never reports it, not that any particular
  /// app is/isn't actually installed.
  func testInstalledTargetsNeverReportsWhatsApp() {
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

  /// `shareToStory` with the WhatsApp target must unconditionally return the
  /// same `NOT_INSTALLED` error code Android uses for a genuinely-absent
  /// target — there is no install-state branch to exercise here, since the
  /// iOS side never attempts a real WhatsApp share at all.
  func testShareToStoryWhatsAppAlwaysReturnsNotInstalled() {
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

  // MARK: - Instagram/Facebook canOpenURL probe coverage (tester-stage gap:
  // the previous pass never exercised the real `UIApplication.shared
  // .canOpenURL` install probe for these two targets at all — only the
  // WhatsApp branch, which never touches `canOpenURL`). The CI/dev simulator
  // never has Instagram or Facebook installed, so `canOpenURL` for both
  // custom schemes deterministically returns `false` here — this is exactly
  // the "not installed" case the QA pass flagged (dimmed, not crash/hang):
  // `shareToStory` must fail closed with `NOT_INSTALLED` (mirroring the
  // Android side's own real `resolveActivity`-returns-null case, exercised
  // there via a genuinely-absent package), and `installedTargets()` must
  // correctly omit both rather than including them or throwing.

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

}
