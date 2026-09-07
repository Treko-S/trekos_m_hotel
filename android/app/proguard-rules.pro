# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Supabase / Ktor / Coroutines
-keepattributes *Annotation*,InnerClasses,EnclosingMethod
-keepattributes Signature
-keepattributes Exceptions
-dontwarn io.ktor.**
-dontwarn kotlinx.coroutines.**

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Play Core Deferred Components
-dontwarn com.google.android.play.core.**
