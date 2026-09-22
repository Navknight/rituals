# Flutter's own embedding is kept by the Flutter Gradle plugin; these cover the
# plugins this app uses that rely on reflection.

# Firebase and Google Play services read annotated members reflectively.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# flutter_local_notifications deserialises its scheduled notifications with Gson.
-keep class com.dexterous.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-dontwarn com.dexterous.**

# The home screen widget provider is referenced only from the manifest.
-keep class io.github.navknight.rituals.RitualWidgetProvider { *; }
