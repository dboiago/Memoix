import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else {
    // This forces the build to loudly crash if it can't find your file!
    throw GradleException("Could not find key.properties file! Looking in: ${keystorePropertiesFile.absolutePath}")
}

android {
    namespace = "io.github.dboiago.memoix"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // ADDED: Your Release Signing Configuration
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "io.github.dboiago.memoix"
        manifestPlaceholders["appAuthRedirectScheme"] = "io.github.dboiago.memoix"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
		
		// Default to 'remove' so Play Store is happy by default
		manifestPlaceholders["otaPermission"] = "<uses-permission android:name=\"android.permission.REQUEST_INSTALL_PACKAGES\" tools:node=\"remove\" />"
    }

    buildTypes {
        getByName("release") {
            // CHANGED: Now points to the release block above instead of "debug"
            signingConfig = signingConfigs.getByName("release")
            
            // Make sure this line exists with the parentheses and double quotes!
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}