# A lire en premier

Bonjour. Ce document explique le projet en mots simples.
Si vous ne lisez qu'une seule page, lisez celle-ci.

---

## 1. A quoi sert ce projet

Vous avez un site web. Vous voulez en faire une **application mobile** :

- une application Android (fichier `.apk` ou `.aab`)
- une application iPhone (fichier `.ipa`)
- une application HarmonyOS NEXT, les telephones Huawei recents (fichier `.hap`)

Ce projet fait les trois, a partir **du meme site**.

Et surtout : vous pouvez **changer de site quand vous voulez**.
Vous changez une adresse dans un fichier, vous remplacez le logo,
vous relancez un script, et vous obtenez une nouvelle application
pour un autre client. Sans retoucher une seule ligne de code.

---

## 2. Ce n'est pas "juste une webview"

Attention, c'est important.

Google Play et Apple **refusent** les applications qui se contentent
d'afficher un site web. Ils appellent ca du "contenu de faible valeur".

Cette application fait beaucoup plus. Elle apporte :

| Ce que fait l'application | Ce qu'un navigateur ne fait pas |
|---|---|
| **Notifications push** envoyees a vos utilisateurs | un site ne peut pas vous notifier quand il est ferme |
| **Notifications par zone** : l'utilisateur entre pres de votre bureau, il recoit un message | impossible dans un navigateur |
| **Mode hors ligne** : les pages deja vues restent lisibles sans reseau | le navigateur affiche "pas de connexion" |
| **Appareil photo, micro, fichiers, scanner de code QR** | acces limite et peu fiable |
| **Vibration** en retour des actions | pas disponible |
| **Barre de chargement native** et ecran de demarrage a votre marque | le navigateur montre sa propre barre |
| **Widget sur l'ecran d'accueil** du telephone | impossible |
| **Partage natif** vers WhatsApp, courriel, etc. | moins bien integre |

C'est ce qui fait accepter l'application par les boutiques.

---

## 3. Les dossiers, en une phrase chacun

Tout part de ce dossier :

```
web_view_android_ios_harmonyos\
```

| Dossier | A quoi il sert |
|---|---|
| `configuration\` | **LE fichier a modifier.** Adresse du site, nom, couleurs. |
| `marque\` | Vos logos. Remplacez les images, c'est tout. |
| `scripts\` | Les scripts a lancer. Installation, configuration, compilation. |
| `cifi_application\` | Le code de l'application Android et iPhone (langage Dart / Flutter). |
| `cifi_harmonyos\` | Le code de l'application Huawei HarmonyOS (langage ArkTS). |
| `plateforme_android\` | Reglages Android recopies dans le projet a la generation. |
| `plateforme_ios\` | Reglages iPhone recopies dans le projet a la generation. |
| `livrables\` | Les fichiers finaux `.apk`, `.ipa`, `.hap`. Cree automatiquement. |
| `docs\` | Cette documentation. |

---

## 4. Par ou commencer

Suivez dans l'ordre. Ne sautez pas d'etape.

### Vous etes sur Windows

1. Lisez **`docs\01_installation_windows.md`** et lancez le script d'installation.
2. Fermez le terminal. Rouvrez-le. **Obligatoire.**
3. Lancez :
   ```
   powershell -ExecutionPolicy Bypass -File scripts\initialiser_projet.ps1
   ```
4. Lisez **`docs\03_personnalisation.md`** pour mettre votre site et votre logo.
5. Lisez **`docs\04_compilation.md`** pour fabriquer les fichiers.

### Vous etes sur Mac ou Linux

Pareil, mais lisez **`docs\02_installation_mac_linux.md`**.

---

## 5. La chose a retenir

Il y a **un seul fichier** a modifier pour changer d'application :

```
web_view_android_ios_harmonyos\configuration\cifi_parametres.json
```

Et **un seul dossier** pour changer les images :

```
web_view_android_ios_harmonyos\marque\
```

Apres chaque modification, vous lancez :

```
powershell -ExecutionPolicy Bypass -File scripts\appliquer_configuration.ps1
```

Ce script recopie vos reglages partout, sur les trois plateformes.
C'est tout. Vous ne touchez jamais au code.

---

## 6. Ce qui demande un Mac

Une seule chose : fabriquer le fichier `.ipa` pour iPhone.

Apple l'impose. Aucun contournement n'existe. Vos options :

- acheter ou emprunter un Mac
- louer un Mac en ligne (MacStadium, MacInCloud)
- utiliser un service qui compile pour vous : **Codemagic**, ou
  **GitHub Actions** avec une machine `macos-latest`

Android et HarmonyOS se compilent tres bien depuis Windows.

---

## 7. Ce qui demande un compte Huawei

Pour HarmonyOS, il faut **DevEco Studio**, le logiciel de Huawei.
Son telechargement exige un compte gratuit sur
<https://developer.huawei.com>.

Le script d'installation ne peut pas le telecharger a votre place :
Huawei demande une connexion. Le script vous donne le lien, vous
installez, puis vous relancez le script : il trouve tout seul le
logiciel et pose les bons reglages.

---

## 8. Les autres pages de la documentation

| Fichier | Contenu |
|---|---|
| `01_installation_windows.md` | Installer les outils sur Windows |
| `02_installation_mac_linux.md` | Installer les outils sur Mac ou Linux |
| `03_personnalisation.md` | **Changer le site, le nom, le logo, les couleurs** |
| `04_compilation.md` | Fabriquer `.apk`, `.aab`, `.ipa`, `.hap` |
| `05_fonctionnalites.md` | Notifications, hors ligne, widget, code du site |
| `06_depannage.md` | Que faire quand ca ne marche pas |
