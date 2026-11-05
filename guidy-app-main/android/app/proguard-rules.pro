# Flutter Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Play Services & Maps
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Firebase
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.** { *; }

# Google Mobile Ads (AdMob)
-keep public class com.google.android.gms.ads.** { public *; }
-keep public class com.google.ads.** { public *; }

# Flutter's embedding engine references Google Play "deferred components"
# (dynamic feature delivery) classes that only exist if the app depends on
# com.google.android.play:core. Guidy ships as one normal APK and doesn't
# use deferred/dynamic feature delivery, so those classes are never on the
# classpath -- R8 (as of recent AGP versions) treats that as a hard error
# by default instead of a warning, which fails minifyRelease. This is
# Flutter's own documented fix for that exact failure, not a Guidy-specific
# workaround: https://github.com/flutter/flutter/issues/119020
-dontwarn com.google.android.play.core.**

# WorkManager (pulled in by Google's ads and Firebase SDKs) creates its Room
# database and input mergers by reflection through their no-arg
# constructors. Room 2.2.5's and WorkManager 2.7.0's own rules keep the
# classes but not the constructors, which AGP 9's R8 strict full mode no
# longer implies: the release app crashed at launch with "Failed to create
# an instance of androidx.work.impl.WorkDatabase" (2026-09-27).
# android.r8.strictFullModeForKeepRules=false in gradle.properties fixed
# it; these keep it fixed if that switch goes away.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class * extends androidx.work.InputMerger { <init>(); }

# flutter_local_notifications: scheduled notifications are saved with Gson
# (and read back after a reboot). R8 strips generic signatures and renames the
# plugin's model classes, which breaks that with "Missing type parameter" in a
# release build -- the commute alerts then never schedule or never come back.
-keepattributes Signature,InnerClasses,EnclosingMethod
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
