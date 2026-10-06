# Personnalisation : changer le site, le nom, le logo

C'est **la page la plus importante**.

Elle explique comment transformer ce projet en application pour
n'importe quel site web, sans toucher au code.

---

## 1. La regle d'or

Il y a **un seul fichier** a modifier :

```
C:\projets_codes\web_view_android_ios_harmonyos\configuration\cifi_parametres.json
```

Et **un seul dossier** d'images :

```
C:\projets_codes\web_view_android_ios_harmonyos\marque\
```

Apres chaque modification, vous lancez **une seule commande** :

```powershell
cd C:\projets_codes\web_view_android_ios_harmonyos
powershell -ExecutionPolicy Bypass -File scripts\appliquer_configuration.ps1
```

Sur Mac ou Linux :

```bash
./scripts/appliquer_configuration.sh
```

Ce script recopie vos reglages dans les **trois** projets
(Android, iPhone, HarmonyOS). Vous ne touchez jamais au code.

---

## 2. Faire une application pour un autre site : les 5 minutes

Exemple concret. Vous voulez une application pour `https://www.monclient.td`.

### Etape 1 : ouvrez le fichier de configuration

```
C:\projets_codes\web_view_android_ios_harmonyos\configuration\cifi_parametres.json
```

Ouvrez-le avec le Bloc-notes, Notepad++ ou VS Code.

### Etape 2 : changez ces 6 lignes

```json
{
  "identite": {
    "nom_affiche": "Mon Client",
    "nom_paquet_android": "td.monclient.application",
    "nom_paquet_ios": "td.monclient.application",
    "nom_paquet_harmonyos": "td.monclient.application",
    "nom_fichier_sortie": "monclient",
    ...
  },
  "site_cible": {
    "url_accueil": "https://www.monclient.td",
    "domaines_autorises": ["monclient.td", "www.monclient.td"],
    ...
  }
}
```

### Etape 3 : remplacez les logos

Mettez vos images **a la place** de celles-ci, avec exactement les
memes noms :

```
C:\projets_codes\web_view_android_ios_harmonyos\marque\logo.png
C:\projets_codes\web_view_android_ios_harmonyos\marque\logo_splash.png
C:\projets_codes\web_view_android_ios_harmonyos\marque\logo_notification.png
```

### Etape 4 : appliquez

```powershell
powershell -File scripts\appliquer_configuration.ps1
```

### Etape 5 : compilez

```powershell
powershell -File scripts\compiler_android.ps1
```

Votre application est dans :

```
C:\projets_codes\web_view_android_ios_harmonyos\livrables\android\
```

C'est tout. Cinq minutes.

---

## 3. Chaque reglage, un par un

Tout ce qui suit se trouve dans **le meme fichier** :

```
C:\projets_codes\web_view_android_ios_harmonyos\configuration\cifi_parametres.json
```

### 3.1 Bloc `identite` — le nom de l'application

```json
"identite": {
  "nom_affiche": "CiFi Tech",
  "nom_paquet_android": "td.cifi.tech.navigateur",
  "nom_paquet_ios": "td.cifi.tech.navigateur",
  "nom_paquet_harmonyos": "td.cifi.tech.navigateur",
  "nom_fichier_sortie": "cifi_tech",
  "version_affichee": "1.0.0",
  "numero_build": 1,
  "editeur": "CiFi - Centrale d'Innovation et de Formation en Informatique",
  "ville": "N'Djamena",
  "pays": "Tchad"
}
```

| Reglage | Ce que ca change | Ou l'utilisateur le voit |
|---|---|---|
| `nom_affiche` | nom de l'application | sous l'icone, sur l'ecran d'accueil du telephone |
| `nom_paquet_android` | identifiant unique Android | invisible, mais **ne se change plus apres publication** |
| `nom_paquet_ios` | identifiant unique iPhone | idem |
| `nom_paquet_harmonyos` | identifiant unique Huawei | idem |
| `nom_fichier_sortie` | nom du fichier produit | `cifi_tech_1.0.0_arm64-v8a.apk` |
| `version_affichee` | numero de version | dans la boutique, et dans "A propos" |
| `numero_build` | compteur interne | **doit augmenter a chaque envoi** sur une boutique |
| `editeur`, `ville`, `pays` | votre societe | ecran "A propos" dans l'application |

> **Attention au nom de paquet.**
> Une fois votre application publiee sur le Play Store, ce nom est
> definitif. Si vous le changez, c'est une **nouvelle** application :
> vos utilisateurs ne recevront pas la mise a jour.
>
> Forme recommandee : `pays.societe.produit`, en minuscules, sans accent,
> sans tiret. Exemple : `td.cifi.tech.navigateur`.

### 3.2 Bloc `site_cible` — l'adresse du site

```json
"site_cible": {
  "url_accueil": "https://www.cifi.td",
  "domaines_autorises": ["cifi.td", "www.cifi.td"],
  "ouvrir_domaines_externes_dans_navigateur": true,
  "agent_utilisateur_suffixe": "CiFiApp/1.0",
  "autoriser_zoom": false,
  "autoriser_selection_texte": true
}
```

| Reglage | Explication |
|---|---|
| `url_accueil` | la page qui s'ouvre au demarrage. **Mettez `https://`, pas `http://`.** |
| `domaines_autorises` | les domaines qui restent **dans** l'application |
| `ouvrir_domaines_externes_dans_navigateur` | `true` : un lien vers un autre site s'ouvre dans Chrome/Safari. `false` : il reste dans l'application. |
| `agent_utilisateur_suffixe` | votre site peut reconnaitre l'application grace a ce texte |
| `autoriser_zoom` | `true` : l'utilisateur peut zoomer avec deux doigts |
| `autoriser_selection_texte` | `false` : empeche la copie de texte |

> **Sur `domaines_autorises`.**
> Mettez le domaine **sans** `https://` et **sans** barre oblique.
> Ecrivez `cifi.td` : les sous-domaines comme `boutique.cifi.td`
> sont automatiquement compris.
>
> Le **dernier** domaine de la liste sert aussi aux liens profonds,
> c'est-a-dire l'ouverture directe de votre application quand quelqu'un
> clique sur un lien de votre site depuis WhatsApp.

### 3.3 Bloc `apparence` — les couleurs

```json
"apparence": {
  "couleur_primaire": "#0B5FFF",
  "couleur_secondaire": "#00B894",
  "couleur_fond_clair": "#FFFFFF",
  "couleur_fond_sombre": "#0E1116",
  "couleur_texte_clair": "#11161D",
  "couleur_texte_sombre": "#EDF1F7",
  "couleur_splash": "#0B5FFF",
  "mode_sombre_automatique": true,
  "orientation_verrouillee": "aucune"
}
```

| Reglage | Ou on la voit |
|---|---|
| `couleur_primaire` | barre de chargement, bouton flottant, widget |
| `couleur_secondaire` | bandeau "version enregistree affichee" |
| `couleur_fond_clair` | fond en mode clair |
| `couleur_fond_sombre` | fond en mode sombre |
| `couleur_splash` | fond de l'ecran de demarrage |
| `mode_sombre_automatique` | `true` : suit le reglage du telephone |
| `orientation_verrouillee` | `aucune`, `portrait` ou `paysage` |

Les couleurs s'ecrivent en hexadecimal : `#` suivi de 6 chiffres.
Pour trouver le code d'une couleur : <https://htmlcolorcodes.com>

### 3.4 Bloc `marque` — les chemins des logos

```json
"marque": {
  "logo_application": "marque/logo.png",
  "logo_splash": "marque/logo_splash.png",
  "logo_notification": "marque/logo_notification.png"
}
```

Normalement vous **ne touchez pas** a ce bloc.
Vous remplacez simplement les fichiers dans le dossier `marque\`.

### 3.5 Bloc `fonctionnalites` — allumer ou eteindre

```json
"fonctionnalites": {
  "mode_hors_ligne": true,
  "duree_cache_jours": 7,
  "notifications_push": true,
  "notifications_geolocalisees": true,
  "rayon_geofence_metres": 500,
  "acces_camera": true,
  "acces_microphone": true,
  "acces_galerie": true,
  "acces_geolocalisation": true,
  "acces_fichiers": true,
  "vibration_retour_haptique": true,
  "partage_natif": true,
  "scanner_qr": true,
  "widget_ecran_accueil": true,
  "tirer_pour_rafraichir": true,
  "barre_progression_chargement": true,
  "navigation_gestes_retour": true
}
```

Mettez `false` pour eteindre une fonction.

> **Conseil important.**
> Eteignez ce dont votre site ne se sert pas.
> Si votre application demande l'acces a l'appareil photo alors qu'elle
> ne s'en sert jamais, Apple la refuse. Google aussi, de plus en plus.
>
> Exemple pour un simple site d'information :
> ```json
> "acces_camera": false,
> "acces_microphone": false,
> "scanner_qr": false,
> ```

### 3.6 Bloc `geofences` — les notifications par zone

```json
"geofences": [
  {
    "identifiant": "siege_ndjamena",
    "libelle": "Siege CiFi N'Djamena",
    "latitude": 12.1348,
    "longitude": 15.0557,
    "rayon_metres": 500,
    "message_entree": "Bienvenue au siege CiFi Tech.",
    "message_sortie": "A bientot chez CiFi Tech."
  }
]
```

Quand l'utilisateur **entre** dans le cercle, il recoit `message_entree`.
Quand il **sort**, il recoit `message_sortie`.

Laissez un message vide (`""`) pour ne rien envoyer dans ce sens.

Pour ajouter une zone, copiez le bloc entre accolades et separez par une
virgule :

```json
"geofences": [
  { "identifiant": "siege", ... },
  { "identifiant": "agence_moundou", ... }
]
```

**Comment trouver la latitude et la longitude :**
ouvrez <https://www.google.com/maps>, clic droit sur le lieu,
le premier element du menu donne les deux nombres. Le premier est la
latitude, le second la longitude.

Pour desactiver completement cette fonction, mettez une liste vide :

```json
"geofences": []
```

### 3.7 Bloc `notifications` — le canal

```json
"notifications": {
  "canal_identifiant": "cifi_canal_principal",
  "canal_libelle": "Notifications CiFi",
  "canal_description": "Alertes et informations CiFi Tech",
  "sujet_diffusion": "cifi_tous"
}
```

| Reglage | Explication |
|---|---|
| `canal_identifiant` | nom technique, sans espace ni accent |
| `canal_libelle` | ce que l'utilisateur lit dans les reglages Android |
| `canal_description` | la phrase sous le libelle |
| `sujet_diffusion` | le "groupe" auquel tous les telephones s'abonnent, pour envoyer un message a tout le monde |

---

## 4. Les logos : formats attendus

```
C:\projets_codes\web_view_android_ios_harmonyos\marque\
```

| Fichier | Taille | Conseils |
|---|---|---|
| `logo.png` | **1024 x 1024** | l'icone de l'application. Carre. Fond transparent ou plein, au choix. |
| `logo_splash.png` | **1024 x 1024** | le logo de l'ecran de demarrage. **Fond transparent obligatoire**, sinon il apparait dans un carre. |
| `logo_notification.png` | **256 x 256** | petite icone des notifications. Android l'affiche en blanc uni : faites une forme simple. |

> **Pensez-y.**
> Android arrondit l'icone sur beaucoup de telephones. Gardez vos
> elements importants au **centre**, avec une marge d'environ 15 %
> tout autour.
>
> Apple **refuse** la transparence sur l'icone principale. Le projet
> la retire automatiquement (`remove_alpha_ios: true`), mais si votre
> logo a un fond transparent, Apple mettra du noir derriere.
> Pour iPhone, preferez un `logo.png` avec un fond plein.

### Regenerer les logos par defaut

Si vous avez abime les images d'origine :

```powershell
python scripts\generer_logo_defaut.py --forcer
```

---

## 5. Ou va chaque reglage, exactement

Pour les curieux. Le script `appliquer_configuration.py` ecrit dans
ces fichiers precis.

### Android

| Reglage | Fichier modifie |
|---|---|
| `nom_affiche` | `C:\projets_codes\web_view_android_ios_harmonyos\cifi_application\android\app\src\main\AndroidManifest.xml` (attribut `android:label`) |
| `nom_paquet_android` | `...\cifi_application\android\app\build.gradle.kts` (`applicationId`) |
| `numero_build` | idem (`versionCode`) |
| `version_affichee` | idem (`versionName`) |
| dernier `domaines_autorises` | `AndroidManifest.xml` (balise `<data android:host>`) |
| `canal_identifiant` | `AndroidManifest.xml` (`default_notification_channel_id`) |
| `couleur_primaire` | `...\cifi_application\android\app\src\main\res\drawable\cifi_widget_fond.xml` |

### iPhone

| Reglage | Fichier modifie |
|---|---|
| `nom_affiche` | `...\cifi_application\ios\Runner\Info.plist` (`CFBundleDisplayName`) |
| `nom_paquet_ios` | `...\cifi_application\ios\Runner.xcodeproj\project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER`) |

### HarmonyOS

| Reglage | Fichier modifie |
|---|---|
| `nom_paquet_harmonyos` | `...\cifi_harmonyos\AppScope\app.json5` (`bundleName`) |
| `numero_build` | idem (`versionCode`) |
| `version_affichee` | idem (`versionName`) |
| `nom_affiche` | `...\cifi_harmonyos\AppScope\resources\base\element\string.json` et `...\cifi_harmonyos\entry\src\main\resources\base\element\string.json` |
| couleurs | `...\cifi_harmonyos\entry\src\main\resources\base\element\color.json` |
| dernier `domaines_autorises` | `...\cifi_harmonyos\entry\src\main\module.json5` (`host`) |

### Commun aux trois

| Reglage | Fichier |
|---|---|
| tout le fichier JSON | copie vers `...\cifi_application\assets\configuration\cifi_parametres.json` |
| tout le fichier JSON | copie vers `...\cifi_harmonyos\entry\src\main\resources\rawfile\cifi_parametres.json` |
| `version_affichee` + `numero_build` | `...\cifi_application\pubspec.yaml` (ligne `version:`) |
| `couleur_splash` | `...\cifi_application\pubspec.yaml` (section `flutter_native_splash`) |

> **Ne modifiez jamais ces fichiers a la main.**
> Le script les reecrit a chaque execution : vos changements seraient perdus.

---

## 6. Changer la page affichee quand il n'y a pas de reseau

Le fichier :

```
C:\projets_codes\web_view_android_ios_harmonyos\cifi_application\assets\pages\hors_ligne.html
```

C'est du HTML et du CSS **ecrits a la main**, sans aucune bibliotheque
externe. Vous pouvez tout changer : le texte, la mise en page, le dessin.

Les mots entre doubles accolades sont remplis automatiquement :

| Marqueur | Devient |
|---|---|
| `{{NOM_APPLICATION}}` | `identite.nom_affiche` |
| `{{URL_DEMANDEE}}` | l'adresse qui n'a pas pu etre chargee |
| `{{COULEUR_PRIMAIRE}}` | `apparence.couleur_primaire` |
| `{{COULEUR_FOND}}` | fond clair ou sombre selon le telephone |
| `{{COULEUR_TEXTE}}` | texte clair ou sombre |
| `{{COULEUR_DISCRETE}}` | le texte, en 62 % d'opacite |
| `{{COULEUR_BORDURE}}` | le texte, en 12 % d'opacite |

Apres modification, relancez `appliquer_configuration` : le fichier est
recopie vers le projet HarmonyOS, qui utilise exactement la meme page.

---

## 7. Faire plusieurs applications depuis le meme projet

Vous avez trois clients. Vous voulez trois applications.

### Methode simple : un dossier de configuration par client

1. Copiez `configuration\cifi_parametres.json` autant de fois que de clients :
   ```
   C:\projets_codes\web_view_android_ios_harmonyos\configuration\client_alpha.json
   C:\projets_codes\web_view_android_ios_harmonyos\configuration\client_beta.json
   ```
2. Faites de meme pour les logos :
   ```
   C:\projets_codes\web_view_android_ios_harmonyos\marque\alpha\logo.png
   C:\projets_codes\web_view_android_ios_harmonyos\marque\beta\logo.png
   ```
3. Avant chaque compilation, copiez la bonne configuration en place :
   ```powershell
   copy configuration\client_alpha.json configuration\cifi_parametres.json
   copy marque\alpha\*.png marque\
   powershell -File scripts\appliquer_configuration.ps1
   powershell -File scripts\compiler_android.ps1
   ```
4. Recuperez le fichier dans `livrables\android\`, rangez-le, et
   recommencez avec le client suivant.

Comme `nom_fichier_sortie` change d'un client a l'autre, les fichiers
ne s'ecrasent pas entre eux.

---

## 8. Recapitulatif en 4 lignes

```powershell
# 1. Modifier
notepad C:\projets_codes\web_view_android_ios_harmonyos\configuration\cifi_parametres.json

# 2. Remplacer les logos dans marque\

# 3. Appliquer
powershell -File scripts\appliquer_configuration.ps1

# 4. Compiler
powershell -File scripts\compiler_android.ps1
```
