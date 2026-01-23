plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.thememorylane"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Flag to enable support for the new language APIs
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.thememorylane"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

configurations.all {
    resolutionStrategy {
        force("androidx.activity:activity:1.8.0")
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Update desugar_jdk_libs to the required version
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
