/**
 * Point d'entree de l'application HarmonyOS NEXT.
 *
 * Il charge les parametres, demande les autorisations declarees dans
 * module.json5, demarre les services, puis ouvre PageNavigateur.
 * Aucune logique metier ici.
 */

import { UIAbility, AbilityConstant, Want, common,
         abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { Parametres } from '../configuration/Parametres';
import { Journal } from '../services/Journal';
import { Registre } from '../services/Registre';

/** Autorisations demandees au premier lancement. */
const AUTORISATIONS: Permissions[] = [
  'ohos.permission.APPROXIMATELY_LOCATION',
  'ohos.permission.LOCATION',
  'ohos.permission.CAMERA',
  'ohos.permission.MICROPHONE'
];

export default class EntryAbility extends UIAbility {

  async onCreate(want: Want, parametresLancement: AbilityConstant.LaunchParam): Promise<void> {
    Journal.informer('creation de l ability principale');
    const contexte = this.context as common.UIAbilityContext;
    await Registre.courant.demarrer(contexte);
    await this.demanderAutorisations(contexte);
  }

  onDestroy(): void {
    Registre.courant.arreter();
    Journal.informer('ability principale detruite');
  }

  async onWindowStageCreate(scene: window.WindowStage): Promise<void> {
    try {
      // Plein ecran : le site occupe toute la surface, comme une
      // application native, pas comme un onglet de navigateur.
      const fenetre: window.Window = scene.getMainWindowSync();
      await fenetre.setWindowLayoutFullScreen(true);
    } catch (erreur) {
      Journal.alerter(`plein ecran refuse : ${erreur}`);
    }

    scene.loadContent('pages/PageNavigateur', (erreur) => {
      if (erreur.code) {
        Journal.erreur(`chargement de la page echoue : ${JSON.stringify(erreur)}`);
        return;
      }
      Journal.informer(
        `page chargee vers ${Parametres.courants.site_cible.url_accueil}`
      );
    });
  }

  onWindowStageDestroy(): void {
    Journal.deboguer('scene de fenetre detruite');
  }

  onForeground(): void {
    Journal.deboguer('application au premier plan');
  }

  onBackground(): void {
    Journal.deboguer('application en arriere-plan');
  }

  /**
   * Demande les autorisations dont les fonctionnalites activees ont besoin.
   * Un refus n'interrompt rien : le service concerne reste simplement muet.
   */
  private async demanderAutorisations(contexte: common.UIAbilityContext): Promise<void> {
    const fonctionnalites = Parametres.courants.fonctionnalites;
    const demandees: Permissions[] = AUTORISATIONS.filter((autorisation: Permissions) => {
      if (autorisation === 'ohos.permission.CAMERA') {
        return fonctionnalites.acces_camera;
      }
      if (autorisation === 'ohos.permission.MICROPHONE') {
        return fonctionnalites.acces_microphone;
      }
      return fonctionnalites.acces_geolocalisation ||
             fonctionnalites.notifications_geolocalisees;
    });

    if (demandees.length === 0) {
      return;
    }

    try {
      const gestionnaire = abilityAccessCtrl.createAtManager();
      await gestionnaire.requestPermissionsFromUser(contexte, demandees);
      Journal.informer(`autorisations demandees : ${demandees.join(', ')}`);
    } catch (erreur) {
      Journal.alerter(`demande d autorisations interrompue : ${erreur}`);
    }
  }
}
