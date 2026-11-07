import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: the upload key stays out of the repo. `android/key.properties`
// (gitignored) holds storeFile, storePassword, keyAlias and keyPassword; the
// owner's copy is ~/.secrets/handy-bookmark-upload.properties. Without it a
// release build is left unsigned, so Play can never get a debug-signed one.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.example.handysuite.save"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The Play Store identity; it can never change after the first upload.
        // (The Kotlin namespace and the on-device storage names keep their
        // old names on purpose.)
        applicationId = "com.apps.winka.handybookmark"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
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
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Development builds keep the id they always had, so the libraries already
// on test devices stay where they are; store builds use the Play id above.
androidComponents {
    onVariants(selector().withBuildType("debug")) { variant ->
        variant.applicationId.set("com.example.handysuite.bookmark.flutterpilot")
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
    androidTestImplementation("androidx.test:runner:1.3.0")
    androidTestImplementation("androidx.test.ext:junit:1.1.2")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // The app lock's biometric prompt needs AppCompat themes.
    implementation("androidx.appcompat:appcompat:1.7.1")
}
