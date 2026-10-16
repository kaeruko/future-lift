import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signing is supplied locally or by GitHub Actions. Never fall back to debug
// keys for a Google Play release.
val releasePropertiesFile = rootProject.file("key.properties")
val releaseProperties = Properties()
val hasReleaseSigning = releasePropertiesFile.isFile
if (hasReleaseSigning) {
    releasePropertiesFile.inputStream().use { releaseProperties.load(it) }
}

fun requiredSigningProperty(name: String): String {
    return releaseProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException("Missing Android release signing property: $name")
}

android {
    namespace = "jp.futurelift.future_lift"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "jp.cloxs.kotohogu"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(requiredSigningProperty("storeFile"))
                storePassword = requiredSigningProperty("storePassword")
                keyAlias = requiredSigningProperty("keyAlias")
                keyPassword = requiredSigningProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
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

// Explicitly fail rather than creating a debug-signed release artifact.
gradle.taskGraph.whenReady {
    val releasing = allTasks.any { task ->
        task.path == ":app:bundleRelease" || task.path == ":app:assembleRelease"
    }
    if (releasing && !hasReleaseSigning) {
        throw GradleException(
            "Android release signing required: missing android/key.properties"
        )
    }
}
