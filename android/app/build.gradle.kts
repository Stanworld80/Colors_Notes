import java.util.Properties // Import nécessaire pour Properties

// Configuration pour lire les propriétés de signature depuis key.properties
val keyPropertiesFile = rootProject.file("../android/key.properties") // Chemin vers android/key.properties
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { input ->
        keyProperties.load(input)
        // Ligne de débogage (optionnelle, à supprimer après vérification) :
       // println(">>> DEBUG: Fichier key.properties trouvé. Valeur de storeFile: " + keyProperties.getProperty("storeFile"))
    }
} else {
    // Ligne de débogage (optionnelle, à supprimer après vérification) :
     //println(">>> DEBUG: Fichier key.properties NON TROUVÉ à l'emplacement attendu: " + keyPropertiesFile.absolutePath)
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration (selon votre version)
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android") // Utilisation de l'ID de plugin Kotlin de l'utilisateur
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Fonction pour lire local.properties
fun localProperties(): Properties {
    val properties = Properties()
    // Le fichier local.properties est généralement dans le dossier 'android' du projet Flutter.
    // rootProject fait référence à la racine du projet Flutter.
    val localPropertiesFile = project.rootProject.file("android/local.properties")
    if (localPropertiesFile.exists()) {
        properties.load(localPropertiesFile.reader())
        // println(">>> DEBUG: Fichier android/local.properties trouvé et chargé.")
    } else {
        // println(">>> DEBUG: Fichier android/local.properties NON TROUVÉ à " + localPropertiesFile.absolutePath)
    }
    return properties
}

// Lire les propriétés depuis local.properties en utilisant les noms de clés corrects
val localProps = localProperties()
val localFlutterVersionCode = localProps.getProperty("flutter.versionCode")
val localFlutterVersionName = localProps.getProperty("flutter.versionName")


android {
    namespace = "org.stanworld.colorsnotes" // Votre namespace
    compileSdk = 35 // SDK de compilation, peut aussi être flutter.compileSdkVersion si défini par le plugin
    ndkVersion = "27.0.12077973" // NDK Version de l'utilisateur

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11 // Version Java de l'utilisateur
        targetCompatibility = JavaVersion.VERSION_11 // Version Java de l'utilisateur
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString() // Cible JVM Kotlin de l'utilisateur
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    // defaultConfig DOIT être un enfant direct de android { ... }
    defaultConfig {
        applicationId = "org.stanworld.colorsnotes"
        minSdk = 23 // minSdk de l'utilisateur
        targetSdk = 34 // targetSdk, peut aussi être flutter.targetSdkVersion
        // Utiliser les valeurs lues depuis local.properties comme fallback si les variables d'environnement ne sont pas définies
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        getByName("debug") {
            // La configuration de débogage est généralement gérée automatiquement.
        }
        create("release") {
            // Configuration pour la signature de release
            if (keyProperties.getProperty("storeFile") != null &&
                keyProperties.getProperty("storePassword") != null &&
                keyProperties.getProperty("keyAlias") != null &&
                keyProperties.getProperty("keyPassword") != null) {

                // Ligne de débogage (optionnelle) :
                // println(">>> DEBUG: Assignation des propriétés de signature pour 'release'. storeFile: " + keyProperties.getProperty("storeFile"))

                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            } else {
                // Ligne de débogage (optionnelle) :
             //    println(">>> DEBUG: Propriétés de signature MANQUANTES dans key.properties pour la configuration 'release'.")
              //   println(">>> DEBUG: storeFile est: " + keyProperties.getProperty("storeFile"))
          //       Laisser Gradle échouer si les propriétés sont manquantes pour une release est une bonne pratique.
            }
        }
    }

    buildTypes {
        release {
            // TODO: Ajoutez vos propres configurations pour la release si nécessaire.
            // Par exemple, activez la minification et la réduction des ressources.
            // minifyEnabled = true
            // shrinkResources = true
            // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")

            // Utilisez la configuration de signature "release" que nous venons de définir.
            signingConfig = signingConfigs.getByName("release")
        }
        debug { // Bloc debug explicite, ce qui est bien.
            signingConfig = signingConfigs.getByName("debug")
            // Vous pouvez ajouter d'autres configurations spécifiques au debug ici si besoin.
        }
    }
}

dependencies {
    // Vos dépendances Firebase et autres
    implementation(platform("com.google.firebase:firebase-bom:33.13.0")) // BOM Firebase
    implementation("com.google.firebase:firebase-analytics-ktx") // Utiliser -ktx pour Kotlin
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-firestore-ktx")
    // implementation("com.google.firebase:firebase-appcheck-playintegrity") // Exemple si vous utilisez AppCheck

    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:2.1.0") // Assurez-vous que la version est compatible
    implementation("androidx.multidex:multidex:2.0.1")

    // Ajoutez d'autres dépendances ici si nécessaire
    // Par exemple, pour les coroutines Kotlin si vous les utilisez dans le code natif Android :
    // implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    // implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}

flutter {
    source = "../.."
}
