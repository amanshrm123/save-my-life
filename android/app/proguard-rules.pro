# flutter_local_notifications (architecture v3 §8) persists scheduled-reminder
# state as Gson-serialized JSON in SharedPreferences (see
# FlutterLocalNotificationsPlugin.buildGson()/NotificationDetails) -- without
# these, R8 strips the field names/generic type info Gson's reflection needs,
# and the daily reminder silently stops surviving a relaunch. Verified against
# the plugin's own source (not just its example proguard file, whose "not
# required for v19+" claim doesn't hold -- Gson is still very much in active
# use at v22.1.0).
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }

# AppLovin MAX (real-ad-serving pass) bundles the IAB Open Measurement SDK,
# which has an OPTIONAL reflective integration with Amazon's Privacy Pass
# attestation library -- a dependency this app never actually adds, since
# nothing here uses it. R8 fails the release build outright (not just a
# warning) without these, per the exact rules R8 itself generates into
# build/app/outputs/mapping/release/missing_rules.txt. Confirmed safe to
# suppress rather than keep: these classes are genuinely never invoked
# unless the (absent) Amazon library is present, matching AppLovin's own
# published R8/ProGuard guidance for this exact warning.
-dontwarn com.amazon.privacypass.PrivacyPass
-dontwarn com.amazon.privacypass.VerificationContext
-dontwarn com.amazon.privacypass.callback.AttestAPICallback
