# ProGuard/R8-Regeln für kailibrate.
#
# Noch nicht aktiv: minifyEnabled/shrinkResources stehen in build.gradle
# auf false (siehe Issue #63). Vor der Aktivierung einen Release-Build
# auf einem Gerät testen – insbesondere geplante Benachrichtigungen
# (flutter_local_notifications nutzt Gson-Reflection).

# --- flutter_local_notifications ---
# Geplante Notifications werden via Gson (de)serialisiert.
-keep class com.dexterous.** { *; }

# --- Gson (transitiv über flutter_local_notifications) ---
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

# --- sqlite3_flutter_libs / Drift ---
# Drift ist pures Dart; sqlite3_flutter_libs liefert nur native Libs.
# Keine zusätzlichen Keep-Rules nötig (Stand drift 2.x).

# --- Play Core (von Flutter referenziert, hier nicht verwendet) ---
-dontwarn com.google.android.play.core.**
