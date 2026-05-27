plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.docforge_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
    }

    flavorDimensions += "channel"

    productFlavors {
        create("xiaomi") {
            dimension = "channel"
            applicationId = "com.docforge.app.xiaomi"
            versionCode = flutter.versionCode
            versionName = flutter.versionName
        }
        create("vivo") {
            dimension = "channel"
            applicationId = "com.docforge.app.vivo"
            versionCode = flutter.versionCode
            versionName = flutter.versionName
        }
        create("huawei") {
            dimension = "channel"
            applicationId = "com.docforge.app.huawei"
            versionCode = flutter.versionCode
            versionName = flutter.versionName
        }
        create("oppo") {
            dimension = "channel"
            applicationId = "com.docforge.app.oppo"
            versionCode = flutter.versionCode
            versionName = flutter.versionName
        }
        create("honor") {
            dimension = "channel"
            applicationId = "com.docforge.app.honor"
            versionCode = flutter.versionCode
            versionName = flutter.versionName
        }
        create("official") {
            dimension = "channel"
            applicationId = "com.docforge.app"
            versionCode = flutter.versionCode
            versionName = flutter.versionName
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // CI 在 steps 中解码 keystore 到 build/ 目录，本地无文件时降级 debug 签名
            val keystoreFile = file("${projectDir}/build/docforge-release.jks")
            if (keystoreFile.exists()) {
                signingConfig = signingConfigs.create("release") {
                    storeFile = keystoreFile
                    storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD") ?: ""
                    keyAlias = System.getenv("ANDROID_KEY_ALIAS") ?: ""
                    keyPassword = System.getenv("ANDROID_KEY_PASSWORD") ?: ""
                }
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 华为 HMS IAP + AGConnect 初始化
    implementation("com.huawei.hms:iap:6.13.0.300")
    implementation("com.huawei.agconnect:agconnect-core:1.9.1.301")
}
