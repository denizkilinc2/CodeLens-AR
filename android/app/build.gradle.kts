plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.codelens.codelens_ar"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // NOTE: JVM target for Kotlin compilation is now set centrally for ALL
    // subprojects (including this one) in the root android/build.gradle.kts,
    // using the modern compilerOptions DSL. The old kotlinOptions{} block
    // was removed from here because it's deprecated/broken on recent
    // Kotlin Gradle Plugin versions.

    defaultConfig {
        applicationId = "com.codelens.codelens_ar"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// NOTE: We previously excluded com.android.support:support-compat here to
// fix a "duplicate class" build error. That was the WRONG fix — it silently
// broke ar_flutter_plugin's plane-discovery UI at runtime (it needs
// AppCompatImageView, which lived in that library). The correct fix is
// enabling Jetifier in gradle.properties (android.enableJetifier=true),
// which auto-converts legacy support-library classes to their AndroidX
// equivalents instead of just deleting them. See gradle.properties.

flutter {
    source = "../.."
}
