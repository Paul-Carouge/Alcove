plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.github.paulcarouge.alcove"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.paulcarouge.alcove"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing (published APKs): the keystore comes from the environment (CI secrets) or
    // ALCOVE_ANDROID_KEYSTORE on a maintainer machine. Without it, release builds use the debug key
    // so that `flutter run --release` still works; such APKs must not be published.
    val keystore = System.getenv("ALCOVE_ANDROID_KEYSTORE")?.let { file(it) }?.takeIf { it.exists() }
    signingConfigs {
        if (keystore != null) {
            create("release") {
                storeFile = keystore
                storePassword = System.getenv("ALCOVE_ANDROID_KEYSTORE_PASSWORD")
                keyAlias = "alcove"
                keyPassword = System.getenv("ALCOVE_ANDROID_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (keystore != null) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

// Flutter gives per-ABI APKs (--split-per-abi) the versionCode 1000 × ABI + code, a Play Store
// convention. Alcove's APKs are sideloaded and interchangeable with the universal one, so they keep its
// code: otherwise a phone updated with a per-ABI APK would refuse the next universal APK as a downgrade
// (ADR 0029). This callback is registered after the Flutter plugin's, so it runs last.
@Suppress("DEPRECATION")
android.applicationVariants.configureEach {
    val code = versionCode
    outputs.configureEach {
        (this as com.android.build.gradle.api.ApkVariantOutput).versionCodeOverride = code
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
    // FileProvider, to hand downloaded updates to the system installer (MainActivity).
    implementation("androidx.core:core-ktx:1.13.1")
}
