# ═══════════════════════════════════════════════════════════════
# Tadabbur — ProGuard/R8 rules (optimized for size + safety)
# ═══════════════════════════════════════════════════════════════

# ─── Flutter core ───
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ─── Google Play Core (deferred components) ───
-dontwarn com.google.android.play.core.**

# ─── Firebase ───
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Crashlytics — preserve stack traces
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keepattributes *Annotation*

# ─── Gson generic signatures (required by flutter_local_notifications) ───
# Without these R8 strips generic type info and Gson's TypeToken<...> fails at
# runtime with: "TypeToken must be created with a type argument". This breaks
# flutter_local_notifications' ability to persist and load scheduled alarms.
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# ─── Google Sign-In / GMS ───
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.**

# ─── just_audio / ExoPlayer ───
-dontwarn com.google.android.exoplayer2.**
-dontwarn androidx.media3.**

# ─── Dio / OkHttp / Okio ───
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# ─── flutter_secure_storage ───
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn androidx.security.crypto.**

# ─── flutter_local_notifications ───
# Model classes are serialized to disk via Gson and must preserve their
# fields + generic signatures so the plugin can restore scheduled
# notifications after the app is killed or the device reboots.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.models.** {
    <fields>;
    <init>(...);
}

# ─── in_app_review (uses Play Core) ───
-dontwarn com.google.android.play.core.review.**

# ─── Kotlin ───
-dontwarn kotlin.**
-dontwarn kotlinx.**

# ─── Enums (used by models) ───
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ─── Native methods ───
-keepclasseswithmembernames class * {
    native <methods>;
}

# ─── Strip debug logging in release ───
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
