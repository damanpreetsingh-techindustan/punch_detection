# AndroidX WorkManager & WorkDatabase reflection rules for R8 / ProGuard
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}
-keep class * extends androidx.work.impl.WorkDatabase {
    public <init>();
}
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }

# AndroidX Room Database rules
-keep class * extends androidx.room.RoomDatabase {
    public <init>();
}
-keepclassmembers class * extends androidx.room.RoomDatabase {
    public <init>();
}
-keep class androidx.room.** { *; }

# AndroidX App Startup
-keep class androidx.startup.** { *; }

# Google ML Kit & Play Services Tasks
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ML Kit pose detection runs MediaPipe, whose native code reads fields of these
# classes by name over JNI. Without these rules R8 renames them and release
# builds crash with "JNI DETECTED ERROR: fid == null" in PacketCreator.
-keep class com.google.mediapipe.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.mediapipe.**
-dontwarn com.google.protobuf.**
