// ---------------------------------------------------------------------------
// Compilation Android de l'application CiFi.
//
// Ce fichier remplace celui genere par "flutter create". Il est recopie par
// scripts/initialiser_projet.ps1 vers :
//     cifi_application/android/app/build.gradle.kts
//
// Il suit le format attendu par AGP 9 et Kotlin 2.x :
//   - le bloc  kotlin { compilerOptions { } }  est a la RACINE du fichier.
//     Surtout pas  kotlinOptions { }  a l'interieur de  android { }  :
//     cette ancienne forme fait echouer la compilation, pas seulement un
//     avertissement.
//
// Les versions du SDK viennent de Flutter (flutter.compileSdkVersion et
// consorts) : elles suivent les mises a jour de Flutter sans que personne
// ait a y penser.
//
// La version de l'application vient de pubspec.yaml, lui-meme reecrit par
// scripts/appliquer_configuration.ps1 depuis
//     configuration/cifi_parametres.json
// Seul applicationId est inscrit ici, et ce meme script le reecrit.
//
// Signature de production : voir cles/cle.proprietes (modele fourni dans
// plateforme_android/cle.proprietes.modele) et docs/04_compilation.md
// ---------------------------------------------------------------------------

import java.util.Properties
import java.io.FileInputStream
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    // Le greffon Flutter doit etre applique APRES ceux d'Android et de Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

// --- lecture du fichier de signature, s'il existe
val proprietesSignature = Properties()
val fichierSignature = rootProject.file("cles/cle.proprietes")
val signatureDisponible = fichierSignature.exists()
if (signatureDisponible) {
    proprietesSignature.load(FileInputStream(fichierSignature))
}

// --- google-services n'est applique que si le fichier Firebase est present.
// Sans cette condition, toute compilation echouerait tant que les
// notifications push ne sont pas configurees.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    // Paquet du CODE Kotlin. Il reste FIXE : les classes du widget en
    // dependent. Ce n'est pas l'identifiant de l'application.
    namespace = "td.cifi.tech.cifi_navigateur"

    compileSdk = flutter.compileSdkVersion

    // ndkVersion volontairement absent : aucune bibliotheque de ce projet
    // ne compile de code natif C++. La declarer forcerait le telechargement
    // du NDK Android, soit 3 Go inutiles. Si un greffon ajoute un jour du
    // code natif, Gradle le reclamera : retablissez alors la ligne
    //     ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Requis par flutter_local_notifications sur les anciens Android.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // === REECRIT PAR appliquer_configuration (identite.nom_paquet_android)
        applicationId = "td.cifi.tech.navigateur"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        // Versions lues dans pubspec.yaml, donc dans cifi_parametres.json.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signatureDisponible) {
            create("release") {
                keyAlias = proprietesSignature.getProperty("alias_cle")
                keyPassword = proprietesSignature.getProperty("mot_de_passe_cle")
                storeFile = proprietesSignature.getProperty("chemin_magasin")
                    ?.let { rootProject.file(it) }
                storePassword = proprietesSignature.getProperty("mot_de_passe_magasin")
            }
        }
    }

    buildTypes {
        release {
            // Sans fichier de signature on retombe sur la cle de debogage :
            // la compilation reussit, mais l'APK n'est PAS publiable.
            signingConfig = if (signatureDisponible) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-regles.pro"
            )
        }

        debug {
            // PAS d'applicationIdSuffix ici : le greffon google-services
            // exige que l'applicationId figure dans google-services.json.
            // Un suffixe ferait echouer toute compilation de debogage des
            // que les notifications push sont configurees.
            versionNameSuffix = "-debogage"
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE*",
                "META-INF/NOTICE*"
            )
        }
    }
}

// Bloc a la RACINE du fichier : seule forme acceptee depuis Kotlin 2.x.
kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Seule dependance Android necessaire : elle apporte aux anciens
    // Android les API de date que flutter_local_notifications utilise.
    // multidex n'est PAS requis : il ne sert qu'en dessous de minSdk 21.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")
}
