/**
 * Journal unique du module HarmonyOS.
 * Un seul domaine et un seul prefixe : les traces sont filtrables
 * dans DevEco avec le filtre "CiFi".
 */

import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAINE: number = 0xC1F1;
const ETIQUETTE: string = 'CiFi';

export class Journal {
  static deboguer(message: string): void {
    hilog.debug(DOMAINE, ETIQUETTE, '%{public}s', message);
  }

  static informer(message: string): void {
    hilog.info(DOMAINE, ETIQUETTE, '%{public}s', message);
  }

  static alerter(message: string): void {
    hilog.warn(DOMAINE, ETIQUETTE, '%{public}s', message);
  }

  static erreur(message: string): void {
    hilog.error(DOMAINE, ETIQUETTE, '%{public}s', message);
  }
}
