plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.handysuite.handy_boards"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.handysuite.handy_boards"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug { applicationIdSuffix = ".flutterpilot" }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            // Configure authorized release signing before store distribution.
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

dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }

// Flutter workspace pub resolution can regenerate a debug registrant while a
// release is compiling. integration_test is a dev-only plugin, absent from the
// release classpath. Remove only that stale registration immediately before
// javac; debug builds keep their normal Flutter-generated registration.
tasks.withType<org.gradle.api.tasks.compile.JavaCompile>().configureEach {
    if (name.contains("Release")) {
        doFirst {
            val registrant = file("src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")
            if (registrant.exists()) {
                val source = registrant.readText()
                val devOnly = Regex("""(?s)\s*try \{\s*flutterEngine\.getPlugins\(\)\.add\(new dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\(\)\);\s*\} catch \(Exception e\) \{.*?\n\s*\}""")
                val releaseSource = source.replace(devOnly, "")
                check(!releaseSource.contains("dev.flutter.plugins.integration_test")) { "Unexpected integration_test registration; preserve source and inspect Flutter generator" }
                if (source != releaseSource) registrant.writeText(releaseSource)
            }
        }
    }
}
