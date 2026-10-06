# Installation sur Windows

Cette page installe tous les outils necessaires sur votre ordinateur.
Comptez **1 a 3 heures** selon votre connexion. La plupart du temps,
c'est le telechargement qui est long.

---

## 1. Avant de commencer

Verifiez trois choses.

### Place sur le disque

Il faut **au moins 30 Go libres** sur `C:`.
Pour verifier, ouvrez l'Explorateur de fichiers et regardez `Ce PC`.

> Votre disque `C:` a actuellement environ 36 Go libres.
> C'est juste suffisant. Si vous pouvez liberer de la place avant, faites-le.

### Version de Windows

Windows 10 ou Windows 11. Verifiez avec la touche Windows + R, tapez
`winver`, puis Entree.

### Droits administrateur

Certaines installations en ont besoin.
Pour ouvrir un terminal administrateur :

1. Touche Windows
2. Tapez `powershell`
3. Clic droit sur **Windows PowerShell**
4. **Executer en tant qu'administrateur**

---

## 2. Lancer le script d'installation

Ouvrez PowerShell **en administrateur**, puis tapez ces deux lignes :

```powershell
cd C:\projets_codes\web_view_android_ios_harmonyos
powershell -ExecutionPolicy Bypass -File scripts\installer_environnement.ps1
```

Le script travaille tout seul. Il affiche ou il en est.
Laissez-le finir sans fermer la fenetre.

### Ce qu'il installe

| Outil | A quoi ca sert | Ou ca s'installe |
|---|---|---|
| **Git** | recuperer du code | installation standard |
| **JDK 17 (Temurin)** | compiler pour Android | `C:\Program Files\Eclipse Adoptium\jdk-17...` |
| **Flutter** | le coeur du projet | `C:\outils_mobile\flutter` |
| **Android SDK** | compiler les `.apk` | `C:\outils_mobile\android_sdk` |
| **Android Studio** | editer et deboguer | installation standard |
| **Node.js** | outils annexes | installation standard |
| **firebase-tools** | notifications push | via npm |
| **Fork Flutter HarmonyOS** | option HarmonyOS | `C:\outils_mobile\harmonyos\flutter_flutter_ohos` |

### Les options du script

Si vous voulez aller plus vite ou economiser de la place :

```powershell
# Ne pas installer Android Studio (vous gardez les outils en ligne de commande)
powershell -File scripts\installer_environnement.ps1 -SauterAndroidStudio

# Ne pas telecharger le fork Flutter HarmonyOS (gagne ~2 Go)
powershell -File scripts\installer_environnement.ps1 -SauterOhos

# Mettre les outils ailleurs que C:\outils_mobile
powershell -File scripts\installer_environnement.ps1 -RacineOutils "D:\outils_mobile"
```

---

## 3. TRES IMPORTANT : fermer et rouvrir le terminal

Le script cree des **variables d'environnement**.
Windows ne les lit qu'au demarrage d'un terminal.

**Fermez completement la fenetre PowerShell. Rouvrez-en une neuve.**

Si vous sautez cette etape, la suite ne marchera pas.

### Verifier que c'est bon

Dans le **nouveau** terminal :

```powershell
flutter --version
java -version
adb version
```

Les trois doivent repondre. Si l'une dit "n'est pas reconnu",
allez voir `docs\06_depannage.md`, section "Commande non reconnue".

---

## 4. Installer DevEco Studio pour HarmonyOS

Cette etape est **manuelle**. Huawei exige un compte pour telecharger.

1. Creez un compte gratuit sur <https://developer.huawei.com>
2. Allez sur <https://developer.huawei.com/consumer/en/deveco-studio>
3. Telechargez la version Windows
4. Installez-la. Acceptez le dossier propose par defaut :
   ```
   C:\Program Files\Huawei\DevEco Studio
   ```
5. Ouvrez DevEco une premiere fois. Il telecharge son SDK tout seul
   (environ 20 minutes).
6. **Relancez le script d'installation** :
   ```powershell
   powershell -File scripts\installer_environnement.ps1
   ```
   Cette fois il trouve DevEco, et il pose les variables `DEVECO_SDK_HOME`
   et `HOS_SDK_HOME` toutes seules.

> Vous pouvez sauter cette etape si vous ne visez pas HarmonyOS
> pour l'instant. Android et iPhone fonctionneront quand meme.

---

## 5. Generer le projet

Toujours dans un terminal neuf :

```powershell
cd C:\projets_codes\web_view_android_ios_harmonyos
powershell -ExecutionPolicy Bypass -File scripts\initialiser_projet.ps1
```

Ce script :

1. cree les dossiers `android\` et `ios\` dans `cifi_application\`
2. y recopie les reglages du projet (permissions, widget, signature)
3. telecharge les bibliotheques Dart
4. applique votre configuration
5. fabrique les icones et l'ecran de demarrage

A la fin il affiche **PROJET PRET**.

---

## 6. Premier essai

Branchez un telephone Android en USB, avec le **debogage USB** active.

> Pour activer le debogage USB : Reglages > A propos du telephone >
> appuyez 7 fois sur "Numero de build" > revenez > Options pour les
> developpeurs > Debogage USB.

Puis :

```powershell
cd C:\projets_codes\web_view_android_ios_harmonyos\cifi_application
flutter devices
flutter run
```

L'application s'installe et se lance sur le telephone.

Pas de telephone sous la main ? Ouvrez Android Studio, menu
**Tools > Device Manager**, creez un telephone virtuel, demarrez-le,
puis relancez `flutter run`.

---

## 7. Et apres

- Pour mettre **votre** site et **votre** logo :
  `docs\03_personnalisation.md`
- Pour fabriquer les fichiers a distribuer :
  `docs\04_compilation.md`

---

## 8. Ou retrouver le journal d'installation

Le script ecrit tout ce qu'il fait dans :

```
C:\Users\<votre_nom>\AppData\Local\Temp\cifi_installation.log
```

Raccourci pour l'ouvrir :

```powershell
notepad $env:TEMP\cifi_installation.log
```

Si quelque chose a rate, ce fichier dit quoi.
