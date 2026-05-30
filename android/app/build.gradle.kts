import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// 读取 key.properties 签名配置
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
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

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
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
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
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
