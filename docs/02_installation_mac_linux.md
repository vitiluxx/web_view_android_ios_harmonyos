# Installation sur Mac ou Linux

Le Mac est la seule machine qui peut tout faire : Android, iPhone et
HarmonyOS. Linux fait Android et HarmonyOS, pas iPhone.

---

## 1. Avant de commencer

| | Mac | Linux |
|---|---|---|
| Android `.apk` / `.aab` | oui | oui |
| iPhone `.ipa` | **oui** | non, impossible |
| HarmonyOS `.hap` | oui | oui |
| Place disque requise | 40 Go (avec Xcode) | 30 Go |

---

## 2. Lancer le script d'installation

Ouvrez le Terminal, puis :

```bash
cd /chemin/vers/web_view_android_ios_harmonyos
chmod +x scripts/*.sh
./scripts/installer_environnement.sh
```

### Options

```bash
# Mettre les outils ailleurs que ~/outils_mobile
./scripts/installer_environnement.sh --racine-outils /opt/outils_mobile

# Ne pas telecharger le fork Flutter HarmonyOS (gagne ~2 Go)
./scripts/installer_environnement.sh --sauter-ohos
```

### Ce qu'il installe

| Outil | Ou |
|---|---|
| Homebrew (Mac seulement) | `/opt/homebrew` |
| Git | via brew ou apt |
| JDK 17 Temurin | via brew ou apt |
| Flutter | `~/outils_mobile/flutter` |
| Android SDK | `~/outils_mobile/android_sdk` |
| CocoaPods (Mac) | via brew |
| Fork Flutter HarmonyOS | `~/outils_mobile/harmonyos/flutter_flutter_ohos` |

---

## 3. Recharger le shell

Le script ajoute des lignes dans `~/.zshrc` (Mac) ou `~/.bashrc` (Linux).
Elles ne sont lues qu'au prochain demarrage du terminal.

```bash
source ~/.zshrc      # sur Mac
source ~/.bashrc     # sur Linux
```

Verifiez :

```bash
flutter --version
java -version
adb version
```

---

## 4. Installer Xcode (Mac seulement, pour iPhone)

1. Ouvrez le **Mac App Store**
2. Cherchez **Xcode**, installez-le (environ 12 Go, c'est long)
3. Ouvrez Xcode une premiere fois, acceptez la licence
4. Dans le Terminal :
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   sudo xcodebuild -license accept
   ```
5. Relancez le script d'installation : il verra Xcode et finira le reglage.

### Compte developpeur Apple

Pour installer sur un vrai iPhone et pour publier sur l'App Store,
il faut un compte Apple Developer payant (99 USD par an) :
<https://developer.apple.com/programs/>

Pour tester sur le **simulateur** uniquement, un compte Apple gratuit suffit.

---

## 5. Installer DevEco Studio pour HarmonyOS

Etape manuelle. Huawei exige un compte pour telecharger.

1. Compte gratuit sur <https://developer.huawei.com>
2. Telechargez DevEco Studio : <https://developer.huawei.com/consumer/en/deveco-studio>
3. Installez-le :
   - Mac : glissez-le dans `/Applications/DevEco-Studio.app`
   - Linux : decompressez dans `~/DevEco-Studio` ou `/opt/deveco-studio`
4. Ouvrez-le une fois, laissez-le telecharger son SDK
5. Relancez :
   ```bash
   ./scripts/installer_environnement.sh
   ```
   Il trouvera DevEco et posera `DEVECO_SDK_HOME` tout seul.

---

## 6. Generer le projet

```bash
./scripts/initialiser_projet.sh
```

Sur Mac, le script cree `android/` **et** `ios/`, et lance `pod install`.
Sur Linux, il cree seulement `android/`.

---

## 7. Premier essai

```bash
cd cifi_application
flutter devices
flutter run
```

Pour lancer sur le simulateur iPhone (Mac uniquement) :

```bash
open -a Simulator
flutter run
```

---

## 8. Compiler sans Mac : les solutions

Vous etes sur Windows ou Linux et il vous faut un `.ipa` ?
Trois chemins, du plus simple au plus technique.

### Codemagic (le plus simple)

<https://codemagic.io> compile Flutter pour iOS sans Mac.
Gratuit jusqu'a 500 minutes par mois.
Vous connectez votre depot Git, vous donnez votre certificat Apple,
il vous rend le `.ipa`.

### GitHub Actions

Si votre code est sur GitHub, ajoutez un fichier
`.github/workflows/ios.yml` qui utilise `runs-on: macos-latest`.
GitHub vous prete une machine Mac. Gratuit pour les depots publics.

### Louer un Mac

<https://www.macstadium.com> ou <https://www.macincloud.com>.
Environ 25 a 60 USD par mois. Vous vous connectez a distance et vous
travaillez comme sur un Mac local.

---

## 9. Journal d'installation

```bash
cat /tmp/cifi_installation.log
```

---

## 10. Et apres

- Mettre votre site et votre logo : `docs/03_personnalisation.md`
- Fabriquer les fichiers : `docs/04_compilation.md`
