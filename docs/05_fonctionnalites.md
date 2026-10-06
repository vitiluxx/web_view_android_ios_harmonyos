# Les fonctionnalites, et comment votre site les utilise

Cette page explique ce que l'application sait faire en plus d'un
navigateur, et comment votre site web peut s'en servir.

---

## 1. Le pont entre votre site et le telephone

Quand l'application ouvre votre site, elle y ajoute un objet JavaScript
appele **`window.CiFi`**. Votre site peut l'appeler comme n'importe
quelle fonction.

### Savoir si on est dans l'application

```html
<script>
  if (window.CiFi && window.CiFi.disponible) {
    // On est dans l'application mobile
    document.body.classList.add('dans-application');
  } else {
    // On est dans un navigateur ordinaire
  }
</script>
```

C'est la base. Cela vous permet de cacher le menu de votre site dans
l'application, d'afficher un bouton "Prendre une photo" seulement sur
mobile, etc.

### Attendre que le pont soit pret

```html
<script>
  document.addEventListener('cifi-passerelle-prete', function () {
    console.log('Les fonctions natives sont disponibles');
  });
</script>
```

---

## 2. Toutes les fonctions disponibles

Chaque fonction renvoie une **promesse**. Utilisez `await` ou `.then()`.

### 2.1 Informations sur l'appareil

```javascript
const infos = await window.CiFi.appareilInformations();
console.log(infos);
// {
//   succes: true,
//   appareil: "Samsung SM-A546B (Android 14)",
//   version_application: "1.0.0+1",
//   nom_application: "CiFi Tech",
//   en_ligne: true
// }
```

### 2.2 Prendre une photo

```javascript
const resultat = await window.CiFi.prendrePhoto();
if (resultat.succes) {
  console.log('Photo enregistree ici :', resultat.chemin);
}
```

L'appareil photo du telephone s'ouvre. L'utilisateur prend la photo.
Vous recevez le chemin du fichier sur l'appareil.

### 2.3 Choisir une image dans la galerie

```javascript
const resultat = await window.CiFi.choisirImage();
if (resultat.succes) {
  console.log('Image choisie :', resultat.chemin);
}
```

### 2.4 Choisir un fichier

```javascript
const resultat = await window.CiFi.choisirFichier();
if (resultat.succes) {
  console.log('Fichier choisi :', resultat.chemin);
}
```

### 2.5 Position de l'utilisateur

```javascript
const position = await window.CiFi.positionActuelle();
if (position.succes) {
  console.log(position.latitude, position.longitude);
  console.log('Precision :', position.precision_metres, 'metres');
}
```

### 2.6 Faire vibrer le telephone

```javascript
await window.CiFi.vibrer();      // vibration courte, 40 ms
await window.CiFi.vibrer(120);   // vibration plus longue
```

Utilisez-la en retour d'une action reussie : commande validee,
formulaire envoye. C'est un detail qui fait "vraie application".

### 2.7 Partager

```javascript
await window.CiFi.partager(
  'Regardez cet article : https://www.cifi.td/article/42',
  'Article CiFi Tech'
);
```

La feuille de partage du telephone s'ouvre : WhatsApp, courriel, SMS...

### 2.8 Envoyer une notification

```javascript
await window.CiFi.notifier(
  'Commande validee',
  'Votre commande 1042 est confirmee.',
  'https://www.cifi.td/commandes/1042'
);
```

Le troisieme parametre est facultatif : c'est l'adresse qui s'ouvrira
quand l'utilisateur appuiera sur la notification.

### 2.9 Mettre a jour le widget d'ecran d'accueil

```javascript
await window.CiFi.majWidget(
  'CiFi Tech',
  '3 nouveaux messages',
  'https://www.cifi.td/messages'
);
```

### 2.10 Savoir si le reseau est la

```javascript
const etat = await window.CiFi.etatReseau();
if (!etat.en_ligne) {
  afficherUnMessageHorsLigne();
}
```

### 2.11 Lister les pages enregistrees hors ligne

```javascript
const archives = await window.CiFi.pagesHorsLigne();
archives.pages.forEach(function (page) {
  console.log(page.titre, page.url, page.horodatage);
});
```

### 2.12 Recevoir un code QR scanne

Quand l'utilisateur scanne un code QR qui ne contient **pas** une
adresse web, le texte est renvoye a votre site :

```javascript
document.addEventListener('cifi-code-scanne', function (evenement) {
  console.log('Code lu :', evenement.detail);
  document.getElementById('champ-reference').value = evenement.detail;
});
```

Si le code contient une adresse de votre site, l'application y va
directement. S'il contient une adresse externe, elle s'ouvre dans le
navigateur.

### Tableau recapitulatif

| Fonction | Android | iPhone | HarmonyOS |
|---|---|---|---|
| `appareilInformations` | oui | oui | oui |
| `prendrePhoto` | oui | oui | via `<input type="file">` |
| `choisirImage` | oui | oui | via `<input type="file">` |
| `choisirFichier` | oui | oui | via `<input type="file">` |
| `positionActuelle` | oui | oui | oui |
| `vibrer` | oui | oui | oui |
| `partager` | oui | oui | oui |
| `notifier` | oui | oui | oui |
| `majWidget` | oui | oui | non |
| `etatReseau` | oui | oui | oui |
| `pagesHorsLigne` | oui | oui | oui |

> Sur HarmonyOS, l'appareil photo et les fichiers passent par le
> composant standard `<input type="file" accept="image/*" capture>`
> de votre page. Le systeme ouvre l'appareil photo tout seul.

---

## 3. Le mode hors ligne

### Comment ca marche

1. Chaque page que l'utilisateur visite est **enregistree** sur le
   telephone, automatiquement.
2. Quand le reseau tombe, l'application cherche la page dans ses archives.
3. Si elle la trouve, elle l'affiche, avec un bandeau vert
   "version enregistree affichee".
4. Si elle ne la trouve pas, elle affiche la page hors ligne locale.

### Les reglages

Dans `configuration\cifi_parametres.json` :

```json
"mode_hors_ligne": true,
"duree_cache_jours": 7
```

- `duree_cache_jours` : au-dela, les pages sont effacees.
- Le nombre de pages gardees est limite a 40, les plus anciennes partent
  en premier.

### Ou les pages sont stockees

| Plateforme | Dossier |
|---|---|
| Android | dossier prive de l'application, `files/pages_cifi` |
| iPhone | `Application Support/pages_cifi` |
| HarmonyOS | `filesDir/pages_cifi` |

L'utilisateur peut tout effacer depuis le menu de l'application :
bouton rond en bas a droite > **Pages enregistrees** > icone corbeille.

### Personnaliser la page hors ligne

```
C:\projets_codes\web_view_android_ios_harmonyos\cifi_application\assets\pages\hors_ligne.html
```

HTML et CSS ecrits a la main, aucune bibliotheque. Voir
`docs\03_personnalisation.md`, section 6, pour la liste des marqueurs.

---

## 4. Les notifications push

### Deux sortes

| Sorte | Qui l'envoie | Besoin d'un serveur |
|---|---|---|
| **locale** | l'application elle-meme | non |
| **distante (push)** | votre serveur, via Firebase | oui |

Les notifications locales marchent **tout de suite**, sans rien
configurer. Les notifications distantes demandent Firebase.

### Mettre en place Firebase (Android et iPhone)

**Etape 1 — creer le projet Firebase**

1. Allez sur <https://console.firebase.google.com>
2. **Ajouter un projet**, donnez-lui un nom
3. Desactivez Google Analytics si vous n'en voulez pas

**Etape 2 — connecter votre application**

Dans un terminal :

```powershell
cd C:\projets_codes\web_view_android_ios_harmonyos\cifi_application
flutterfire configure
```

L'outil pose des questions, choisissez votre projet Firebase et cochez
Android et iOS. Il depose tout seul :

```
C:\projets_codes\web_view_android_ios_harmonyos\cifi_application\android\app\google-services.json
C:\projets_codes\web_view_android_ios_harmonyos\cifi_application\ios\Runner\GoogleService-Info.plist
C:\projets_codes\web_view_android_ios_harmonyos\cifi_application\lib\firebase_options.dart
```

**Etape 3 — recompiler**

```powershell
powershell -File scripts\compiler_android.ps1
```

**Etape 4 — envoyer un message a tout le monde**

Dans la console Firebase : **Engage > Messaging > Nouvelle campagne**.
Dans la cible, choisissez le **sujet** `cifi_tous` (ou la valeur que vous
avez mise dans `notifications.sujet_diffusion`).

**Pour ouvrir une page precise**, ajoutez une donnee personnalisee :

| Cle | Valeur |
|---|---|
| `url` | `https://www.cifi.td/promotion` |

L'application ouvrira cette page quand l'utilisateur appuiera sur la
notification.

### iPhone : etape supplementaire obligatoire

Apple exige une cle de notification :

1. <https://developer.apple.com/account/resources/authkeys/list>
2. **Keys > +**, cochez **Apple Push Notifications service (APNs)**
3. Telechargez le fichier `.p8` (**une seule fois possible**)
4. Dans Firebase : **Parametres du projet > Cloud Messaging >
   Configuration de l'application Apple**, deposez le `.p8`,
   le Key ID et le Team ID

### HarmonyOS : Huawei Push Kit

HarmonyOS n'utilise pas Firebase. Il faut Huawei Push Kit :

1. <https://developer.huawei.com/consumer/en/service/josp/agc/index.html>
2. Creez un projet, ajoutez votre application avec le `bundleName`
   de votre configuration
3. Telechargez `agconnect-services.json`
4. Deposez-le dans :
   ```
   C:\projets_codes\web_view_android_ios_harmonyos\cifi_harmonyos\entry\src\main\resources\rawfile\
   ```
5. Ajoutez la dependance dans :
   ```
   C:\projets_codes\web_view_android_ios_harmonyos\cifi_harmonyos\entry\oh-package.json5
   ```
   ```json
   "dependencies": {
     "@hw-agconnect/hmcore": "^1.0.0",
     "@kit.PushKit": "^1.0.0"
   }
   ```

> Sans cette etape, les notifications **locales** HarmonyOS fonctionnent
> quand meme : alertes de zone, messages declenches par votre site.
> Seules les notifications envoyees depuis un serveur manquent.

---

## 5. Les notifications par zone (geofencing)

### Le principe

Vous declarez un cercle sur la carte. Quand l'utilisateur entre dedans,
il recoit un message. Quand il en sort, un autre.

C'est **la** fonction qu'un site web ne pourra jamais faire.

### Reglage

Dans `configuration\cifi_parametres.json` :

```json
"notifications_geolocalisees": true,
"rayon_geofence_metres": 500,

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

### Idees d'utilisation

- une agence : "Vous etes a cote de notre agence, passez nous voir"
- un commerce : "Promotion du jour disponible en magasin"
- un campus : "Vos cours du jour sont affiches"
- un evenement : "Le programme de la journee est en ligne"

### Les limites a connaitre

- La position n'est relevee que si l'utilisateur a **accepte** la
  geolocalisation.
- Pour que ca marche quand l'application est fermee, il faut
  l'autorisation "toujours", que beaucoup d'utilisateurs refusent.
- Les relevés sont espaces d'au moins 50 metres de deplacement,
  pour menager la batterie.
- iOS limite fortement la localisation en arriere-plan. Attendez-vous
  a un declenchement moins fiable que sur Android.

---

## 6. Le widget d'ecran d'accueil

### Android : rien a faire

Le widget est deja pret. L'utilisateur appuie longuement sur son ecran
d'accueil, choisit **Widgets**, trouve votre application, et le pose.

Les fichiers concernes :

```
C:\projets_codes\web_view_android_ios_harmonyos\plateforme_android\app\src\main\res\layout\cifi_widget_disposition.xml
C:\projets_codes\web_view_android_ios_harmonyos\plateforme_android\app\src\main\res\xml\cifi_widget_information.xml
C:\projets_codes\web_view_android_ios_harmonyos\plateforme_android\app\src\main\kotlin\td\cifi\tech\cifi_navigateur\CifiFournisseurWidget.kt
```

### iPhone : a ajouter dans Xcode

Apple impose de creer l'extension a la main, une seule fois.

1. Ouvrez `cifi_application/ios/Runner.xcworkspace` dans Xcode
2. **File > New > Target**
3. Choisissez **Widget Extension**
4. Nom du produit : **exactement** `CifiWidget`
5. Decochez **Include Configuration Intent**
6. Xcode cree un dossier `CifiWidget`. Remplacez son fichier Swift par :
   ```
   C:\projets_codes\web_view_android_ios_harmonyos\plateforme_ios\CifiWidget\CifiWidget.swift
   ```
7. Selectionnez la cible **Runner**, onglet **Signing & Capabilities**,
   bouton **+ Capability**, ajoutez **App Groups**
8. Creez le groupe, nomme **exactement** :
   ```
   group.td.cifi.tech.navigateur
   ```
9. Faites la meme chose sur la cible **CifiWidget**, avec le meme groupe

> Le nom du groupe doit etre identique a la constante `groupeApple`
> dans le fichier :
> `C:\projets_codes\web_view_android_ios_harmonyos\cifi_application\lib\services\service_widget_accueil.dart`
>
> Si vous changez `nom_paquet_ios`, changez aussi cette constante.

### HarmonyOS

HarmonyOS appelle ca une "form". Elle n'est pas incluse dans ce projet.
Pour l'ajouter : DevEco Studio, clic droit sur le module `entry`,
**New > Service Widget**.

---

## 7. Les autres apports natifs

### Barre de chargement

Une barre fine, de votre couleur primaire, affiche la **vraie**
progression du chargement. Elle disparait toute seule a 100 %.

Reglage : `"barre_progression_chargement": true`

### Ecran de demarrage

Votre logo sur votre couleur, affiche par le systeme avant meme que
l'application ne demarre. C'est ce qui fait la difference entre une
application et un raccourci web.

Reglages : `apparence.couleur_splash` et `marque\logo_splash.png`

### Tirer pour rafraichir

L'utilisateur tire la page vers le bas, elle se recharge.

Reglage : `"tirer_pour_rafraichir": true`

### Geste retour

Le bouton retour du telephone remonte l'historique de **votre site**,
pas de l'application. Quand il n'y a plus d'historique, l'application
se ferme. Une courte vibration accompagne chaque retour.

Reglage : `"navigation_gestes_retour": true`

### Liens externes

Un lien vers un autre site s'ouvre dans le navigateur du telephone,
pas dans votre application. Les liens `tel:`, `mailto:`, `sms:` et
`whatsapp:` ouvrent directement la bonne application.

Reglage : `"ouvrir_domaines_externes_dans_navigateur": true`

### Menu d'actions natives

Le bouton rond en bas a droite ouvre un menu :

- Rafraichir
- Partager cette page
- Pages enregistrees
- Scanner un code
- A propos

Chaque entree disparait si la fonction correspondante est eteinte dans
`fonctionnalites`.

---

## 8. Ou se trouve chaque fonction dans le code

Pour ceux qui veulent modifier.

### Android et iPhone (langage Dart)

```
C:\projets_codes\web_view_android_ios_harmonyos\cifi_application\lib\
```

| Fonction | Fichier |
|---|---|
| lecture de la configuration | `configuration\parametres_application.dart` |
| couleurs et themes | `configuration\palette_couleurs.dart` |
| messages de journal | `noyau\journal.dart` |
| demarrage des services | `noyau\registre_services.dart` |
| detection du reseau | `services\service_connectivite.dart` |
| mode hors ligne | `services\service_cache_hors_ligne.dart` |
| notifications | `services\service_notifications.dart` |
| geolocalisation et zones | `services\service_geolocalisation.dart` |
| appareil photo, fichiers, partage | `services\service_materiel.dart` |
| widget d'ecran d'accueil | `services\service_widget_accueil.dart` |
| pont JavaScript | `passerelle\passerelle_javascript.dart` |
| ecran de demarrage | `ecrans\ecran_demarrage.dart` |
| ecran principal (la webview) | `ecrans\ecran_navigateur.dart` |
| liste des pages enregistrees | `ecrans\ecran_hors_ligne.dart` |
| scanner de code QR | `ecrans\ecran_scanner_qr.dart` |
| barre de progression | `composants\indicateur_chargement.dart` |
| bandeau hors ligne | `composants\bandeau_reseau.dart` |
| menu d'actions | `composants\menu_actions.dart` |
| fabrication de la page hors ligne | `composants\fabrique_page_hors_ligne.dart` |

### HarmonyOS (langage ArkTS)

```
C:\projets_codes\web_view_android_ios_harmonyos\cifi_harmonyos\entry\src\main\ets\
```

| Fonction | Fichier |
|---|---|
| lecture de la configuration | `configuration\Parametres.ets` |
| messages de journal | `services\Journal.ets` |
| demarrage des services | `services\Registre.ets` |
| detection du reseau | `services\ServiceReseau.ets` |
| mode hors ligne | `services\ServiceCache.ets` |
| notifications | `services\ServiceNotifications.ets` |
| geolocalisation et zones | `services\ServiceGeolocalisation.ets` |
| demarrage de l'application | `entryability\EntryAbility.ets` |
| ecran principal | `pages\PageNavigateur.ets` |

---

## 9. Exemple complet a coller dans votre site

```html
<!-- A placer avant la fermeture de </body> -->
<script>
(function () {
  'use strict';

  var dansApplication = !!(window.CiFi && window.CiFi.disponible);

  if (!dansApplication) {
    return;   // navigateur ordinaire, on ne fait rien
  }

  document.body.classList.add('dans-application-cifi');

  // --- Exemple 1 : vibrer quand un formulaire part
  document.addEventListener('submit', function () {
    window.CiFi.vibrer(60);
  }, true);

  // --- Exemple 2 : bouton de partage
  var boutonPartage = document.getElementById('bouton-partage');
  if (boutonPartage) {
    boutonPartage.addEventListener('click', function () {
      window.CiFi.partager(document.title + '\n' + window.location.href,
                           document.title);
    });
  }

  // --- Exemple 3 : prevenir quand le reseau tombe
  setInterval(function () {
    window.CiFi.etatReseau().then(function (etat) {
      document.body.classList.toggle('hors-ligne', !etat.en_ligne);
    });
  }, 5000);

  // --- Exemple 4 : recevoir un code QR
  document.addEventListener('cifi-code-scanne', function (evenement) {
    var champ = document.getElementById('champ-reference');
    if (champ) {
      champ.value = evenement.detail;
      champ.dispatchEvent(new Event('change'));
    }
  });
})();
</script>

<style>
  /* Cacher le menu du site dans l'application : elle a le sien */
  .dans-application-cifi .menu-du-site { display: none; }

  /* Signaler visuellement la perte de reseau */
  .hors-ligne .zone-commentaires { opacity: 0.45; pointer-events: none; }
</style>
```
