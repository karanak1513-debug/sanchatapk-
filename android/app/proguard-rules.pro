# Flutter & Engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase & Google Play Services
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Play Core & Deferred Components
-dontwarn com.google.android.play.core.**

# Local Auth / Biometric
-keep class androidx.biometric.** { *; }

# File Providers & Permissions
-keep class androidx.core.content.FileProvider { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }

