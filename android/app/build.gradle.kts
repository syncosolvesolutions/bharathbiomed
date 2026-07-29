import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.reader(Charsets.UTF_8).use { reader ->
        localProperties.load(reader)
    }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Per-tenant applicationId/app-name, kept out of source so a white-label
// build doesn't require hand-editing this file — see
// tenants/<tenantId>/tenant.properties, copied to android/tenant.properties
// (same directory as local.properties/key.properties above — this is the
// Gradle root for the Android build, not the Flutter project root) by
// scripts/new_tenant.sh for that tenant's build. `namespace` above stays
// fixed regardless (it's tied to the physical Kotlin package under
// src/main/kotlin/ — see MainActivity.kt — and, unlike applicationId, AGP
// doesn't need it to vary per tenant). Falls back to this repo's own
// already-published identity when no tenant.properties is present, so a
// plain `flutter build`/`flutter run` with no tenant setup keeps working
// exactly as before. Note a real per-tenant build also needs that tenant's
// own google-services.json in this directory — the applicationId must have
// a matching client entry there, or processDebugGoogleServices fails fast
// (verified while testing this).
val tenantProperties = Properties()
val tenantPropertiesFile = rootProject.file("tenant.properties")
if (tenantPropertiesFile.exists()) {
    tenantPropertiesFile.reader(Charsets.UTF_8).use { reader ->
        tenantProperties.load(reader)
    }
}
val tenantApplicationId = tenantProperties.getProperty("applicationId") ?: "com.syncosolve.bharathbiomedpharma"
val tenantAppLabel = tenantProperties.getProperty("appLabel") ?: "Bharath Biomed Pharma"

android {
    namespace = "com.syncosolve.bharathbiomedpharma"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        applicationId = tenantApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://docs.flutter.dev/deployment/android#reviewing-the-gradle-build-configuration.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
        // Resolves the `${appLabel}` placeholder in AndroidManifest.xml's
        // android:label — see the tenantAppLabel comment above.
        manifestPlaceholders["appLabel"] = tenantAppLabel
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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

dependencies {}
