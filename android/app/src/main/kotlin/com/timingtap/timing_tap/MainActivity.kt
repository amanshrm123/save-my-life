package com.timingtap.timing_tap

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Registers the restricted-social-share MethodChannel (architecture v5
    // §5/§10) once per engine attach — constant cost, not per-share
    // (architecture §11).
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SocialSharePlugin.CHANNEL)
            .setMethodCallHandler(SocialSharePlugin(this))
    }
}
