import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Kept alive for the app's lifetime — `FlutterMethodChannel.setMethodCallHandler`
  // does not retain the closure's captured objects any longer than the
  // channel itself lives, so a bare local `let` here would risk the plugin
  // being deallocated right after `didInitializeImplicitFlutterEngine`
  // returns. No `pendingGrant`-style teardown is needed on this side (unlike
  // Android's `MainActivity.onDestroy`/`clearPendingGrant`): the iOS plugin
  // holds no state beyond a single in-flight pasteboard write.
  private var socialSharePlugin: SocialSharePlugin?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Native side of `com.timingtap.timing_tap/social_share` (architecture
    // v5 §5/§10) — mirrors Android's `MainActivity.configureFlutterEngine`
    // registration of `SocialSharePlugin.kt` on the same channel name.
    let socialSharePlugin = SocialSharePlugin()
    self.socialSharePlugin = socialSharePlugin
    FlutterMethodChannel(
      name: SocialSharePlugin.channelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler { call, result in
      socialSharePlugin.handle(call, result: result)
    }
  }
}
