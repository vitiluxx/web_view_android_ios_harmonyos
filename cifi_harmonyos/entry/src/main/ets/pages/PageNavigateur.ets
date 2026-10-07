/**
 * Page unique de l'application HarmonyOS NEXT.
 *
 * Elle affiche le site cible dans un composant Web (ArkWeb) et y ajoute
 * les memes apports natifs que la version Flutter :
 *   - barre de progression reelle du chargement
 *   - bandeau et page de secours hors ligne
 *   - archivage automatique des pages consultees
 *   - passerelle JavaScript vers le materiel
 *   - geste retour materiel qui remonte l'historique du site
 */

import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { util } from '@kit.ArkTS';

import { Parametres } from '../configuration/Parametres';
import { Journal } from '../services/Journal';
import { Registre } from '../services/Registre';
import { PageArchivee } from '../services/ServiceCache';

/** Reponse standard renvoyee au site par la passerelle. */
interface ReponsePasserelle {
  succes: boolean;
  [cle: string]: Object | undefined;
}

@Entry
@Component
struct PageNavigateur {
  private controleurWeb: webview.WebviewController = new webview.WebviewController();
  private registre: Registre = Registre.courant;
  private gabaritHorsLigne: string = '';

  @State progression: number = 0;
  @State enLigne: boolean = true;
  @State premierRenduTermine: boolean = false;
  @State pageSecoursAffichee: boolean = false;
  @State urlCourante: string = Parametres.courants.site_cible.url_accueil;

  // ------------------------------------------------------------ cycle de vie

  aboutToAppear(): void {
    this.registre.reseau.demarrer((enLigne: boolean) => {
      this.enLigne = enLigne;
      if (enLigne && this.pageSecoursAffichee) {
        this.rafraichir();
      }
    });
    this.enLigne = this.registre.reseau.releverMaintenant();
    this.chargerGabaritHorsLigne();
  }

  aboutToDisappear(): void {
    this.registre.reseau.arreter();
  }

  private chargerGabaritHorsLigne(): void {
    try {
      const contexte = getContext(this) as common.UIAbilityContext;
      const octets: Uint8Array =
        contexte.resourceManager.getRawFileContentSync('hors_ligne.html');
      this.gabaritHorsLigne = util.TextDecoder.create('utf-8').decodeToString(octets);
    } catch (erreur) {
      Journal.alerter(`gabarit hors ligne illisible : ${erreur}`);
    }
  }

  // ------------------------------------------------------------ interface

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        if (Parametres.courants.fonctionnalites.barre_progression_chargement) {
          this.barreProgression()
        }
        if (!this.enLigne) {
          this.bandeauReseau()
        }
        this.zoneWeb()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.couleur_fond'))

      if (!this.premierRenduTermine) {
        this.voileChargement()
      }

      this.boutonActions()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  barreProgression() {
    Progress({
      value: this.progression,
      total: 100,
      type: ProgressType.Linear
    })
      .color($r('app.color.couleur_primaire'))
      .backgroundColor(Color.Transparent)
      .height(3)
      .width('100%')
      .opacity(this.progression >= 100 ? 0 : 1)
      .animation({ duration: 260 })
  }

  @Builder
  bandeauReseau() {
    Row() {
      Text(this.registre.cache.estArchivee(this.urlCourante)
        ? 'Hors ligne - version enregistree affichee'
        : 'Hors ligne - connexion introuvable')
        .fontSize(13)
        .fontColor(Color.White)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('Reessayer')
        .fontSize(13)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Medium)
        .onClick(() => this.rafraichir())
    }
    .width('100%')
    .height(40)
    .padding({ left: 14, right: 14 })
    .backgroundColor(this.registre.cache.estArchivee(this.urlCourante)
      ? $r('app.color.couleur_secondaire')
      : $r('app.color.couleur_erreur'))
  }

  @Builder
  zoneWeb() {
    Web({
      src: Parametres.courants.site_cible.url_accueil,
      controller: this.controleurWeb
    })
      .width('100%')
      .layoutWeight(1)
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .databaseAccess(true)
      .geolocationAccess(Parametres.courants.fonctionnalites.acces_geolocalisation)
      .fileAccess(Parametres.courants.fonctionnalites.acces_fichiers)
      .imageAccess(true)
      .mixedMode(MixedMode.None)
      .zoomAccess(Parametres.courants.site_cible.autoriser_zoom)
      .horizontalScrollBarAccess(false)
      .verticalScrollBarAccess(false)
      .cacheMode(CacheMode.Default)
      .javaScriptProxy({
        object: this.construirePasserelle(),
        name: 'CiFiNatif',
        methodList: [
          'appareilInformations',
          'positionActuelle',
          'vibrer',
          'partager',
          'notifier',
          'etatReseau',
          'pagesHorsLigne'
        ],
        controller: this.controleurWeb
      })
      .onProgressChange((evenement) => {
        this.progression = evenement?.newProgress ?? 0;
      })
      .onPageBegin((evenement) => {
        this.urlCourante = evenement?.url ?? this.urlCourante;
        this.progression = 2;
      })
      .onPageEnd((evenement) => {
        this.progression = 100;
        this.premierRenduTermine = true;
        this.injecterPasserelle();
        if (!this.pageSecoursAffichee) {
          this.archiverPageCourante(evenement?.url ?? this.urlCourante);
        }
      })
      .onErrorReceive((evenement) => {
        // Une ressource secondaire absente ne remplace pas la page entiere.
        if (evenement?.request?.isMainFrame() !== true) {
          return;
        }
        Journal.alerter(
          `chargement echoue : ${evenement?.error?.getErrorInfo() ?? 'inconnu'}`
        );
        this.afficherSecoursHorsLigne(evenement?.request?.getRequestUrl() ?? this.urlCourante);
      })
      .onPermissionRequest((evenement) => {
        const fonctionnalites = Parametres.courants.fonctionnalites;
        if (fonctionnalites.acces_camera || fonctionnalites.acces_microphone) {
          evenement?.request?.grant(evenement.request.getAccessibleResource());
        } else {
          evenement?.request?.deny();
        }
      })
      .onGeolocationShow((evenement) => {
        const autorise: boolean =
          Parametres.courants.fonctionnalites.acces_geolocalisation;
        evenement?.geolocation?.invoke(evenement.origin, autorise, false);
      })
  }

  @Builder
  voileChargement() {
    Column() {
      LoadingProgress()
        .color($r('app.color.couleur_primaire'))
        .width(42)
        .height(42)

      Text(Parametres.courants.identite.nom_affiche)
        .fontSize(14)
        .fontColor($r('app.color.couleur_primaire'))
        .margin({ top: 16 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.couleur_fond'))
  }

  @Builder
  boutonActions() {
    Column() {
      Text('...')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
    }
    .width(46)
    .height(46)
    .borderRadius(23)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.couleur_primaire'))
    .position({ right: 18, bottom: 34 })
    .shadow({ radius: 12, color: '#33000000', offsetY: 3 })
    .bindMenu(this.menuActions)
  }

  @Builder
  menuActions() {
    Menu() {
      MenuItem({ content: 'Rafraichir' })
        .onClick(() => this.rafraichir())

      if (Parametres.courants.fonctionnalites.partage_natif) {
        MenuItem({ content: 'Partager cette page' })
          .onClick(() => this.partagerPageCourante())
      }

      if (Parametres.courants.fonctionnalites.mode_hors_ligne) {
        MenuItem({ content: 'Pages enregistrees' })
          .onClick(() => this.afficherListeArchives())
      }

      MenuItem({ content: `A propos de ${Parametres.courants.identite.nom_affiche}` })
        .onClick(() => this.afficherAPropos())
    }
  }

  // ------------------------------------------------------------ navigation

  /** Geste retour materiel : on remonte l'historique du site d'abord. */
  onBackPress(): boolean {
    try {
      if (this.pageSecoursAffichee) {
        this.rafraichir();
        return true;
      }
      if (this.controleurWeb.accessBackward()) {
        this.vibrerCourt();
        this.controleurWeb.backward();
        return true;
      }
    } catch (erreur) {
      Journal.deboguer(`retour arriere impossible : ${erreur}`);
    }
    return false;
  }

  private rafraichir(): void {
    try {
      if (this.pageSecoursAffichee) {
        this.pageSecoursAffichee = false;
        this.controleurWeb.loadUrl(this.urlCourante);
        return;
      }
      this.controleurWeb.refresh();
    } catch (erreur) {
      Journal.alerter(`rafraichissement impossible : ${erreur}`);
    }
  }

  // ------------------------------------------------------------ hors ligne

  private archiverPageCourante(adresse: string): void {
    if (!Parametres.courants.fonctionnalites.mode_hors_ligne || !this.enLigne) {
      return;
    }
    // On recupere le HTML via la page elle-meme : ArkWeb n'expose pas
    // de lecture directe du document.
    this.controleurWeb.runJavaScript('document.documentElement.outerHTML')
      .then((html: string) => {
        const nettoye: string = this.retirerGuillemetsJson(html);
        const titre: string = this.controleurWeb.getTitle() ?? adresse;
        this.registre.cache.archiver(adresse, titre, nettoye);
        this.registre.cache.memoriserDerniereUrl(adresse);
      })
      .catch((erreur: Error) => {
        Journal.deboguer(`archivage ignore : ${erreur.message}`);
      });
  }

  private afficherSecoursHorsLigne(adresse: string): void {
    if (Parametres.courants.fonctionnalites.mode_hors_ligne) {
      const archive: string | undefined = this.registre.cache.lireHtml(adresse);
      if (archive !== undefined) {
        this.pageSecoursAffichee = true;
        this.premierRenduTermine = true;
        this.controleurWeb.loadData(archive, 'text/html', 'UTF-8', adresse, undefined);
        return;
      }
    }

    if (this.gabaritHorsLigne.length === 0) {
      return;
    }

    const apparence = Parametres.courants.apparence;
    const html: string = this.gabaritHorsLigne
      .replace(/\{\{COULEUR_PRIMAIRE\}\}/g, apparence.couleur_primaire)
      .replace(/\{\{COULEUR_FOND\}\}/g, apparence.couleur_fond_clair)
      .replace(/\{\{COULEUR_TEXTE\}\}/g, apparence.couleur_texte_clair)
      .replace(/\{\{COULEUR_DISCRETE\}\}/g, 'rgba(17, 22, 29, 0.62)')
      .replace(/\{\{COULEUR_BORDURE\}\}/g, 'rgba(17, 22, 29, 0.12)')
      .replace(/\{\{NOM_APPLICATION\}\}/g, Parametres.courants.identite.nom_affiche)
      .replace(/\{\{TITRE\}\}/g, 'Pas de connexion')
      .replace(/\{\{EXPLICATION\}\}/g,
        `${Parametres.courants.identite.nom_affiche} n'arrive pas a joindre le reseau. ` +
        'Les pages deja consultees restent lisibles hors ligne.')
      .replace(/\{\{CONSEILS\}\}/g, this.conseilsHorsLigne())
      .replace(/\{\{URL_DEMANDEE\}\}/g, adresse);

    this.pageSecoursAffichee = true;
    this.premierRenduTermine = true;
    this.controleurWeb.loadData(html, 'text/html', 'UTF-8', undefined, undefined);
  }

  /** Conseils de la page hors ligne, rendus en elements de liste. */
  private conseilsHorsLigne(): string {
    const lignes: string[] = [
      'Verifiez les donnees mobiles ou le Wi-Fi.',
      "Desactivez le mode avion s'il est actif.",
      'Changez de place : le signal varie beaucoup en interieur.'
    ];
    return lignes
      .map((ligne: string) =>
        `<li><span class="puce"></span><span>${ligne}</span></li>`)
      .join('');
  }

  private afficherListeArchives(): void {
    const pages: PageArchivee[] = this.registre.cache.pagesArchivees;
    if (pages.length === 0) {
      promptAction.showToast({ message: 'Aucune page enregistree' });
      return;
    }
    const titres: string = pages
      .slice(0, 8)
      .map((page: PageArchivee) => `- ${page.titre}`)
      .join('\n');

    promptAction.showDialog({
      title: `${pages.length} page(s) enregistree(s)`,
      message: titres,
      buttons: [
        { text: 'Vider', color: '#D64545' },
        { text: 'Fermer', color: '#666666' }
      ]
    }).then((reponse) => {
      if (reponse.index === 0) {
        this.registre.cache.viderTout();
      }
    }).catch((erreur: Error) => {
      Journal.deboguer(`dialogue ferme : ${erreur.message}`);
    });
  }

  // ------------------------------------------------------------ actions natives

  private partagerPageCourante(): void {
    if (!Parametres.courants.fonctionnalites.partage_natif) {
      return;
    }
    try {
      const donnees = new systemShare.SharedData({
        utd: uniformTypeDescriptor.UniformDataType.HYPERLINK,
        content: this.urlCourante,
        title: this.controleurWeb.getTitle() ?? Parametres.courants.identite.nom_affiche
      });
      const controleur = new systemShare.ShareController(donnees);
      const contexte = getContext(this) as common.UIAbilityContext;
      controleur.show(contexte, {
        selectionMode: systemShare.SelectionMode.BATCH,
        previewMode: systemShare.SharePreviewMode.DETAIL
      });
    } catch (erreur) {
      Journal.alerter(`partage impossible : ${erreur}`);
    }
  }

  private afficherAPropos(): void {
    const identite = Parametres.courants.identite;
    promptAction.showDialog({
      title: identite.nom_affiche,
      message: `Version ${identite.version_affichee}\n` +
               `${identite.editeur}\n${identite.ville}, ${identite.pays}`,
      buttons: [{ text: 'Fermer', color: '#666666' }]
    }).catch((erreur: Error) => {
      Journal.deboguer(`dialogue ferme : ${erreur.message}`);
    });
  }

  private vibrerCourt(): void {
    if (!Parametres.courants.fonctionnalites.vibration_retour_haptique) {
      return;
    }
    try {
      vibrator.startVibration(
        { type: 'time', duration: 18 },
        { usage: 'touch' }
      );
    } catch (erreur) {
      Journal.deboguer(`vibration refusee : ${erreur}`);
    }
  }

  // ------------------------------------------------------------ passerelle JavaScript

  /**
   * Objet expose au site sous le nom global CiFiNatif.
   * Le script injecte plus bas l'habille en window.CiFi, pour garder la
   * meme interface que la version Flutter et iOS.
   */
  private construirePasserelle(): Record<string, Function> {
    const registre: Registre = this.registre;

    return {
      appareilInformations: (): ReponsePasserelle => {
        return {
          succes: true,
          nom_application: Parametres.courants.identite.nom_affiche,
          version_application: Parametres.courants.identite.version_affichee,
          plateforme: 'harmonyos',
          en_ligne: registre.reseau.enLigne
        };
      },

      positionActuelle: (): ReponsePasserelle => {
        if (!registre.geolocalisation.aUnePosition) {
          registre.geolocalisation.positionActuelle();
          return { succes: false, erreur: 'position en cours d acquisition' };
        }
        return {
          succes: true,
          latitude: registre.geolocalisation.latitude,
          longitude: registre.geolocalisation.longitude
        };
      },

      vibrer: (duree: number): ReponsePasserelle => {
        if (!Parametres.courants.fonctionnalites.vibration_retour_haptique) {
          return { succes: false, erreur: 'vibration desactivee' };
        }
        try {
          vibrator.startVibration(
            { type: 'time', duration: duree > 0 ? duree : 40 },
            { usage: 'touch' }
          );
          return { succes: true };
        } catch (erreur) {
          return { succes: false, erreur: `${erreur}` };
        }
      },

      partager: (texte: string): ReponsePasserelle => {
        if (texte === undefined || texte.length === 0) {
          return { succes: false, erreur: 'texte vide' };
        }
        this.partagerPageCourante();
        return { succes: true };
      },

      notifier: (titre: string, corps: string): ReponsePasserelle => {
        registre.notifications.afficher(
          titre !== undefined && titre.length > 0
            ? titre
            : Parametres.courants.identite.nom_affiche,
          corps ?? ''
        );
        return { succes: true };
      },

      etatReseau: (): ReponsePasserelle => {
        return { succes: true, en_ligne: registre.reseau.releverMaintenant() };
      },

      pagesHorsLigne: (): ReponsePasserelle => {
        return { succes: true, pages: registre.cache.pagesArchivees };
      }
    };
  }

  /**
   * Fabrique window.CiFi dans la page. Interface identique a celle de la
   * version Flutter : le meme code de site fonctionne sur les trois
   * plateformes.
   */
  private injecterPasserelle(): void {
    const script: string = `
(function () {
  if (window.CiFi || !window.CiFiNatif) { return; }
  function enveloppe(nom) {
    return function () {
      var resultat = window.CiFiNatif[nom].apply(window.CiFiNatif, arguments);
      return Promise.resolve(resultat);
    };
  }
  window.CiFi = {
    disponible: true,
    appareilInformations: enveloppe('appareilInformations'),
    positionActuelle:     enveloppe('positionActuelle'),
    vibrer:               enveloppe('vibrer'),
    partager:             enveloppe('partager'),
    notifier:             enveloppe('notifier'),
    etatReseau:           enveloppe('etatReseau'),
    pagesHorsLigne:       enveloppe('pagesHorsLigne')
  };
  document.dispatchEvent(new Event('cifi-passerelle-prete'));
})();
`;
    this.controleurWeb.runJavaScript(script).catch((erreur: Error) => {
      Journal.deboguer(`injection de la passerelle ignoree : ${erreur.message}`);
    });
  }

  /**
   * runJavaScript renvoie une valeur JSON : une chaine arrive donc
   * entouree de guillemets et avec des echappements. On la restitue.
   */
  private retirerGuillemetsJson(brut: string): string {
    if (brut.length < 2 || !brut.startsWith('"')) {
      return brut;
    }
    try {
      return JSON.parse(brut) as string;
    } catch (erreur) {
      return brut;
    }
  }
}
