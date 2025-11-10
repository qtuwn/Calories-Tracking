import com.android.build.gradle.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Ensure older Android library plugins from pub cache that don't specify a
// namespace are given a default namespace so AGP (8.x) doesn't fail the build.
// This is a local, temporary workaround to unblock development. It assigns a
// deterministic namespace derived from the package folder name.
subprojects {
    plugins.withId("com.android.library") {
        try {
            val androidExt = extensions.findByType(LibraryExtension::class.java)
            if (androidExt != null) {
                val ns = androidExt.namespace
                if (ns == null || ns.isEmpty()) {
                    // safe default namespace per-project
                    androidExt.namespace = "com.example.${project.name.replace('-', '_')}"
                }
            }
        } catch (e: Exception) {
            // ignore - best effort only
        }
    }
}
