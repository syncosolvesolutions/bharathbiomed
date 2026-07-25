# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase / Crashlytics — keep stack traces symbol-mappable and avoid
# stripping classes the SDKs reach via reflection.
-keepattributes SourceFile,LineNumberTable,*Annotation*
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# sqflite / gson-style reflection used by some plugins
-keepclassmembers class * {
    @com.google.firebase.database.PropertyName <fields>;
}
