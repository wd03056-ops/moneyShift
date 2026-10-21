# =============================================================================
# Money Shift — ProGuard / R8 (Play Store release)
# minifyEnabled + shrinkResources + obfuscation
# =============================================================================

# ----- Flutter engine / embedding -----
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ----- Play Core (Flutter deferred components stubs) -----
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# ----- Firebase / Google Play services -----
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.firestore.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepattributes Exceptions
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeInvisibleAnnotations

# Firestore PropertyName / ServerTimestamp
-keepclassmembers class * {
  @com.google.firebase.firestore.PropertyName <fields>;
  @com.google.firebase.firestore.ServerTimestamp <fields>;
  @com.google.firebase.firestore.DocumentId <fields>;
}

# ----- Kakao SDK (로그인 / Redirect URI) -----
-keep class com.kakao.** { *; }
-keep interface com.kakao.** { *; }
-dontwarn com.kakao.**
-keep class com.kakao.sdk.** { *; }
-keep class com.kakao.sdk.flutter.** { *; }

# ----- flutter_local_notifications -----
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# ----- app_links / deep links -----
-keep class com.llfbandit.app_links.** { *; }
-dontwarn com.llfbandit.app_links.**

# ----- Geolocator / location -----
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**
-keep class com.google.android.gms.location.** { *; }

# ----- OkHttp / gRPC (Firestore transport) -----
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.**
-dontwarn org.conscrypt.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ----- Kotlin / Coroutines -----
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**
-keep class kotlin.Metadata { *; }
-keepclassmembers class kotlinx.coroutines.** { *; }

# ----- Native methods -----
-keepclasseswithmembernames class * {
    native <methods>;
}

# ----- Parcelable / Serializable -----
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ----- Enums -----
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ----- R8: keep line numbers for crash symbolication -----
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ----- Guava / animal sniffer (transitive) -----
-dontwarn com.google.common.**
-dontwarn sun.misc.**
