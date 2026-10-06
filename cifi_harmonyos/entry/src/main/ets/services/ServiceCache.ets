/**
 * Mode hors ligne HarmonyOS.
 *
 * Archive le code HTML des pages visitees dans le dossier prive de
 * l'application, et le restitue quand le reseau manque.
 * Equivalent fonctionnel de
 *     cifi_application/lib/services/service_cache_hors_ligne.dart
 */

import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';
import { Parametres } from '../configuration/Parametres';
import { Journal } from './Journal';

export interface PageArchivee {
  url: string;
  titre: string;
  nom_fichier: string;
  horodatage: number;
}

const NOM_PREFERENCES: string = 'cifi_cache';
const CLE_INDEX: string = 'index_pages_archivees';
const CLE_DERNIERE_URL: string = 'derniere_url';
const NOMBRE_MAXIMUM_PAGES: number = 40;
const MILLISECONDES_PAR_JOUR: number = 86400000;

export class ServiceCache {
  private dossier: string = '';
  private magasin: preferences.Preferences | undefined = undefined;
  private index: PageArchivee[] = [];

  async demarrer(contexte: common.UIAbilityContext): Promise<void> {
    if (!Parametres.courants.fonctionnalites.mode_hors_ligne) {
      Journal.deboguer('mode hors ligne desactive par configuration');
      return;
    }

    try {
      this.dossier = `${contexte.filesDir}/pages_cifi`;
      if (!fileIo.accessSync(this.dossier)) {
        fileIo.mkdirSync(this.dossier);
      }

      this.magasin = await preferences.getPreferences(contexte, NOM_PREFERENCES);
      this.chargerIndex();
      await this.purgerPagesExpirees();

      Journal.informer(
        `cache hors ligne pret : ${this.index.length} page(s), dossier ${this.dossier}`
      );
    } catch (erreur) {
      Journal.erreur(`cache hors ligne indisponible : ${erreur}`);
    }
  }

  get pagesArchivees(): PageArchivee[] {
    return this.index.slice().reverse();
  }

  // ----------------------------------------------------------- ecriture

  async archiver(url: string, titre: string, html: string): Promise<void> {
    if (this.magasin === undefined || html.trim().length === 0) {
      return;
    }
    try {
      const nomFichier: string = `${this.empreinte(url)}.html`;
      const chemin: string = `${this.dossier}/${nomFichier}`;

      const fichier = fileIo.openSync(
        chemin,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
      );
      fileIo.writeSync(fichier.fd, html);
      fileIo.closeSync(fichier);

      this.index = this.index.filter((page: PageArchivee) => page.url !== url);
      this.index.push({
        url: url,
        titre: titre.length === 0 ? url : titre,
        nom_fichier: nomFichier,
        horodatage: Date.now()
      });

      while (this.index.length > NOMBRE_MAXIMUM_PAGES) {
        const retiree: PageArchivee | undefined = this.index.shift();
        if (retiree !== undefined) {
          this.supprimerFichier(retiree);
        }
      }

      await this.enregistrerIndex();
      Journal.deboguer(`page archivee : ${url}`);
    } catch (erreur) {
      Journal.alerter(`archivage impossible pour ${url} : ${erreur}`);
    }
  }

  async memoriserDerniereUrl(url: string): Promise<void> {
    if (this.magasin === undefined) {
      return;
    }
    await this.magasin.put(CLE_DERNIERE_URL, url);
    await this.magasin.flush();
  }

  // ----------------------------------------------------------- lecture

  lireHtml(url: string): string | undefined {
    const page: PageArchivee | undefined = this.trouver(url);
    if (page === undefined) {
      return undefined;
    }
    const chemin: string = `${this.dossier}/${page.nom_fichier}`;
    try {
      if (!fileIo.accessSync(chemin)) {
        return undefined;
      }
      return fileIo.readTextSync(chemin);
    } catch (erreur) {
      Journal.alerter(`lecture du cache impossible : ${erreur}`);
      return undefined;
    }
  }

  estArchivee(url: string): boolean {
    return this.trouver(url) !== undefined;
  }

  // ----------------------------------------------------------- entretien

  async viderTout(): Promise<void> {
    for (const page of this.index) {
      this.supprimerFichier(page);
    }
    this.index = [];
    await this.enregistrerIndex();
    Journal.informer('cache hors ligne vide');
  }

  private async purgerPagesExpirees(): Promise<void> {
    const jours: number = Parametres.courants.fonctionnalites.duree_cache_jours;
    const limite: number = Date.now() - jours * MILLISECONDES_PAR_JOUR;

    const conservees: PageArchivee[] = [];
    let supprimees: number = 0;

    for (const page of this.index) {
      if (page.horodatage < limite) {
        this.supprimerFichier(page);
        supprimees++;
      } else {
        conservees.push(page);
      }
    }

    if (supprimees === 0) {
      return;
    }
    this.index = conservees;
    await this.enregistrerIndex();
    Journal.informer(`${supprimees} page(s) expiree(s) supprimee(s)`);
  }

  // ----------------------------------------------------------- interne

  private trouver(url: string): PageArchivee | undefined {
    return this.index.find((page: PageArchivee) => page.url === url);
  }

  private supprimerFichier(page: PageArchivee): void {
    const chemin: string = `${this.dossier}/${page.nom_fichier}`;
    try {
      if (fileIo.accessSync(chemin)) {
        fileIo.unlinkSync(chemin);
      }
    } catch (erreur) {
      Journal.deboguer(`suppression impossible : ${erreur}`);
    }
  }

  private chargerIndex(): void {
    if (this.magasin === undefined) {
      return;
    }
    const brut: string = this.magasin.getSync(CLE_INDEX, '') as string;
    if (brut.length === 0) {
      return;
    }
    try {
      this.index = JSON.parse(brut) as PageArchivee[];
    } catch (erreur) {
      Journal.alerter(`index du cache illisible, remise a zero : ${erreur}`);
      this.index = [];
    }
  }

  private async enregistrerIndex(): Promise<void> {
    if (this.magasin === undefined) {
      return;
    }
    await this.magasin.put(CLE_INDEX, JSON.stringify(this.index));
    await this.magasin.flush();
  }

  /** Nom de fichier stable et sans caractere interdit, derive de l'URL. */
  private empreinte(url: string): string {
    let accumulateur: number = 7;
    for (let position: number = 0; position < url.length; position++) {
      accumulateur = (accumulateur * 31 + url.charCodeAt(position)) & 0x7fffffff;
    }
    return `page_${accumulateur}`;
  }
}
