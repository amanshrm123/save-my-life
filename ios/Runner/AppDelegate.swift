import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // The capture list below (`[socialSharePlugin]`) already keeps this
  // instance alive for as long as the channel's handler closure itself is
  // retained by the engine — this stored property isn't needed for
  // lifetime purposes, it's just the natural, discoverable place to construct
  // the plugin once per `AppDelegate`, mirroring the Android side's
  // `SocialSharePlugin` living as long as `MainActivity`'s engine attach
  // (architecture v5 §5/§10/§11).
  private let socialSharePlugin = SocialSharePlugin()

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Registers the restricted-social-share MethodChannel (architecture v5
    // §5/§10) once per engine attach — constant cost, not per-share
    // (architecture §11), mirroring `MainActivity.configureFlutterEngine`.
    let channel = FlutterMethodChannel(
      name: SocialSharePlugin.channelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [socialSharePlugin] call, result in
      socialSharePlugin.handle(call, result: result)
    }
  }
}
