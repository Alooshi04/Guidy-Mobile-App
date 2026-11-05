import java.util.Base64
import java.util.Properties
import java.io.FileInputStream
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
	id("com.google.gms.google-services")
	id("com.google.firebase.crashlytics")
}

// Single source of truth for API keys -- see secrets.properties.example
// at the Flutter project root. Falls back to the .example template (all
// placeholder values) if secrets.properties hasn't been created yet, so
// a fresh clone still builds -- it just won't have working Maps/
// AdMob until real values are filled in.
val secretsProperties = Properties()
val secretsFile = rootProject.file("../secrets.properties")
val secretsExampleFile = rootProject.file("../secrets.properties.example")
if (secretsFile.exists()) {
    secretsProperties.load(FileInputStream(secretsFile))
} else if (secretsExampleFile.exists()) {
    logger.warn("secrets.properties not found -- using secrets.properties.example placeholder values. Maps/AdMob won't work until you create a real secrets.properties.")
    secretsProperties.load(FileInputStream(secretsExampleFile))
}
fun secret(key: String): String = secretsProperties.getProperty(key, "")

// Release signing -- see key.properties.example at the Flutter project
// root for the template. Real values (and the keystore file itself) go
// in android/key.properties and android/app/*.jks, both gitignored --
// see https://flutter.dev/to/reference-keystore. CI (release.yml) always
// provisions this from repo secrets before invoking Gradle, so it never
// hits the missing-file path below.
//
// If key.properties is missing when a *release* build is actually
// requested, this used to just log a warning and silently fall back to
// debug signing -- easy to miss in the gradle output, and the resulting
// "release" APK looks fine locally but Play Store will reject it on
// upload. Fail loudly instead: a release build with no real keystore
// configured refuses to proceed unless the missing-signing fallback is
// explicitly acknowledged with -PallowDebugSigningFallback=true (for the
// rare case of wanting a quick local release-mode build -- e.g. checking
// R8/minification -- without a real keystore on hand). Debug builds are
// completely unaffected either way.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
val allowDebugSigningFallback =
    (project.findProperty("allowDebugSigningFallback") as String?)?.toBoolean() ?: false
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else if (allowDebugSigningFallback) {
    logger.warn("android/key.properties not found -- ALLOWING debug-signed release build because -PallowDebugSigningFallback=true was passed. This APK will be rejected by Play Store; do not upload it.")
}

// Ads-off builds (--dart-define=GUIDY_NO_ADS=true) must not declare the
// advertising ID. Flutter hands the dart-defines to Gradle as a comma
// separated list of base64 "KEY=value" pairs.
val adsOffBuild: Boolean = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.any { String(Base64.getDecoder().decode(it)) == "GUIDY_NO_ADS=true" }
    ?: false

android {
    namespace = "com.guidy.guidy_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (commute notifications) needs it.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.guidy.guidy_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Substituted into AndroidManifest.xml's ${...} placeholders.
        manifestPlaceholders["mapsApiKey"] = secret("MAPS_API_KEY_ANDROID")
        manifestPlaceholders["admobAppId"] = secret("ADMOB_APP_ID_ANDROID")
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    if (adsOffBuild) {
        // Overlay that removes the AD_ID permission, release builds only.
        sourceSets.getByName("release").manifest.srcFile("src/noads/AndroidManifest.xml")
    }

    buildTypes {
        release {
            // Real release signing when android/key.properties is present,
            // debug signing otherwise. The "refuse to build without a real
            // keystore" check used to live right here -- which was wrong:
            // Gradle configures EVERY build type block eagerly regardless
            // of which task actually gets invoked, so that throw fired even
            // for a plain `flutter build apk --debug`, failing debug builds
            // outright on any machine without key.properties (found via
            // CI, 2026-09-15 -- it never showed up locally because
            // key.properties already exists on the dev machine). The real
            // check now lives below, gated on the task graph actually
            // containing a release task.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

// Refuse to build a *release* APK with no real keystore configured, unless
// explicitly acknowledged via -PallowDebugSigningFallback=true (see the
// comment above hasReleaseSigning) -- silently shipping a debug-signed APK
// from a release build is exactly the mistake worth refusing to make by
// default. This has to be gated on the task graph rather than living
// inside buildTypes { release { ... } } directly: Gradle configures every
// build type block during the configuration phase no matter which task was
// requested, so a check there would fire even for `assembleDebug`. Gating
// on gradle.taskGraph.whenReady only fails the build when a release task
// (assembleRelease, bundleRelease, etc.) is actually part of what's
// running -- a plain debug build never touches this at all.
gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { task ->
        task.name.startsWith("assembleRelease") ||
            task.name.startsWith("bundleRelease") ||
            task.name.startsWith("packageRelease")
    }
    if (buildingRelease && !hasReleaseSigning && !allowDebugSigningFallback) {
        throw GradleException(
            "Refusing to build a 'release' APK: android/key.properties is missing, " +
            "so this would silently fall back to debug signing (Play Store rejects " +
            "debug-signed uploads). Create android/key.properties from " +
            "android/key.properties.example with a real release keystore, or, if you " +
            "specifically want a debug-signed release-mode build for local testing " +
            "(e.g. checking R8/minification), re-run with " +
            "-PallowDebugSigningFallback=true to acknowledge that explicitly."
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
