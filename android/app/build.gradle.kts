plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.iosmacs_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.iosmacs_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDir(file("../../../build/emacs-android/arm64-v8a/iosmacs/jniLibs"))
            assets.srcDir(file("../../../build/emacs-android/arm64-v8a/java/install_temp/assets"))
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    // Store Emacs charset map files uncompressed so assets.list() works for the
    // etc/charsets/ directory during first-launch asset extraction.
    aaptOptions {
        noCompress(".map")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

val androidEmacsJavaBridgeJar =
    file("../../../build/emacs-android/arm64-v8a/iosmacs/emacs-android-java.jar")

dependencies {
    if (androidEmacsJavaBridgeJar.exists()) {
        implementation(files(androidEmacsJavaBridgeJar))
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
