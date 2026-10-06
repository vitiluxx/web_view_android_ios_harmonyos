/**
 * Assemble les services et les demarre une seule fois.
 *
 * Equivalent de cifi_application/lib/noyau/registre_services.dart :
 * c'est le seul endroit qui connait tous les services. La page
 * PageNavigateur lit le registre, jamais les services separement.
 */

import { common } from '@kit.AbilityKit';
import { Parametres } from '../configuration/Parametres';
import { Journal } from './Journal';
import { ServiceCache } from './ServiceCache';
import { ServiceGeolocalisation, FranchissementZone } from './ServiceGeolocalisation';
import { ServiceNotifications } from './ServiceNotifications';
import { ServiceReseau } from './ServiceReseau';

export class Registre {
  private static instance: Registre | undefined = undefined;

  readonly reseau: ServiceReseau = new ServiceReseau();
  readonly cache: ServiceCache = new ServiceCache();
  readonly notifications: ServiceNotifications = new ServiceNotifications();
  readonly geolocalisation: ServiceGeolocalisation = new ServiceGeolocalisation();

  private pret: boolean = false;

  static get courant(): Registre {
    if (Registre.instance === undefined) {
      Registre.instance = new Registre();
    }
    return Registre.instance;
  }

  get estPret(): boolean {
    return this.pret;
  }

  /**
   * Demarre les services. Un service en echec n'empeche pas les autres :
   * l'application doit rester utilisable sans GPS ni notifications.
   */
  async demarrer(contexte: common.UIAbilityContext): Promise<void> {
    if (this.pret) {
      return;
    }

    await Parametres.charger(contexte);

    try {
      await this.cache.demarrer(contexte);
    } catch (erreur) {
      Journal.erreur(`service cache non demarre : ${erreur}`);
    }

    try {
      await this.notifications.demarrer();
    } catch (erreur) {
      Journal.erreur(`service notifications non demarre : ${erreur}`);
    }

    try {
      await this.geolocalisation.demarrer((evenement: FranchissementZone) => {
        const titre: string = evenement.zone.libelle.length > 0
          ? evenement.zone.libelle
          : Parametres.courants.identite.nom_affiche;
        this.notifications.afficher(titre, evenement.message);
      });
    } catch (erreur) {
      Journal.erreur(`service geolocalisation non demarre : ${erreur}`);
    }

    this.pret = true;
    Journal.informer('registre des services pret');
  }

  arreter(): void {
    this.reseau.arreter();
    this.geolocalisation.arreter();
    this.pret = false;
  }
}
