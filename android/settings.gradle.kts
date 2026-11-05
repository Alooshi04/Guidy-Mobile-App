pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
	// 4.4.0 -> 4.4.4: the Crashlytics plugin pinned on the next line is
	// v3, which refuses to configure against google-services below
	// 4.4.1 ("The Crashlytics Gradle plugin 3 requires Google-Services
	// 4.4.1 and above"). Both versions are pinned, so this was not a
	// resolution fluke -- the Android build could not have succeeded
	// from a clean checkout with these two together.
	id("com.google.gms.google-services") version "4.4.4" apply false
	id("com.google.firebase.crashlytics") version "3.0.7" apply false
}

include(":app")
