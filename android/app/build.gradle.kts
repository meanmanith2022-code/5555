plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.meanney_ai_video_voice_dubber"
    compileSdk = 36
    buildToolsVersion = "34.0.0"

    defaultConfig {
        applicationId = "com.example.meanney_ai_video_voice_dubber"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}