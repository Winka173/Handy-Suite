plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        manifestPlaceholders["handyAdmobAppId"] = providers.gradleProperty("handyAdmobAppId").orElse("ca-app-pub-3940256099942544~3347511713").get()
        applicationId = "com.example.handysuite.bookmark"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug { applicationIdSuffix = ".flutterpilot" }
        release {
            // Release artifacts remain unsigned until the publisher supplies signing.
            // Never sign a production release with the development debug key.
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
    androidTestImplementation("androidx.test:runner:1.3.0")
    androidTestImplementation("androidx.test.ext:junit:1.1.2")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
