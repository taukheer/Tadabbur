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
-keep class com.dexterous.flutterlocalnotifications.** { *; }

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
