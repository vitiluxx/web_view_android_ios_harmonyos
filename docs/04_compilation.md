# Compilation : fabriquer les fichiers a distribuer

Cette page explique comment produire les fichiers que vous enverrez aux
boutiques ou directement a vos utilisateurs.

---

## 1. Les quatre fichiers possibles

| Fichier | Pour quoi | Fabrique sur |
|---|---|---|
| `.apk` | installation directe sur un Android, hors boutique | Windows, Mac, Linux |
| `.aab` | envoi sur le **Google Play Store** | Windows, Mac, Linux |
| `.ipa` | envoi sur l'**App Store** Apple | **Mac uniquement** |
| `.hap` | envoi sur **Huawei AppGallery** | Windows, Mac, Linux (avec DevEco) |

Tout arrive dans :

```
C:\projets_codes\web_view_android_ios_harmonyos\livrables\
```

---

## 2. Android

### 2.1 Fabriquer un `.apk` de test

C'est le plus rapide. Pas besoin de cle de signature.

```powershell
cd C:\projets_codes\web_view_android_ios_harmonyos
powershell -ExecutionPolicy Bypass -File scripts\compiler_android.ps1
```

Sur Mac ou Linux :

```bash
./scripts/compiler_android.sh
```

Resultat, avec les tailles reellement mesurees sur ce projet :

| Fichier | Taille | Pour qui |
|---|---|---|
| `cifi_tech_1.0.0_arm64-v8a.apk` | 25,7 Mo | tous les telephones recents |
| `cifi_tech_1.0.0_armeabi-v7a.apk` | 21,5 Mo | anciens telephones 32 bits |
| `cifi_tech_1.0.0_x86_64.apk` | 28,1 Mo | emulateurs et rares tablettes |
| `cifi_tech_1.0.0_universel.apk` | 65,3 Mo | les trois a la fois (option `-SansDecoupage`) |
| `cifi_tech_1.0.0.aab` | 59,3 Mo | a deposer sur le Play Store |

Tous dans :

```
C:\projets_codes\web_view_android_ios_harmonyos\livrables\android\
```

Trois fichiers APK, parce que par defaut le script fait un APK par type
de processeur. C'est environ trois fois plus leger pour l'utilisateur
que le fichier universel.

> **Le numero de version des APK decoupes vous surprendra.**
> L'APK `arm64-v8a` affiche `versionCode=2001` alors que votre
> configuration dit `1`. C'est normal : Flutter ajoute
> `1000 x numero_architecture` pour que le Play Store distingue les
> fichiers et serve le bon a chaque telephone.
> Voir `docs\06_depannage.md`, section 16.8.


> **Lequel envoyer a quelqu'un ?**
> `arm64-v8a` dans 95 % des cas. C'est le processeur de tous les
> telephones recents.
>
> Si vous ne savez pas, faites un seul fichier qui marche partout :
> ```powershell
> powershell -File scripts\compiler_android.ps1 -SansDecoupage
> ```

### 2.2 Installer l'APK sur un telephone

Telephone branche en USB, debogage USB active :

```powershell
adb install -r C:\projets_codes\web_view_android_ios_harmonyos\livrables\android\cifi_tech_1.0.0_arm64-v8a.apk
```

Ou bien : copiez le fichier sur le telephone, ouvrez-le avec le
gestionnaire de fichiers, autorisez l'installation depuis cette source.

### 2.3 Preparer la signature pour le Play Store

Le Play Store **refuse** un APK signe avec la cle de debogage.
Il faut votre propre cle. On la fabrique **une seule fois**.

**Etape 1 — creer la cle :**

```powershell
cd C:\projets_codes\web_view_android_ios_harmonyos\cifi_application\android\cles
keytool -genkey -v -keystore cifi_release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias cifi
```

L'outil pose des questions. Repondez :

- un mot de passe (notez-le, deux fois plutot qu'une)
- votre nom
- votre unite d'organisation : `CiFi Tech`
- votre organisation : `CiFi`
- votre ville : `N'Djamena`
- votre region : `Chari-Baguirmi`
- votre code pays : `TD`

**Etape 2 — remplir le fichier de mots de passe :**

Copiez le modele :

```powershell
copy C:\projets_codes\web_view_android_ios_harmonyos\cifi_application\android\cles\cle.proprietes.modele C:\projets_codes\web_view_android_ios_harmonyos\cifi_application\android\cles\cle.proprietes
```

Ouvrez le nouveau fichier et remplacez les `A_REMPLACER` :

```properties
chemin_magasin=cles/cifi_release.jks
alias_cle=cifi
mot_de_passe_magasin=votre_mot_de_passe
mot_de_passe_cle=votre_mot_de_passe
```

**Etape 3 — verifier que ca marche :**

```powershell
powershell -File scripts\compiler_android.ps1
```

Le script doit afficher :

```
[OK]     cle de signature trouvee : version publiable
```

> ## DANGER : ne perdez jamais cette cle
>
> Le fichier `cifi_release.jks` est **irremplacable**.
>
> Si vous le perdez, vous ne pourrez **plus jamais** mettre a jour votre
> application sur le Play Store. Il faudra en publier une nouvelle et
> redemander a tous vos utilisateurs de l'installer.
>
> **Faites deux sauvegardes**, sur deux supports differents, hors de
> l'ordinateur. Notez les mots de passe au meme endroit.
>
> Le fichier est deja exclu de git par `.gitignore` : il ne partira
> jamais sur GitHub par accident.

### 2.4 Fabriquer le `.aab` pour le Play Store

```powershell
powershell -File scripts\compiler_android.ps1 -Type aab
```

Resultat :

```
C:\projets_codes\web_view_android_ios_harmonyos\livrables\android\cifi_tech_1.0.0.aab
```

C'est ce fichier que vous deposez sur
<https://play.google.com/console>.

### 2.5 Toutes les options

```powershell
# APK uniquement (defaut)
powershell -File scripts\compiler_android.ps1 -Type apk

# AAB uniquement
powershell -File scripts\compiler_android.ps1 -Type aab

# Les deux
powershell -File scripts\compiler_android.ps1 -Type tout

# Version de test, avec les outils de debogage
powershell -File scripts\compiler_android.ps1 -Debogage

# Un seul APK qui marche sur tous les telephones
powershell -File scripts\compiler_android.ps1 -SansDecoupage
```

---

## 3. iPhone

**Rappel : il faut un Mac.** Aucune alternative.

### 3.1 Avant la premiere compilation

1. Ouvrez le projet dans Xcode :
   ```bash
   open cifi_application/ios/Runner.xcworkspace
   ```
   (bien `.xcworkspace`, pas `.xcodeproj`)

2. Selectionnez **Runner** dans la colonne de gauche

3. Onglet **Signing & Capabilities**

4. Cochez **Automatically manage signing**

5. Dans **Team**, choisissez votre compte Apple Developer

6. Verifiez que **Bundle Identifier** correspond bien a votre
   `nom_paquet_ios` du fichier de configuration

### 3.2 Compiler

```bash
./scripts/compiler_ios.sh
```

Resultat :

```
livrables/ios/cifi_tech_1.0.0.ipa
```

### 3.3 Envoyer sur TestFlight ou l'App Store

Le plus simple, avec Xcode :
**Window > Organizer > Distribute App**

En ligne de commande :

```bash
xcrun altool --upload-app -f livrables/ios/cifi_tech_1.0.0.ipa \
             -t ios -u votre@courriel.com
```

### 3.4 Tester sans compte payant

```bash
./scripts/compiler_ios.sh --sans-signature
```

Le fichier produit ne s'installe que sur le **simulateur** iPhone,
pas sur un vrai telephone.

---

## 4. HarmonyOS NEXT

### 4.1 Avec le script

```powershell
powershell -ExecutionPolicy Bypass -File scripts\compiler_harmonyos.ps1
```

Sur Mac ou Linux :

```bash
./scripts/compiler_harmonyos.sh
```

Resultat :

```
C:\projets_codes\web_view_android_ios_harmonyos\livrables\harmonyos\cifi_tech_1.0.0_debug.hap
```

### 4.2 Avec DevEco Studio (si le script ne trouve pas les outils)

1. Ouvrez DevEco Studio
2. **File > Open**
3. Choisissez le dossier :
   ```
   C:\projets_codes\web_view_android_ios_harmonyos\cifi_harmonyos
   ```
4. Attendez la fin de la synchronisation (barre en bas)
5. Menu **Build > Build Hap(s)/APP(s) > Build Hap(s)**
6. Le fichier apparait dans :
   ```
   C:\projets_codes\web_view_android_ios_harmonyos\cifi_harmonyos\entry\build\default\outputs\default\
   ```

### 4.3 Signer pour AppGallery

1. Dans DevEco : **File > Project Structure > Signing Configs**
2. Cochez **Automatically generate signature**
3. Connectez-vous avec votre compte Huawei
4. DevEco remplit tout seul le bloc `signingConfigs` de :
   ```
   C:\projets_codes\web_view_android_ios_harmonyos\cifi_harmonyos\build-profile.json5
   ```
5. Compilez en mode release :
   ```powershell
   powershell -File scripts\compiler_harmonyos.ps1 -Mode release
   ```

### 4.4 Installer sur un appareil Huawei

```powershell
hdc install C:\projets_codes\web_view_android_ios_harmonyos\livrables\harmonyos\cifi_tech_1.0.0_debug.hap
```

`hdc` est l'equivalent Huawei de `adb`. Il arrive avec DevEco Studio.

---

## 5. Avant chaque envoi sur une boutique

Verifiez cette liste.

- [ ] `numero_build` a **augmente** depuis le dernier envoi
- [ ] `version_affichee` est a jour
- [ ] `url_accueil` est bien en **`https://`**
- [ ] vous avez eteint les `fonctionnalites` que votre site n'utilise pas
- [ ] les logos sont les bons (lancez l'application et regardez)
- [ ] vous avez lance `appliquer_configuration` **apres** vos modifications
- [ ] la cle de signature est en place (le script l'ecrit)
- [ ] vous avez teste l'application sur un vrai telephone
- [ ] vous avez teste le mode avion (la page hors ligne doit s'afficher)
- [ ] votre site a une **politique de confidentialite** accessible :
      les trois boutiques l'exigent

---

## 6. Pourquoi une boutique refuse une application webview

C'est la question qui compte. Les trois motifs classiques, et la reponse
de ce projet.

| Motif de refus | Ce que fait ce projet |
|---|---|
| "Contenu de faible valeur, simple site web" | notifications push, mode hors ligne, widget, materiel, scanner QR |
| "Demande des autorisations inutiles" | chaque autorisation s'eteint dans `fonctionnalites` |
| "Pas de politique de confidentialite" | a vous de la mettre sur votre site |

> **Le conseil qui fait la difference.**
> Dans le formulaire de la boutique, ne dites pas "application de notre
> site web". Decrivez les fonctions natives :
>
> *"Application mobile avec notifications geolocalisees, consultation
> hors ligne des documents, scanner de codes QR integre et widget
> d'ecran d'accueil."*
>
> C'est vrai, et c'est exactement ce que le relecteur cherche a lire.

---

## 7. Nettoyer quand plus rien ne compile

```powershell
cd C:\projets_codes\web_view_android_ios_harmonyos\cifi_application
flutter clean
flutter pub get
cd ..
powershell -File scripts\appliquer_configuration.ps1
```

Pour HarmonyOS :

```powershell
rmdir /s /q C:\projets_codes\web_view_android_ios_harmonyos\cifi_harmonyos\entry\build
rmdir /s /q C:\projets_codes\web_view_android_ios_harmonyos\cifi_harmonyos\.hvigor
```

Si cela ne suffit pas : `docs\06_depannage.md`.
