group = "app.forma.forma_pose"
version = "0.1.0"

buildscript {
    val kotlinVersion = "2.2.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "app.forma.forma_pose"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        // CameraX + MediaPipe Tasks need API 24.
        minSdk = 24
    }
}

// Licences: CameraX (Apache 2.0), MediaPipe Tasks Vision (Apache 2.0), AndroidX (Apache 2.0).
// Versions are pinned for 16 KB page-size support, which Google Play requires
// for apps targeting Android 15+ (verified on a Galaxy S23 / Android 16).
dependencies {
    val cameraxVersion = "1.6.2"
    implementation("androidx.camera:camera-core:$cameraxVersion")
    implementation("androidx.camera:camera-camera2:$cameraxVersion")
    implementation("androidx.camera:camera-lifecycle:$cameraxVersion")
    implementation("androidx.camera:camera-view:$cameraxVersion")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.lifecycle:lifecycle-common:2.8.7")
    // MediaPipe Pose Landmarker (BlazePose GHUM): 33 landmarks + world landmarks.
    implementation("com.google.mediapipe:tasks-vision:1.0.0")
}
