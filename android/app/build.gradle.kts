plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.calories_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Enable core library desugaring for libraries that require newer Java APIs
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.calories_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // The health plugin (and its AndroidX Health Connect dependencies) requires
        // a minimum SDK of 26. We set it explicitly here to satisfy library
        // requirements. If you need to support older Android versions, choose a
        // different plugin version or remove the dependency.
        minSdk = 26
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

flutter {
    source = "../.."
}

dependencies {
    // Required for core library desugaring when plugins (e.g. flutter_local_notifications)
    // require newer Java language features in Android libraries.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
// Note: google-services plugin classpath is declared in the top-level build.gradle.kts

// Apply the Google Services Gradle plugin (Kotlin DSL)
apply(plugin = "com.google.gms.google-services")
