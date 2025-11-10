pluginManagement {
    val flutterSdkPath = run {
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
    // Bump Android Gradle Plugin to 8.9.1 to satisfy newer AndroidX AAR metadata
    // (e.g. androidx.health.connect:connect-client:1.1.0-rc03 requires AGP >= 8.9.1).
    id("com.android.application") version "8.9.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.3.15") apply false
    // END: FlutterFire Configuration
    // Kotlin plugin bumped to match newer plugin toolchain used by some dependencies.
    id("org.jetbrains.kotlin.android") version "2.2.10" apply false
}

include(":app")
