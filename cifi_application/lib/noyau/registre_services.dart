import '../configuration/parametres_application.dart';
import '../services/service_cache_hors_ligne.dart';
import '../services/service_connectivite.dart';
import '../services/service_geolocalisation.dart';
import '../services/service_materiel.dart';
import '../services/service_notifications.dart';
import '../services/service_widget_accueil.dart';
import 'journal.dart';
import 'service.dart';

/// Assemble les services et les demarre une seule fois.
///
/// C'est le seul endroit du projet qui connait tous les services : les
/// ecrans recoivent le registre, jamais des dependances en vrac. Les
/// services entre eux ne communiquent que par rappel (ici : zone
/// franchie -> notification).
class RegistreServices {
  RegistreServices._({
    required this.parametres,
    required this.connectivite,
    required this.cache,
    required this.notifications,
    required this.materiel,
    required this.widgetAccueil,
    required this.geolocalisation,
  });

  final ParametresApplication parametres;
  final ServiceConnectivite connectivite;
  final ServiceCacheHorsLigne cache;
  final ServiceNotifications notifications;
  final ServiceMateriel materiel;
  final ServiceWidgetAccueil widgetAccueil;
  final ServiceGeolocalisation geolocalisation;

  static RegistreServices? _instance;

  static RegistreServices get courant {
    final RegistreServices? instance = _instance;
    if (instance == null) {
      throw StateError('RegistreServices.demarrer() n a pas ete appele.');
    }
    return instance;
  }

  /// Construit puis demarre tous les services actifs.
  /// Un service en echec n'empeche jamais les autres de demarrer :
  /// l'application doit rester utilisable meme sans Firebase ni GPS.
  static Future<RegistreServices> demarrer(
    ParametresApplication parametres,
  ) async {
    final ServiceNotifications notifications = ServiceNotifications(
      parametres.fonctionnalites,
      parametres.notifications,
    );

    final RegistreServices registre = RegistreServices._(
      parametres: parametres,
      connectivite: ServiceConnectivite(),
      cache: ServiceCacheHorsLigne(parametres.fonctionnalites),
      notifications: notifications,
      materiel: ServiceMateriel(parametres.fonctionnalites),
      widgetAccueil: ServiceWidgetAccueil(
        parametres.fonctionnalites,
        parametres.identite,
      ),
      geolocalisation: ServiceGeolocalisation(
        parametres.fonctionnalites,
        parametres.zones,
        surFranchissement: (FranchissementZone evenement) {
          notifications.afficher(
            titre: evenement.zone.libelle.isEmpty
                ? parametres.identite.nomAffiche
                : evenement.zone.libelle,
            corps: evenement.message,
            urlAssociee: parametres.site.urlAccueil,
          );
        },
      ),
    );

    await registre._demarrerTout();
    _instance = registre;
    return registre;
  }

  Future<void> _demarrerTout() async {
    final List<Service> services = <Service>[
      connectivite,
      cache,
      materiel,
      notifications,
      widgetAccueil,
      geolocalisation,
    ];

    for (final Service service in services) {
      if (!service.estActif) {
        Journal.deboguer('service ${service.nom} desactive par configuration');
        continue;
      }
      try {
        await service.demarrer();
      } catch (erreur, pile) {
        Journal.erreur('service ${service.nom} non demarre', erreur, pile);
      }
    }
  }

  Future<void> arreterTout() async {
    for (final Service service in <Service>[connectivite, geolocalisation]) {
      try {
        await service.arreter();
      } catch (erreur) {
        Journal.alerter('arret du service ${service.nom} imparfait : $erreur');
      }
    }
  }
}
