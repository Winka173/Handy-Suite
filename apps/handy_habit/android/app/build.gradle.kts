import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: the upload key stays out of the repo. `android/key.properties`
// (gitignored) holds storeFile, storePassword, keyAlias and keyPassword; the
// owner's copy is ~/.secrets/handy-habit-upload.properties. Without it a
// release build is left unsigned, so Play can never get a debug-signed one.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.example.handysuite.habit"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        manifestPlaceholders["handyAdmobAppId"] = providers.gradleProperty("handyAdmobAppId").orElse("ca-app-pub-3940256099942544~3347511713").get()
        // The Play Store identity; it can never change after the first upload.
        // (The Kotlin namespace keeps its old name: widget and channel class
        // names hang on it.)
        applicationId = "com.apps.winka.handyhabit"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Never signed with the debug key: without key.properties the
            // bundle stays unsigned and Play refuses it.
            if (hasReleaseKey) signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Development builds keep the id they always had, so the habits already on
// test devices stay where they are; store builds use the Play id above.
androidComponents {
    onVariants(selector().withBuildType("debug")) { variant ->
        variant.applicationId.set("com.example.handysuite.habit.flutterpilot")
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
