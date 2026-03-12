# ──────────────────────────────────────────────────
# ProGuard / R8 rules — ASTRO
# ──────────────────────────────────────────────────

# ── Flutter ──
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Firebase ──
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ── Google Sign-In ──
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ── Gson (used by Firebase) ──
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }

# ── OkHttp / Okio (network layer) ──
-dontwarn okhttp3.**
-dontwarn okio.**

# ── Prevent stripping of R8-incompatible code ──
-dontwarn javax.annotation.**

# ── Play Core (deferred components) ──
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
