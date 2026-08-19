package com.timingtap.timing_tap

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Registers the restricted-social-share MethodChannel (architecture v5
    // §5/§10) once per engine attach — constant cost, not per-share
    // (architecture §11). Deliberately does NOT eagerly revoke
    // `SocialSharePlugin`'s pending URI grant from `onDestroy` (code-reviewer
    // flag: an earlier pass added that, and it reintroduced exactly the race
    // `SocialSharePlugin`'s own deferred-revoke design exists to avoid — a
    // backgrounded `MainActivity` can be torn down by the system while the
    // receiving composer is still asynchronously reading the granted URI,
    // revoking out from under it. The grant is bounded some other way
    // anyway: revoked before the next share, or effectively gone when the
    // process dies. See `SocialSharePlugin.pendingGrant`'s doc comment.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SocialSharePlugin.CHANNEL)
            .setMethodCallHandler(SocialSharePlugin(this))
    }
}
