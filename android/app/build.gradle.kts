import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")

    // Firebase / Google Services
    id("com.google.gms.google-services")

    // Kotlin
    id("kotlin-android")

    // Flutter plugin must remain after Android and Kotlin plugins
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------
// Release Signing Configuration
// ---------------------------------------------------------

// ---------------------------------------------------------
// Google Maps API key
// ---------------------------------------------------------
// Read from (first match wins): android/local.properties `MAPS_API_KEY=...`
// (git-ignored), a Gradle property (-PMAPS_API_KEY / ~/.gradle/gradle.properties)
// or the MAPS_API_KEY environment variable (CI). Gradle's findProperty() does
// NOT read local.properties, which is why the map used to render blank.
val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val mapsApiKey: String =
    (localProperties.getProperty("MAPS_API_KEY")
        ?: project.findProperty("MAPS_API_KEY") as String?
        ?: System.getenv("MAPS_API_KEY")
        ?: "").trim()
if (mapsApiKey.isEmpty()) {
    logger.warn(
        "MAPS_API_KEY is not set: Google Maps will show a blank map. " +
            "Add MAPS_API_KEY=<android key> to android/local.properties."
    )
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.rashidapps.skillnova"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // -----------------------------------------------------
    // Java / Kotlin
    // -----------------------------------------------------

    compileOptions {
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // -----------------------------------------------------
    // Default App Configuration
    // -----------------------------------------------------

    defaultConfig {
        applicationId = "com.rashidapps.skillnova"

        // ML Kit Text Recognition v2 requires Android API 23+
        minSdk = flutter.minSdkVersion

        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Google Maps API key
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    // -----------------------------------------------------
    // Release Signing
    // -----------------------------------------------------

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?

            storeFile = keystoreProperties["storeFile"]?.let {
                file(it)
            }

            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    // -----------------------------------------------------
    // Build Types
    // -----------------------------------------------------

    buildTypes {

        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }

        getByName("release") {

            signingConfig = signingConfigs.getByName("release")

            // Production optimizations
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile(
                    "proguard-android-optimize.txt"
                ),
                "proguard-rules.pro"
            )
        }
    }
}

// ---------------------------------------------------------
// Flutter
// ---------------------------------------------------------

flutter {
    source = "../.."
}

// ---------------------------------------------------------
// Dependencies
// ---------------------------------------------------------

dependencies {

    // Java 8+ API desugaring
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4"
    )

    // -----------------------------------------------------
    // Google ML Kit Text Recognition
    // -----------------------------------------------------

    // Latin / English
    implementation(
        "com.google.mlkit:text-recognition:16.0.1"
    )

    // Required because google_mlkit_text_recognition
    // references these recognizers internally.

    implementation(
        "com.google.mlkit:text-recognition-chinese:16.0.1"
    )

    implementation(
        "com.google.mlkit:text-recognition-devanagari:16.0.1"
    )

    implementation(
        "com.google.mlkit:text-recognition-japanese:16.0.1"
    )

    implementation(
        "com.google.mlkit:text-recognition-korean:16.0.1"
    )
}
