/**
 * Geolocalisation et notifications geolocalisees.
 *
 * Meme principe que la version Flutter : le service detecte les entrees
 * et sorties de zone, puis appelle un rappel. Il ne fabrique aucune
 * notification lui-meme.
 */

import { geoLocationManager } from '@kit.LocationKit';
import { ZoneGeographique, Parametres } from '../configuration/Parametres';
import { Journal } from './Journal';

export enum SensFranchissement {
  ENTREE = 'entree',
  SORTIE = 'sortie'
}

export interface FranchissementZone {
  zone: ZoneGeographique;
  sens: SensFranchissement;
  message: string;
}

export type RappelFranchissement = (evenement: FranchissementZone) => void;

/** Distance en metres entre deux points (formule de haversine). */
export function distanceEnMetres(
  latitudeDepart: number,
  longitudeDepart: number,
  latitudeArrivee: number,
  longitudeArrivee: number
): number {
  const RAYON_TERRESTRE: number = 6371000;
  const enRadians = (degres: number): number => (degres * Math.PI) / 180;

  const deltaLatitude: number = enRadians(latitudeArrivee - latitudeDepart);
  const deltaLongitude: number = enRadians(longitudeArrivee - longitudeDepart);

  const a: number =
    Math.sin(deltaLatitude / 2) * Math.sin(deltaLatitude / 2) +
    Math.cos(enRadians(latitudeDepart)) *
      Math.cos(enRadians(latitudeArrivee)) *
      Math.sin(deltaLongitude / 2) *
      Math.sin(deltaLongitude / 2);

  return 2 * RAYON_TERRESTRE * Math.asin(Math.min(1, Math.sqrt(a)));
}

export class ServiceGeolocalisation {
  private rappel: RappelFranchissement | undefined = undefined;
  private zonesOccupees: Set<string> = new Set<string>();
  private surveillanceActive: boolean = false;
  private derniereLatitude: number = 0;
  private derniereLongitude: number = 0;
  private positionConnue: boolean = false;

  async demarrer(rappel: RappelFranchissement): Promise<void> {
    const fonctionnalites = Parametres.courants.fonctionnalites;
    if (!fonctionnalites.acces_geolocalisation &&
        !fonctionnalites.notifications_geolocalisees) {
      Journal.deboguer('geolocalisation desactivee par configuration');
      return;
    }

    this.rappel = rappel;

    if (!fonctionnalites.notifications_geolocalisees ||
        Parametres.courants.geofences.length === 0) {
      Journal.informer('geolocalisation active sans surveillance de zone');
      return;
    }

    const requete: geoLocationManager.ContinuousLocationRequest = {
      interval: 60,
      locationScenario:
        geoLocationManager.UserActivityScenario.NAVIGATION
    };

    try {
      geoLocationManager.on('locationChange', requete,
        (position: geoLocationManager.Location) => this.traiterPosition(position));
      this.surveillanceActive = true;
      Journal.informer(
        `surveillance de ${Parametres.courants.geofences.length} zone(s) demarree`
      );
    } catch (erreur) {
      Journal.alerter(`surveillance de position impossible : ${erreur}`);
    }
  }

  arreter(): void {
    if (!this.surveillanceActive) {
      return;
    }
    try {
      geoLocationManager.off('locationChange');
    } catch (erreur) {
      Journal.deboguer(`arret de la surveillance imparfait : ${erreur}`);
    }
    this.surveillanceActive = false;
  }

  /** Releve ponctuel pour la passerelle JavaScript. */
  async positionActuelle(): Promise<geoLocationManager.Location | undefined> {
    try {
      const position: geoLocationManager.Location =
        await geoLocationManager.getCurrentLocation();
      this.memoriser(position);
      return position;
    } catch (erreur) {
      Journal.alerter(`position actuelle indisponible : ${erreur}`);
      return undefined;
    }
  }

  get latitude(): number {
    return this.derniereLatitude;
  }

  get longitude(): number {
    return this.derniereLongitude;
  }

  get aUnePosition(): boolean {
    return this.positionConnue;
  }

  private memoriser(position: geoLocationManager.Location): void {
    this.derniereLatitude = position.latitude;
    this.derniereLongitude = position.longitude;
    this.positionConnue = true;
  }

  private traiterPosition(position: geoLocationManager.Location): void {
    this.memoriser(position);

    const rayonParDefaut: number =
      Parametres.courants.fonctionnalites.rayon_geofence_metres;

    for (const zone of Parametres.courants.geofences) {
      const rayon: number = zone.rayon_metres > 0 ? zone.rayon_metres : rayonParDefaut;
      const distance: number = distanceEnMetres(
        position.latitude,
        position.longitude,
        zone.latitude,
        zone.longitude
      );

      const dedans: boolean = distance <= rayon;
      const etaitDedans: boolean = this.zonesOccupees.has(zone.identifiant);

      if (dedans && !etaitDedans) {
        this.zonesOccupees.add(zone.identifiant);
        this.publier(zone, SensFranchissement.ENTREE, zone.message_entree);
      } else if (!dedans && etaitDedans) {
        this.zonesOccupees.delete(zone.identifiant);
        this.publier(zone, SensFranchissement.SORTIE, zone.message_sortie);
      }
    }
  }

  private publier(
    zone: ZoneGeographique,
    sens: SensFranchissement,
    message: string
  ): void {
    if (message.trim().length === 0) {
      return;
    }
    Journal.informer(`zone ${zone.identifiant} : ${sens}`);
    this.rappel?.({ zone: zone, sens: sens, message: message });
  }
}
