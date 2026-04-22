plugins {
    id("com.android.application")
    id("kotlin-android")
    // لا بد من وجود هذا السطر لربط فلاتر
    id("dev.flutter.flutter-gradle-plugin")
    // هذا السطر هو المسؤول عن تفعيل خدمات جوجل (Firebase)
    id("com.google.gms.google-services")
}

android {
    // يجب أن يتطابق مع المعرف في Firebase وملف الـ JSON
    namespace = "com.sohail.supermarket.admin"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "30.0.14904198"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // هذا هو المعرف الفريد لتطبيقك
        applicationId = "com.sohail.supermarket.admin"
        
        minSdk = 21
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // تفعيل MultiDex للتعامل مع عدد المكتبات الكبير في Firebase
        multiDexEnabled = true
    }

    signingConfigs {
        getByName("debug") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
        getByName("release") {
            // حالياً نستخدم إعدادات الديباج للتجربة
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // دعم تعدد ملفات الـ Dex (ضروري لـ Firebase)
    implementation("androidx.multidex:multidex:2.0.1")
    // استيراد منصة Firebase
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-analytics")
}
