package com.timingtap.timing_tap

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Native side of `com.timingtap.timing_tap/social_share` (architecture v5
 * §5/§10): a `MethodChannel` handler covering exactly two responsibilities —
 * probing which of the 3 restricted share targets (Instagram Story, WhatsApp
 * Status, Facebook Story) currently resolve on-device, and firing a single
 * target's direct Story/Status intent.
 *
 * Deliberately tiny (architecture §5 point 5: "roughly 120 lines of
 * Kotlin"), and deliberately retains nothing beyond a single method call:
 * no listener, no `BroadcastReceiver`, no callback registration — one-shot
 * `startActivity` only (architecture §11).
 *
 * [context] is `MainActivity` itself (see `MainActivity.configureFlutterEngine`),
 * not `applicationContext` — a latent Activity-retention risk in general,
 * but bounded today: `FlutterActivity` owns this plugin instance's entire
 * lifetime 1:1 (a fresh `SocialSharePlugin` per `configureFlutterEngine`
 * call, never cached/reused across engine attaches), so this instance never
 * outlives the Activity it holds. Revisit if this plugin is ever registered
 * against a long-lived cached `FlutterEngine` instead.
 */
class SocialSharePlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.timingtap.timing_tap/social_share"

        private const val PKG_INSTAGRAM = "com.instagram.android"
        private const val PKG_WHATSAPP = "com.whatsapp"
        private const val PKG_FACEBOOK = "com.facebook.katana"

        // Wire-format target names — must match `ShareTarget.name` verbatim
        // on the Dart side (`lib/features/sharing/domain/share_target.dart`).
        private const val TARGET_INSTAGRAM = "instagramStory"
        private const val TARGET_WHATSAPP = "whatsappStatus"
        private const val TARGET_FACEBOOK = "facebookStory"

        private val ALL_TARGETS = listOf(TARGET_INSTAGRAM, TARGET_WHATSAPP, TARGET_FACEBOOK)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "installedTargets" -> result.success(installedTargets())
            "shareToStory" -> shareToStory(call, result)
            else -> result.notImplemented()
        }
    }

    /**
     * The bare action/type/package shape of each target's intent, with no
     * data/extras yet — shared between the install probe (which only needs
     * this much to call `resolveActivity`) and [shareToStory] (which adds
     * the sticker/color extras on top of the same base before firing it).
     */
    private fun baseIntent(target: String): Intent? = when (target) {
        TARGET_INSTAGRAM -> Intent("com.instagram.share.ADD_TO_STORY").apply {
            type = "image/*"
            setPackage(PKG_INSTAGRAM)
        }
        TARGET_FACEBOOK -> Intent("com.facebook.stories.ADD_TO_STORY").apply {
            type = "image/*"
            setPackage(PKG_FACEBOOK)
        }
        TARGET_WHATSAPP -> Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/status")).apply {
            setPackage(PKG_WHATSAPP)
        }
        else -> null
    }

    private fun packageFor(target: String): String? = when (target) {
        TARGET_INSTAGRAM -> PKG_INSTAGRAM
        TARGET_WHATSAPP -> PKG_WHATSAPP
        TARGET_FACEBOOK -> PKG_FACEBOOK
        else -> null
    }

    /**
     * Plain package-installed check — deliberately NOT `resolveActivity`
     * (see the WhatsApp branch of [installedTargets] for why): a simple
     * `getPackageInfo` lookup, unaffected by Android 12+ per-app web-link
     * domain approval.
     */
    private fun isPackageInstalled(pkg: String): Boolean =
        runCatching { context.packageManager.getPackageInfo(pkg, 0) }.isSuccess

    /**
     * `resolveActivity` returns null both when the target app is genuinely
     * absent from the device AND when its package is missing from this
     * manifest's `<queries>` block (architecture §12 code-reviewer flag 8)
     * — a `<queries>` regression is indistinguishable from "not installed"
     * at this layer. Nothing to disambiguate at runtime; kept in sync by
     * hand against `AndroidManifest.xml`'s 3 `<package>` entries.
     */
    private fun installedTargets(): List<String> {
        return ALL_TARGETS.filter { target ->
            if (target == TARGET_WHATSAPP) {
                // NOT `resolveActivity` against `baseIntent`'s
                // `https://wa.me/status` web intent: since Android 12, web
                // intents are subject to per-app domain approval and can
                // resolve to nothing even when WhatsApp is installed (the
                // user can disable "Open supported links" for WhatsApp in
                // system settings) — Meta's own official sample
                // (`fbsamples/whatsapp_status_api_android`) never calls
                // `resolveActivity` for this at all. A plain
                // package-installed check is the only reliable probe here.
                return@filter isPackageInstalled(PKG_WHATSAPP)
            }
            val intent = baseIntent(target) ?: return@filter false
            // Plain `0`, NOT `MATCH_DEFAULT_ONLY` (architecture §2.1, Meta's
            // own sample code): `MATCH_DEFAULT_ONLY` additionally requires
            // the resolved activity to declare `CATEGORY_DEFAULT`, which
            // these vendor-custom actions
            // (`com.instagram.share.ADD_TO_STORY` etc.) are not guaranteed
            // to declare. Using that flag risks a permanently-dimmed tile
            // even when the app IS installed.
            context.packageManager.resolveActivity(intent, 0) != null
        }
    }

    private fun shareToStory(call: MethodCall, result: MethodChannel.Result) {
        val target = call.argument<String>("target")
        val stickerPath = call.argument<String>("stickerPath")
        val topColor = call.argument<String>("topColor")
        val bottomColor = call.argument<String>("bottomColor")
        val fbAppId = call.argument<String>("fbAppId") ?: ""

        if (target == null || stickerPath == null || topColor == null || bottomColor == null) {
            result.error("BAD_ARGS", "Missing required argument", null)
            return
        }

        val packageName = packageFor(target)
        val intent = baseIntent(target)
        if (packageName == null || intent == null) {
            result.error("UNKNOWN_TARGET", "Unrecognized target: $target", null)
            return
        }

        // Same split as installedTargets(): WhatsApp's presence is checked
        // via plain package-installed (never `resolveActivity` against the
        // `https://wa.me/status` web intent — see that function's comment),
        // Instagram/Facebook keep the plain `0` `resolveActivity` check.
        val stillInstalled = if (target == TARGET_WHATSAPP) {
            isPackageInstalled(packageName)
        } else {
            context.packageManager.resolveActivity(intent, 0) != null
        }
        if (!stillInstalled) {
            // Defence-in-depth only — `ShareTargetSheet` already pre-checks
            // install state before letting a tile reach here at all. Only
            // reachable via a race (app uninstalled between the probe and
            // the tap), so mapped by the Dart side to the same
            // "Couldn't open X" copy as a thrown ActivityNotFoundException,
            // not the dimmed-tile "isn't installed" copy.
            result.error("NOT_INSTALLED", "$packageName did not resolve", null)
            return
        }

        val uri: Uri
        try {
            uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.shareprovider",
                File(stickerPath),
            )
        } catch (e: Exception) {
            result.error("BAD_FILE", "Could not resolve sticker file URI", null)
            return
        }

        // Composition: the outcome card PNG is passed as the STICKER layer
        // over a tier-colored background gradient, never as the background
        // asset itself (architecture §3) — same shape across all 3 targets.
        // Sticker-only sharing (no background asset) uses `type = "image/*"`
        // rather than `setDataAndType(uri, ...)` for Instagram/Facebook —
        // confirmed correct against `react-native-share`'s
        // `InstagramStoriesShare.java`/`FacebookStoriesShare.java`, which use
        // exactly this in production.
        when (target) {
            TARGET_INSTAGRAM -> {
                intent.putExtra("interactive_asset_uri", uri)
                intent.putExtra("top_background_color", topColor)
                intent.putExtra("bottom_background_color", bottomColor)
                intent.putExtra("source_application", fbAppId)
            }
            TARGET_FACEBOOK -> {
                intent.putExtra("interactive_asset_uri", uri)
                intent.putExtra("top_background_color", topColor)
                intent.putExtra("bottom_background_color", bottomColor)
                intent.putExtra("com.facebook.platform.extra.APPLICATION_ID", fbAppId)
            }
            TARGET_WHATSAPP -> {
                // Sticker-only, no background asset — matches Instagram/
                // Facebook's shape (architecture §3: the card PNG is ALWAYS
                // the sticker/foreground layer, never the background asset,
                // for all 3 targets). `EXTRA_STREAM` (background media) is
                // deliberately NOT set here — that would be the "both
                // background AND sticker" double-asset bug this branch
                // avoids.
                //
                // WhatsApp DOES support a gradient-fill background, matching
                // Instagram/Facebook's treatment above — sourced from
                // `fbsamples/whatsapp_status_api_android`'s `MainActivity.kt`.
                // Its extras just use a different color format: `#AARRGGBB`
                // (8 hex digits, alpha first) rather than Instagram/
                // Facebook's 6-digit `#RRGGBB`, hence [toArgbHex] below —
                // done here, not on the Dart side, so `#RRGGBB` stays the one
                // canonical wire format across the whole channel.
                intent.putExtra("share_type", "SHARE_TO_STATUS")
                intent.putExtra("source_app_package_name", context.packageName)
                intent.putExtra("source_app_name", "Stay Alive")
                intent.putExtra("foreground_media", uri)
                intent.putExtra("color_gradient_top", toArgbHex(topColor))
                intent.putExtra("color_gradient_bottom", toArgbHex(bottomColor))
            }
        }

        // Both mechanisms, deliberately (architecture §12 code-reviewer
        // flag 5) — the intent flag alone is not honoured by every
        // receiving composer, so an explicit grantUriPermission is issued
        // as well, before startActivity.
        //
        // Unlike the intent-flag grant (scoped to the receiving task's
        // lifetime), this explicit grant persists until revoked or a system
        // restart — and `CardRenderer` always writes to the same fixed
        // path, so a stale grant would keep giving a previously-used app
        // read access to every LATER card written to that path too. At most
        // one such grant is ever kept outstanding: revoke the previous one
        // (if any) right before issuing a new one, rather than revoking
        // immediately after this call (which would race a composer that
        // reads the URI asynchronously after `startActivity` returns).
        pendingGrant?.let { (pkg, grantedUri) ->
            context.revokeUriPermission(pkg, grantedUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        context.grantUriPermission(packageName, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        pendingGrant = packageName to uri

        try {
            context.startActivity(intent)
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.error("ACTIVITY_NOT_FOUND", e.message, null)
        }
    }

    /**
     * Widens a `#RRGGBB` string (the one canonical wire-format color this
     * channel uses — see `share_composition.dart`'s `shareColorHex`) to
     * WhatsApp's `#AARRGGBB` gradient-extra format by prefixing a
     * fully-opaque alpha. Instagram/Facebook's `top_background_color`/
     * `bottom_background_color` extras stay plain 6-digit `#RRGGBB`; only
     * WhatsApp's `color_gradient_top`/`color_gradient_bottom` extras need
     * this 8-digit alpha-first form (`fbsamples/whatsapp_status_api_android`).
     * Widening happens here, not on the Dart side, so the wire format itself
     * stays platform-neutral.
     */
    private fun toArgbHex(rrggbb: String): String = "#FF${rrggbb.removePrefix("#")}"

    /**
     * The most recent (packageName, uri) pair granted via [shareToStory],
     * revoked right before the next grant is issued (see the comment at the
     * call site) — at most one outstanding grant across this plugin's
     * lifetime, one per `MainActivity`/engine lifetime (architecture §11
     * "one-shot, no lingering access" precedent).
     */
    private var pendingGrant: Pair<String, Uri>? = null
}
