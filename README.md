# CiFi Tech — Application mobile multi-plateforme

Coque mobile native autour d'un site web, pour **Android**, **iOS** et
**HarmonyOS NEXT**, produite depuis une configuration unique.

> **CiFi** — Centrale d'Innovation et de Formation en Informatique.
> Societe SaaS, N'Djamena, Republique du Tchad.
> Branche technologique : **CiFi Tech**.


---

## Livrables

| Fichier | Plateforme | Machine requise |
|---        |---       |---             |
| `.apk` / `.aab` | Android | Windows, Mac, Linux |
| `.ipa` | iOS | **Mac uniquement** (contrainte Apple) |
| `.hap` | HarmonyOS NEXT | Windows, Mac, Linux + DevEco Studio |

---

## Pas une simple webview

Les boutiques refusent les coques web sans valeur ajoutee. Cette
application apporte ce qu'un navigateur mobile ne sait pas faire :

- **Notifications push** et **notifications declenchees par zone geographique**
- **Mode hors ligne** : archivage et relecture des pages visitees
- **Acces materiel** : appareil photo, micro, galerie, fichiers, scanner QR, vibration
- **Indicateurs natifs** : splash screen de marque, barre de progression reelle
- **Widget d'ecran d'accueil** (Android App Widget, iOS WidgetKit)
- **Partage systeme**, liens profonds, geste retour sur l'historique du site
- **Passerelle JavaScript** `window.CiFi` : le site pilote le materiel

---

## Reutilisable : un fichier, une application

Pour produire l'application d'un autre site, on modifie **un seul fichier**
et **un seul dossier**, puis on lance **un seul script**.

```
configuration/cifi_parametres.json   adresse, nom, identifiants, couleurs
marque/                              logo.png, logo_splash.png, logo_notification.png
```

```powershell
powershell -File scripts\appliquer_configuration.ps1
```

La configuration est propagee vers les trois projets natifs : manifeste
Android, Info.plist iOS, module.json5 HarmonyOS, icones, splash screen.
Aucune ligne de code a toucher.

---

## Demarrage rapide

### Windows

```powershell
cd C:\projets_codes\web_view_android_ios_harmonyos
powershell -ExecutionPolicy Bypass -File scripts\installer_environnement.ps1
# fermer puis rouvrir le terminal
powershell -ExecutionPolicy Bypass -File scripts\initialiser_projet.ps1
powershell -ExecutionPolicy Bypass -File scripts\compiler_android.ps1
```

### Mac / Linux

```bash
chmod +x scripts/*.sh
./scripts/installer_environnement.sh
source ~/.zshrc           # ou ~/.bashrc
./scripts/initialiser_projet.sh
./scripts/compiler_android.sh
./scripts/compiler_ios.sh          # Mac uniquement
./scripts/compiler_harmonyos.sh
```

---

## Architecture

```
web_view_android_ios_harmonyos/
├─ configuration/        source unique de verite (JSON)
├─ marque/               logos
├─ scripts/              installation, configuration, compilation
├─ cifi_application/     Flutter — Android + iOS (Dart)
├─ cifi_harmonyos/       ArkTS natif — HarmonyOS NEXT (.hap)
├─ plateforme_android/   fichiers natifs Android recopies a la generation
├─ plateforme_ios/       fichiers natifs iOS recopies a la generation
├─ livrables/            sorties .apk / .aab / .ipa / .hap
└─ docs/                 documentation
```

**Choix d'architecture.** Android et iOS partagent 100 % du code metier
en Dart. HarmonyOS NEXT passe par un module ArkTS natif plutot que par
le fork `flutter_flutter` d'OpenHarmony : ce fork retarde sur Flutter
stable et casse regulierement. Le module ArkTS atteint la parite
fonctionnelle (webview ArkWeb, hors ligne, notifications, zones
geographiques, passerelle JavaScript identique) et compile de maniere
fiable. Le fork reste installe en option par le script d'environnement.

---

## Documentation

| Fichier | Contenu |
|---|---|
| [docs/00_lire_en_premier.md](docs/00_lire_en_premier.md) | vue d'ensemble, par ou commencer |
| [docs/01_installation_windows.md](docs/01_installation_windows.md) | installation Windows |
| [docs/02_installation_mac_linux.md](docs/02_installation_mac_linux.md) | installation Mac et Linux |
| [docs/03_personnalisation.md](docs/03_personnalisation.md) | **changer le site, le nom, le logo, les couleurs** |
| [docs/04_compilation.md](docs/04_compilation.md) | produire et signer les livrables |
| [docs/05_fonctionnalites.md](docs/05_fonctionnalites.md) | fonctions natives et API `window.CiFi` |
| [docs/06_depannage.md](docs/06_depannage.md) | resolution des erreurs courantes |

---

## Securite

Cles de signature, `google-services.json`, `GoogleService-Info.plist` et
`agconnect-services.json` sont exclus du depot par `.gitignore`.
Le magasin de cles Android est irremplacable : conservez-en deux
sauvegardes hors de l'ordinateur.

---

## Licence

Voir [LICENSE](LICENSE).
