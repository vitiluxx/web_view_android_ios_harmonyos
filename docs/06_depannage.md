# Depannage : quand ca ne marche pas

Cherchez votre message d'erreur dans cette page. Les solutions sont
classees de la plus frequente a la plus rare.

---

## 1. "flutter n'est pas reconnu" / "command not found: flutter"

**Cause la plus frequente :** vous n'avez pas ferme et rouvert le terminal
apres l'installation.

**Solution :**

1. Fermez **completement** la fenetre du terminal
2. Ouvrez-en une nouvelle
3. Reessayez

**Si ca ne suffit pas**, verifiez que le chemin est bien dans le PATH :

```powershell
# Windows
[Environment]::GetEnvironmentVariable("Path", "User") -split ";" | Select-String "flutter"
```

```bash
# Mac / Linux
echo $PATH | tr ':' '\n' | grep flutter
```

Rien ne sort ? Ajoutez-le a la main :

```powershell
# Windows
$chemin = [Environment]::GetEnvironmentVariable("Path", "User")
[Environment]::SetEnvironmentVariable("Path", "$chemin;C:\outils_mobile\flutter\bin", "User")
```

```bash
# Mac / Linux
echo 'export PATH="$PATH:$HOME/outils_mobile/flutter/bin"' >> ~/.zshrc
source ~/.zshrc
```

Puis rouvrez le terminal.

---

## 2. `flutter doctor` affiche des croix rouges

### "Android licenses not accepted"

```powershell
flutter doctor --android-licenses
```

Tapez `y` puis Entree a chaque question. Il y en a une dizaine.

### "Unable to locate Android SDK"

```powershell
flutter config --android-sdk C:\outils_mobile\android_sdk
```

### "cmdline-tools component is missing"

```powershell
sdkmanager --install "cmdline-tools;latest"
```

Si `sdkmanager` n'est pas reconnu, le chemin complet est :

```
C:\outils_mobile\android_sdk\cmdline-tools\latest\bin\sdkmanager.bat
```

### "Xcode not installed" (sur Mac)

Normal si vous ne visez pas l'iPhone. Sinon, installez Xcode depuis
le Mac App Store.

### "Chrome / Visual Studio / Linux toolchain"

Sans importance. Ce sont les cibles web et bureau, dont ce projet ne
se sert pas.

---

## 3. "Could not resolve dependencies" lors de `flutter pub get`

Les versions des bibliotheques ne s'accordent pas avec votre version de
Flutter.

**Solution 1 — laisser Flutter trancher :**

```powershell
cd C:\projets_codes\web_view_android_ios_harmonyos\cifi_application
flutter pub upgrade --major-versions
```

**Solution 2 — repartir propre :**

```powershell
cd C:\projets_codes\web_view_android_ios_harmonyos\cifi_application
del pubspec.lock
flutter clean
flutter pub get
```

**Solution 3 — mettre Flutter a jour :**

```powershell
flutter upgrade
```

---

## 4. L'application s'ouvre sur un ecran blanc

### Verifiez l'adresse

Ouvrez :

```
C:\projets_codes\web_view_android_ios_harmonyos\configuration\cifi_parametres.json
```

- `url_accueil` commence bien par **`https://`** ?
- Pas de faute de frappe ?
- Le site repond bien dans un navigateur ordinaire ?

### Votre site est en `http://` et pas en `https://`

Android et iOS bloquent le trafic non chiffre. **La bonne solution est
de passer votre site en HTTPS** (Let's Encrypt est gratuit).

En depannage temporaire, pour tester seulement :

Fichier `C:\projets_codes\web_view_android_ios_harmonyos\cifi_application\android\app\src\main\res\xml\configuration_securite_reseau.xml`,
decommentez le bloc `domain-config` et mettez votre domaine.

> **Ne publiez jamais** une application avec ce reglage actif.

### Lire les messages de l'application

```powershell
cd C:\projets_codes\web_view_android_ios_harmonyos\cifi_application
flutter logs
```

Les lignes commencant par `[CiFi]` viennent de l'application.

---

## 5. "Execution failed for task ':app:...'" pendant la compilation Android

### Essayez d'abord le nettoyage complet

```powershell
cd C:\projets_codes\web_view_android_ios_harmonyos\cifi_application
flutter clean
cd android
.\gradlew clean
cd ..
flutter pub get
flutter build apk --release
```

### "Could not find com.google.gms:google-services"

Le greffon Firebase est declare mais le fichier manque.

Soit vous mettez Firebase en place (`docs\05_fonctionnalites.md`,
section 4), soit vous enlevez `google-services.json` du dossier :

```
C:\projets_codes\web_view_android_ios_harmonyos\cifi_application\android\app\
```

Le fichier `build.gradle.kts` n'active le greffon que si ce fichier existe.

### "Unsupported class file major version" ou "Java version"

Mauvaise version de Java. Il faut le **17**.

```powershell
java -version
```

Si ce n'est pas 17 :

```powershell
[Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files\Eclipse Adoptium\jdk-17.0.13.11-hotspot", "User")
```

Adaptez le numero de version au dossier reel, puis rouvrez le terminal.

### "OutOfMemoryError" ou compilation tres lente

Ouvrez :

```
C:\projets_codes\web_view_android_ios_harmonyos\cifi_application\android\gradle.properties
```

Ajoutez ou modifiez :

```properties
org.gradle.jvmargs=-Xmx4096M
org.gradle.daemon=true
org.gradle.parallel=true
```

---

## 6. Le logo ou le nom n'ont pas change

**Vous avez oublie d'appliquer la configuration.**

```powershell
cd C:\projets_codes\web_view_android_ios_harmonyos
powershell -File scripts\appliquer_configuration.ps1
```

**Toujours l'ancien logo apres ca ?** Android garde les icones en cache.
Desinstallez l'application du telephone, puis reinstallez-la.

**Verifiez que vos images sont bien au bon endroit :**

```powershell
dir C:\projets_codes\web_view_android_ios_harmonyos\marque\
```

Les trois fichiers doivent s'appeler **exactement** :
`logo.png`, `logo_splash.png`, `logo_notification.png`

---

## 7. Le script dit "motif non trouve dans ..."

Le fichier a modifier a ete change a la main, et le script ne reconnait
plus la ligne a remplacer.

**Solution :** regenerez le fichier d'origine.

```powershell
cd C:\projets_codes\web_view_android_ios_harmonyos
powershell -File scripts\initialiser_projet.ps1
```

Les fichiers des dossiers `plateforme_android\` et `plateforme_ios\`
sont recopies par-dessus ceux du projet.

**Un avertissement "fichier absent" est normal** tant que
`initialiser_projet` n'a pas ete lance.

---

## 8. HarmonyOS : "hvigorw introuvable"

DevEco Studio n'est pas installe, ou le script ne le trouve pas.

**Verifiez qu'il est bien la :**

```powershell
dir "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\"
```

**S'il est installe ailleurs**, compilez depuis DevEco plutot que par le
script :

1. Ouvrez DevEco Studio
2. **File > Open**
3. Dossier `C:\projets_codes\web_view_android_ios_harmonyos\cifi_harmonyos`
4. **Build > Build Hap(s)/APP(s) > Build Hap(s)**

---

## 9. HarmonyOS : "Cannot find module '@kit.ArkWeb'"

Le SDK HarmonyOS n'est pas installe ou pas trouve.

1. Ouvrez DevEco Studio
2. **File > Settings > SDK**
3. Installez l'API **12** (HarmonyOS 5.0.0)
4. Relancez :
   ```powershell
   powershell -File scripts\installer_environnement.ps1
   ```
   Il posera `DEVECO_SDK_HOME`.

---

## 10. iPhone : "No profiles for 'td.cifi...' were found"

Votre compte Apple ne connait pas encore cet identifiant.

1. Ouvrez `cifi_application/ios/Runner.xcworkspace` dans Xcode
2. Cible **Runner** > **Signing & Capabilities**
3. Cochez **Automatically manage signing**
4. Choisissez votre **Team**
5. Xcode cree le profil tout seul

**Si le Bundle Identifier est deja pris**, changez `nom_paquet_ios` dans
votre configuration pour quelque chose d'unique, puis relancez
`appliquer_configuration`.

---

## 11. iPhone : "CocoaPods not installed" ou erreurs de pods

```bash
cd cifi_application/ios
pod deintegrate
pod install --repo-update
```

Si `pod` n'existe pas :

```bash
brew install cocoapods
```

---

## 12. Les notifications n'arrivent pas

### Verifiez dans l'ordre

1. **L'utilisateur a-t-il accepte ?**
   Reglages du telephone > Applications > votre application >
   Notifications.

2. **Firebase est-il configure ?**
   Le fichier doit exister :
   ```
   C:\projets_codes\web_view_android_ios_harmonyos\cifi_application\android\app\google-services.json
   ```
   Sinon, voir `docs\05_fonctionnalites.md` section 4.

3. **Lisez les journaux :**
   ```powershell
   flutter logs
   ```
   Cherchez la ligne `[CiFi][information] jeton push : ...`
   Si elle dit "indisponible", Firebase n'est pas joignable.

4. **Sur iPhone**, la cle APNs `.p8` est-elle bien deposee dans Firebase ?
   Sans elle, aucune notification n'arrive, jamais.

5. **Android 13 et plus** demande une autorisation explicite.
   L'application la demande au demarrage, mais l'utilisateur peut refuser.

---

## 13. La geolocalisation ne declenche rien

- `"notifications_geolocalisees": true` dans la configuration ?
- La liste `geofences` n'est pas vide ?
- L'utilisateur a accepte la localisation ?
- Le service de localisation du telephone est allume ?
- Le rayon est-il raisonnable ? En dessous de 100 metres, le GPS n'est
  pas assez precis pour declencher de maniere fiable.
- Pour un declenchement application fermee, il faut l'autorisation
  **"Toujours"**, pas "Pendant l'utilisation".

Pour tester : mettez une zone autour de votre position actuelle avec un
rayon de 1000 metres, puis relancez l'application.

---

## 14. Le mode hors ligne ne garde rien

- `"mode_hors_ligne": true` ?
- Avez-vous visite les pages **en etant connecte** avant de couper ?
  L'application n'enregistre que ce qu'elle a reussi a charger.
- `duree_cache_jours` n'est pas a `0` ?

Pour verifier ce qui est enregistre : bouton rond en bas a droite >
**Pages enregistrees**.

---

## 15. Rien ne marche, je repars de zero

```powershell
cd C:\projets_codes\web_view_android_ios_harmonyos

# Effacer les projets generes (votre code et votre configuration restent)
rmdir /s /q cifi_application\android
rmdir /s /q cifi_application\ios
rmdir /s /q cifi_application\build
rmdir /s /q cifi_application\.dart_tool

# Tout regenerer
powershell -File scripts\initialiser_projet.ps1
```

Vos fichiers suivants ne sont **jamais** touches :

- `configuration\cifi_parametres.json`
- `marque\`
- `cifi_application\lib\`
- `cifi_application\assets\`
- `cifi_harmonyos\`

---

## 16. Problemes rencontres lors de la premiere compilation

Cette section liste des blocages reels, rencontres en compilant ce
projet pour de bon. Chacun a une cause precise et une solution verifiee.

### 16.1 "kotlinOptions is deprecated" : la compilation s'arrete

**Message :** `Script compilation errors ... kotlinOptions ... is deprecated`

**Cause :** depuis AGP 9 et Kotlin 2, le bloc `kotlinOptions { }` a
l'interieur de `android { }` n'est plus un avertissement mais une
**erreur**. Le reglage a demenage a la racine du fichier.

**Solution :** dans
`cifi_application/android/app/build.gradle.kts`, la forme correcte est

```kotlin
kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}
```

C'est deja le cas dans ce projet. Si vous repartez d'un `flutter create`
plus ancien, pensez a verifier ce point.

### 16.2 "NDK not configured" ou "did not have a source.properties file"

**Cause :** le NDK Android est **obligatoire** pour ce projet, meme si
nous n'ecrivons aucun code C++ : `path_provider_android` depend de `jni`,
qui le reclame.

**Si le dossier existe mais est incomplet** (telechargement interrompu),
Gradle refuse de demarrer. Supprimez-le :

```powershell
Remove-Item -LiteralPath "C:/outils_mobile/android_sdk/ndk" -Recurse -Force
```

**Pour l'installer :**

```powershell
# Methode normale
sdkmanager --install "ndk;28.2.13676358"

# Si la connexion coupe : telechargez l'archive a la main sur
# https://developer.android.com/ndk/downloads (version r28c, ~713 Mo)
# puis laissez-la dans Telechargements et lancez
powershell -File scripts\installer_ndk_manuel.ps1
```

### 16.3 "Failed to find target with hash string 'android-37'"

**Cause :** un greffon compile contre l'API 37. Or Android publie
desormais cette API sous le nom `android-37.0`, avec un numero mineur,
et AGP 9.1 ne sait pas encore faire le rapprochement : il cherche
`android-37` tout court.

**Solution retenue dans ce projet :** `permission_handler` est fige en
`^12.0.0`, dont la partie Android vise l'API 35. La raison est ecrite en
commentaire dans `cifi_application/pubspec.yaml`.

Reessayez de monter cette contrainte quand AGP saura lire les niveaux
d'API a version mineure.

### 16.4 "requires desugar_jdk_libs version to be X or above"

**Cause :** `flutter_local_notifications` exige une version minimale de
la bibliotheque de retro-compatibilite.

**Solution :** montez le numero dans
`plateforme_android/app/build.gradle.kts`, puis relancez
`scripts/initialiser_projet.ps1` :

```kotlin
coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
```

### 16.5 "compiled against android-34" alors qu'il en faut 36

**Cause :** un greffon trop ancien. Ce n'est pas au `compileSdk` de
l'application qu'il faut toucher, mais a la version du greffon.

**Solution :** remettez les dependances a jour.

```powershell
cd C:\projets_codes\web_view_android_ios_harmonyos\cifi_application
flutter pub upgrade --major-versions
flutter analyze
```

`flutter analyze` vous dira exactement ce que la montee de version a
casse dans le code. En general quelques appels a renommer.

### 16.6 La compilation est tuee avant la fin

**Cause :** Gradle demande trop de memoire. Le gabarit Flutter reclame
`-Xmx8G`, une valeur pensee pour des machines tres bien dotees.

**Solution :** elle est deja appliquee dans ce projet, via
`plateforme_android/gradle.properties` :

```properties
org.gradle.jvmargs=-Xmx3G -XX:MaxMetaspaceSize=1G
org.gradle.parallel=false
```

Si cela ne suffit pas, fermez ce qui consomme de la memoire. Un
navigateur avec beaucoup d'onglets prend facilement 2 Go, et WSL ou
Docker (processus `vmmem`) encore autant :

```powershell
wsl --shutdown
```

### 16.7 Avertissement sur le greffon Kotlin

**Message :** `Your app uses the following plugins that apply Kotlin
Gradle Plugin (KGP) ... Future versions of Flutter will fail to build`

**Ce n'est pas une erreur aujourd'hui.** Le reglage qui maintient
l'ancien comportement est dans
`cifi_application/android/gradle.properties` :

```properties
android.builtInKotlin=false
```

**Pour savoir ou vous en etes :**

```powershell
python scripts/auditer_greffons_kotlin.py
```

Le script lit `pubspec.lock`, inspecte chaque greffon et dit lesquels
sont en retard. Quand la liste est vide, il vous donne la marche a
suivre pour passer a `true`.

A la date de redaction, trois greffons etaient concernes
(`firebase_core`, `home_widget`, `mobile_scanner`) et **tous les trois
etaient deja a leur derniere version** : il n'y avait rien a mettre a
jour, seulement a attendre leur correction en amont.

### 16.8 Le numero de version des APK decoupes est bizarre

L'APK `arm64-v8a` affiche `versionCode=2001` alors que votre
configuration dit `1`. **C'est normal et voulu.**

Quand les APK sont decoupes par architecture, Flutter ajoute
automatiquement `1000 x numero_architecture` au `versionCode`, pour que
le Play Store puisse les distinguer et servir le bon fichier a chaque
telephone.

| Fichier | versionCode |
|---|---|
| `armeabi-v7a` | 1001 |
| `arm64-v8a` | 2001 |
| `x86_64` | 4001 |

Ne corrigez rien. Si vous publiez le `.aab`, la question ne se pose meme
pas : le Play Store fait le decoupage lui-meme.

---

## 17. Les journaux : ou regarder

| Quoi | Ou |
|---|---|
| installation Windows | `%TEMP%\cifi_installation.log` |
| installation Mac/Linux | `/tmp/cifi_installation.log` |
| application en marche | `flutter logs` |
| Android, detail | `adb logcat \| findstr CiFi` |
| iPhone, detail | Xcode > Window > Devices and Simulators > Console |
| HarmonyOS, detail | DevEco Studio > onglet Log, filtre `CiFi` |

---

## 18. Verifier que tout est en place

```powershell
# Les outils
flutter doctor -v

# Les variables d'environnement
echo $env:JAVA_HOME
echo $env:ANDROID_HOME
echo $env:DEVECO_SDK_HOME

# Le projet
dir C:\projets_codes\web_view_android_ios_harmonyos\cifi_application\android
dir C:\projets_codes\web_view_android_ios_harmonyos\cifi_application\assets\configuration

# La configuration est-elle un JSON valide ?
python -c "import json;json.load(open(r'C:\projets_codes\web_view_android_ios_harmonyos\configuration\cifi_parametres.json'));print('JSON valide')"
```

Cette derniere commande est utile : une virgule en trop dans le fichier
de configuration empeche toute l'application de demarrer.
