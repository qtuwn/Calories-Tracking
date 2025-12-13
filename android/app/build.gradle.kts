plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.calories_app"
    // flutter_local_notifications 19.5.0+ and plugins require compileSdk 36
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Core library desugaring is required for flutter_local_notifications
        // which uses Java 8+ APIs (e.g., java.time) on older Android versions
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.calories_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Health Connect requires minSdk 26, using 28 for better compatibility
        minSdk = maxOf(flutter.minSdkVersion, 28)
        // flutter_local_notifications 19.5.0+ and plugins require targetSdk 36
        targetSdk = 36
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

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring dependency required for flutter_local_notifications 19.5.0+
    // This enables Java 8+ APIs (e.g., java.time) on Android API levels below 26
    // Version 2.1.4+ required for flutter_local_notifications 19.5.0+
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // WindowManager dependency to prevent crashes with desugaring on Android 12L+
    implementation("androidx.window:window:1.2.0")
}
