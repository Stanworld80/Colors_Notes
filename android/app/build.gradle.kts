import java.util.Properties // Import nécessaire

val keyPropertiesFile =
    rootProject.file("../key.properties") // Chemin relatif depuis le dossier 'app' vers 'android/key.properties'
val keyProperties = Properties() // Utilisation de la classe Properties importée
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { input ->
        keyProperties.load(input)
    }
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
android {
    namespace = "org.stanworld.colorsnotes"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }



    signingConfigs {
        getByName("debug") {
            defaultConfig {
                applicationId = "org.stanworld.colorsnotes"
                minSdk = 23
                targetSdk = flutter.targetSdkVersion
                versionCode = flutter.versionCode
                versionName = flutter.versionName
            }

            create("release") {
                if (keyProperties.containsKey("storeFile")) {
                    storeFile =
                        file(keyProperties.getProperty("storeFile")) // Utilise file() pour résoudre le chemin
                    storePassword = keyProperties.getProperty("storePassword")
                    keyAlias = keyProperties.getProperty("keyAlias")
                    keyPassword = keyProperties.getProperty("keyPassword")
                }
            }
        }
    }


    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("release")
        }

        debug {
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
