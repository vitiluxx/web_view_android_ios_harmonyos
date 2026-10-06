/**
 * Notifications locales HarmonyOS.
 *
 * Les notifications distantes passent par Huawei Push Kit, qui exige un
 * compte console et un fichier agconnect-services.json : la demarche est
 * decrite dans docs/05_fonctionnalites.md. Ce service couvre tout ce qui
 * ne demande aucun serveur : alertes de zone, fin de telechargement,
 * messages declenches par le site.
 */

import { notificationManager } from '@kit.NotificationKit';
import { Parametres } from '../configuration/Parametres';
import { Journal } from './Journal';

export class ServiceNotifications {
  private autorise: boolean = false;
  private compteur: number = 1;

  /** Demande l'autorisation une seule fois, au demarrage. */
  async demarrer(): Promise<void> {
    if (!Parametres.courants.fonctionnalites.notifications_push) {
      Journal.deboguer('notifications desactivees par configuration');
      return;
    }
    try {
      this.autorise = await notificationManager.isNotificationEnabled();
      if (!this.autorise) {
        await notificationManager.requestEnableNotification();
        this.autorise = await notificationManager.isNotificationEnabled();
      }
      Journal.informer(`notifications autorisees : ${this.autorise}`);
    } catch (erreur) {
      Journal.alerter(`autorisation de notification refusee : ${erreur}`);
      this.autorise = false;
    }
  }

  /** Publie une notification simple avec titre et texte. */
  async afficher(titre: string, corps: string): Promise<void> {
    if (!this.autorise) {
      Journal.deboguer('notification ignoree : autorisation absente');
      return;
    }

    const requete: notificationManager.NotificationRequest = {
      id: this.compteur++,
      content: {
        notificationContentType:
          notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: titre,
          text: corps
        }
      }
    };

    try {
      await notificationManager.publish(requete);
      Journal.deboguer(`notification publiee : ${titre}`);
    } catch (erreur) {
      Journal.alerter(`publication de notification echouee : ${erreur}`);
    }
  }
}
