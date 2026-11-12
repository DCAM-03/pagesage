plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// CI supplies these only for trusted builds; never write passwords to the repo.
val signingValues = listOf(
    "PAGESAGE_ANDROID_KEYSTORE_PATH", "PAGESAGE_ANDROID_STORE_PASSWORD",
    "PAGESAGE_ANDROID_KEY_ALIAS", "PAGESAGE_ANDROID_KEY_PASSWORD",
).associateWith { System.getenv(it)?.takeIf(String::isNotBlank) }
val hasReleaseSigning = signingValues.values.all { it != null }
require(signingValues.values.all { it == null } || hasReleaseSigning) {
    "Android signing requires all four PAGESAGE_ANDROID_* environment values"
}
require(System.getenv("PAGESAGE_REQUIRE_RELEASE_SIGNING") != "true" || hasReleaseSigning) {
    "This build requires release signing; configure the Android signing Secrets"
}

android {
    namespace = "dev.pagesage.app"
    // flutter_secure_storage 11.x requires compileSdk 37; Flutter 3.44.2
    // still defaults to 36, so pin it explicitly.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.pagesage.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("distribution") {
                storeFile = file(signingValues.getValue("PAGESAGE_ANDROID_KEYSTORE_PATH")!!)
                storePassword = signingValues.getValue("PAGESAGE_ANDROID_STORE_PASSWORD")
                keyAlias = signingValues.getValue("PAGESAGE_ANDROID_KEY_ALIAS")
                keyPassword = signingValues.getValue("PAGESAGE_ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseSigning) "distribution" else "debug")
        }
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
    // Local OCR for scan PDFs (Phase 1). Latin + Chinese script packs are offline.
    implementation("com.google.mlkit:text-recognition:16.0.1")
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
    implementation("com.google.android.gms:play-services-tasks:18.2.0")
}
