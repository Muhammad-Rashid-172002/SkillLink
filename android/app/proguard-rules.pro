# =========================================================
# SkillNova - Production ProGuard / R8 Rules
# =========================================================


# ---------------------------------------------------------
# Flutter
# ---------------------------------------------------------

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

-dontwarn io.flutter.embedding.**


# ---------------------------------------------------------
# Firebase / Google Play Services
# ---------------------------------------------------------

-keepattributes Signature
-keepattributes *Annotation*

-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**


# ---------------------------------------------------------
# Google ML Kit
# ---------------------------------------------------------

-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }

-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.mlkit_vision_text_common.**


# ---------------------------------------------------------
# ML Kit Text Recognition
# ---------------------------------------------------------

-keep class com.google.mlkit.vision.text.** { *; }

-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**


# ---------------------------------------------------------
# Preserve generic type information / annotations
# ---------------------------------------------------------

-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes Signature
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeInvisibleAnnotations
-keepattributes RuntimeVisibleParameterAnnotations
-keepattributes RuntimeInvisibleParameterAnnotations


# ---------------------------------------------------------
# Keep native methods
# ---------------------------------------------------------

-keepclasseswithmembernames class * {
    native <methods>;
}


# ---------------------------------------------------------
# Keep Parcelable CREATOR fields
# ---------------------------------------------------------

-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}


# ---------------------------------------------------------
# Keep Serializable members
# ---------------------------------------------------------

-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
}