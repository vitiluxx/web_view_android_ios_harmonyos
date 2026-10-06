/**
 * Lecture du fichier de parametres unique.
 *
 * Le fichier vit dans entry/src/main/resources/rawfile/cifi_parametres.json
 * Il est recopie automatiquement depuis
 *     configuration/cifi_parametres.json
 * par scripts/appliquer_configuration.ps1
 *
 * Aucune autre classe ne lit ce fichier : tout passe par Parametres.courants.
 */

import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { Journal } from '../services/Journal';

export interface Identite {
  nom_affiche: string;
  version_affichee: string;
  editeur: string;
  ville: string;
  pays: string;
}

export interface SiteCible {
  url_accueil: string;
  domaines_autorises: string[];
  ouvrir_domaines_externes_dans_navigateur: boolean;
  agent_utilisateur_suffixe: string;
  autoriser_zoom: boolean;
}

export interface Apparence {
  couleur_primaire: string;
  couleur_secondaire: string;
  couleur_fond_clair: string;
  couleur_fond_sombre: string;
  couleur_texte_clair: string;
  couleur_texte_sombre: string;
  couleur_splash: string;
}

export interface Fonctionnalites {
  mode_hors_ligne: boolean;
  duree_cache_jours: number;
  notifications_push: boolean;
  notifications_geolocalisees: boolean;
  rayon_geofence_metres: number;
  acces_camera: boolean;
  acces_microphone: boolean;
  acces_geolocalisation: boolean;
  acces_fichiers: boolean;
  vibration_retour_haptique: boolean;
  partage_natif: boolean;
  tirer_pour_rafraichir: boolean;
  barre_progression_chargement: boolean;
}

export interface ZoneGeographique {
  identifiant: string;
  libelle: string;
  latitude: number;
  longitude: number;
  rayon_metres: number;
  message_entree: string;
  message_sortie: string;
}

export interface ReglagesNotifications {
  canal_identifiant: string;
  canal_libelle: string;
  canal_description: string;
}

export interface FichierParametres {
  identite: Identite;
  site_cible: SiteCible;
  apparence: Apparence;
  fonctionnalites: Fonctionnalites;
  geofences: ZoneGeographique[];
  notifications: ReglagesNotifications;
}

/** Valeurs de repli : l'application demarre meme si le fichier manque. */
const PARAMETRES_DE_REPLI: FichierParametres = {
  identite: {
    nom_affiche: 'CiFi Tech',
    version_affichee: '1.0.0',
    editeur: 'CiFi',
    ville: "N'Djamena",
    pays: 'Tchad'
  },
  site_cible: {
    url_accueil: 'https://www.cifi.td',
    domaines_autorises: ['cifi.td', 'www.cifi.td'],
    ouvrir_domaines_externes_dans_navigateur: true,
    agent_utilisateur_suffixe: 'CiFiApp/1.0',
    autoriser_zoom: false
  },
  apparence: {
    couleur_primaire: '#0B5FFF',
    couleur_secondaire: '#00B894',
    couleur_fond_clair: '#FFFFFF',
    couleur_fond_sombre: '#0E1116',
    couleur_texte_clair: '#11161D',
    couleur_texte_sombre: '#EDF1F7',
    couleur_splash: '#0B5FFF'
  },
  fonctionnalites: {
    mode_hors_ligne: true,
    duree_cache_jours: 7,
    notifications_push: true,
    notifications_geolocalisees: true,
    rayon_geofence_metres: 500,
    acces_camera: true,
    acces_microphone: true,
    acces_geolocalisation: true,
    acces_fichiers: true,
    vibration_retour_haptique: true,
    partage_natif: true,
    tirer_pour_rafraichir: true,
    barre_progression_chargement: true
  },
  geofences: [],
  notifications: {
    canal_identifiant: 'cifi_canal_principal',
    canal_libelle: 'Notifications CiFi',
    canal_description: 'Alertes et informations CiFi Tech'
  }
};

export class Parametres {
  private static instance: FichierParametres = PARAMETRES_DE_REPLI;
  private static chargement: boolean = false;

  static get courants(): FichierParametres {
    return Parametres.instance;
  }

  static get charges(): boolean {
    return Parametres.chargement;
  }

  /** Lit le rawfile une seule fois, au demarrage de l'ability. */
  static async charger(contexte: common.UIAbilityContext): Promise<void> {
    if (Parametres.chargement) {
      return;
    }
    try {
      const octets: Uint8Array =
        contexte.resourceManager.getRawFileContentSync('cifi_parametres.json');
      const decodeur = util.TextDecoder.create('utf-8');
      const texte: string = decodeur.decodeToString(octets);
      Parametres.instance = JSON.parse(texte) as FichierParametres;
      Parametres.chargement = true;
      Journal.informer('parametres charges depuis rawfile');
    } catch (erreur) {
      Journal.alerter(`parametres illisibles, valeurs de repli utilisees : ${erreur}`);
      Parametres.instance = PARAMETRES_DE_REPLI;
      Parametres.chargement = true;
    }
  }

  /** Vrai si l'adresse appartient au site cible. */
  static estInterne(adresse: string): boolean {
    const site: SiteCible = Parametres.instance.site_cible;
    const hote: string = Parametres.extraireHote(adresse);
    if (hote.length === 0) {
      return true;
    }
    for (const domaine of site.domaines_autorises) {
      const compare: string = domaine.toLowerCase();
      if (hote === compare || hote.endsWith(`.${compare}`)) {
        return true;
      }
    }
    return false;
  }

  /** Extraction d'hote sans URL() : l'API n'est pas garantie en ArkTS. */
  static extraireHote(adresse: string): string {
    const separateur: number = adresse.indexOf('://');
    if (separateur < 0) {
      return '';
    }
    const reste: string = adresse.substring(separateur + 3);
    const fin: number = reste.search(/[/?#:]/);
    const hote: string = fin < 0 ? reste : reste.substring(0, fin);
    return hote.toLowerCase();
  }
}
