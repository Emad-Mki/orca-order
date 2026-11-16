plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

if (file("google-services.json").isFile) {
    apply(plugin = "com.google.gms.google-services")
}

val releaseStoreFile = System.getenv("ORCA_RELEASE_STORE_FILE")
val releaseStorePassword = System.getenv("ORCA_RELEASE_STORE_PASSWORD")
val releaseKeyAlias = System.getenv("ORCA_RELEASE_KEY_ALIAS")
val releaseKeyPassword = System.getenv("ORCA_RELEASE_KEY_PASSWORD")
val releaseVersionName = System.getenv("ORCA_VERSION_NAME") ?: "1.0.0.01"
val hasOriginalReleaseKey = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword
).all { !it.isNullOrBlank() }

if (System.getenv("ORCA_REQUIRE_RELEASE_SIGNING") == "true" &&
    !hasOriginalReleaseKey
) {
    throw GradleException(
        "Release signing was required, but the original signing credentials are missing."
    )
}

android {
    namespace = "com.example.orca_order"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.orca_order"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 37
        versionCode = flutter.versionCode
        // Android versionName allows the requested zero-padded display version.
        versionName = releaseVersionName
    }

    if (hasOriginalReleaseKey) {
        signingConfigs {
            create("originalRelease") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword!!
                keyAlias = releaseKeyAlias!!
                keyPassword = releaseKeyPassword!!
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasOriginalReleaseKey) {
                signingConfigs.getByName("originalRelease")
            } else {
                signingConfigs.getByName("debug")
            }
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.core:core:1.15.0")
}
