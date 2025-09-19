import java.util.Properties // Import nécessaire pour Properties

// Configuration pour lire les propriétés de signature depuis key.properties
val keyPropertiesFile = rootProject.file("../android/key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { input ->
        keyProperties.load(input)
    }
}

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

fun localProperties(): Properties {
    val properties = Properties()
    val localPropertiesFile = project.rootProject.file("android/local.properties")
    if (localPropertiesFile.exists()) {
        properties.load(localPropertiesFile.reader())
    }
    return properties
}

val localProps = localProperties()
// val localFlutterVersionCode = localProps.getProperty("flutter.versionCode") // Généralement géré par Flutter
// val localFlutterVersionName = localProps.getProperty("flutter.versionName") // Généralement géré par Flutter

android {
    namespace = "org.stanworld.colorsnotes"
    compileSdk = 35 // Ou flutter.compileSdkVersion si défini par le plugin Flutter
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        applicationId = "org.stanworld.colorsnotes"
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode // Géré par Flutter via pubspec.yaml
        versionName = flutter.versionName // Géré par Flutter via pubspec.yaml
        multiDexEnabled = true
    }

    signingConfigs {
        getByName("debug") {
            // Configuration par défaut pour le débogage
        }
        create("release") {
            if (keyProperties.getProperty("storeFile") != null &&
                keyProperties.getProperty("storePassword") != null &&
                keyProperties.getProperty("keyAlias") != null &&
                keyProperties.getProperty("keyPassword") != null) {

                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            } else {
                // Il est préférable de laisser Gradle échouer ici si les propriétés sont manquantes pour un build release.
                // Vous pouvez ajouter un logger.warn si vous le souhaitez, mais l'échec est souvent le comportement attendu.
                println(">>> AVERTISSEMENT: Propriétés de signature MANQUANTES dans key.properties pour la configuration 'release'. Le build pourrait échouer ou ne pas être signé.")
            }
        }
    }

    buildTypes {
        release {
            // minifyEnabled = true
            // shrinkResources = true
            // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("release")
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.13.0"))
    implementation("com.google.firebase:firebase-analytics-ktx")
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-firestore-ktx")
    // implementation("com.google.firebase:firebase-appcheck-playintegrity")

    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:2.1.0") // Assurez-vous que cette version ou une version compatible est utilisée
    implementation("androidx.multidex:multidex:2.0.1")
}

flutter {
    source = "../.."
}
