/**
 * Surveillance de la connexion reseau.
 *
 * Le service ne touche a aucune interface : il appelle le rappel fourni
 * au demarrage. C'est la page qui decide quoi afficher.
 */

import { connection } from '@kit.NetworkKit';
import { Journal } from './Journal';

export type RappelEtatReseau = (enLigne: boolean) => void;

export class ServiceReseau {
  private observateur: connection.NetConnection | undefined = undefined;
  private rappel: RappelEtatReseau | undefined = undefined;
  private enLigneCourant: boolean = true;

  get enLigne(): boolean {
    return this.enLigneCourant;
  }

  /** Branche la surveillance et notifie immediatement l'etat courant. */
  demarrer(rappel: RappelEtatReseau): void {
    this.rappel = rappel;
    this.releverMaintenant();

    try {
      this.observateur = connection.createNetConnection();
      this.observateur.register((erreur) => {
        if (erreur) {
          Journal.alerter(`surveillance reseau refusee : ${JSON.stringify(erreur)}`);
        }
      });
      this.observateur.on('netAvailable', () => this.publier(true));
      this.observateur.on('netLost', () => this.publier(false));
      this.observateur.on('netUnavailable', () => this.publier(false));
      Journal.informer('surveillance reseau active');
    } catch (erreur) {
      Journal.alerter(`surveillance reseau indisponible : ${erreur}`);
    }
  }

  arreter(): void {
    try {
      this.observateur?.unregister(() => {});
    } catch (erreur) {
      Journal.deboguer(`arret de la surveillance imparfait : ${erreur}`);
    }
    this.observateur = undefined;
    this.rappel = undefined;
  }

  /** Releve ponctuel, utilise au demarrage et sur demande du site. */
  releverMaintenant(): boolean {
    try {
      const capacites = connection.getDefaultNetSync();
      this.enLigneCourant = capacites !== undefined && capacites.netId !== 0;
    } catch (erreur) {
      Journal.alerter(`etat reseau inconnu, on suppose en ligne : ${erreur}`);
      this.enLigneCourant = true;
    }
    return this.enLigneCourant;
  }

  private publier(enLigne: boolean): void {
    if (this.enLigneCourant === enLigne) {
      return;
    }
    this.enLigneCourant = enLigne;
    Journal.informer(enLigne ? 'reseau retrouve' : 'reseau perdu');
    this.rappel?.(enLigne);
  }
}
