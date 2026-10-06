import 'dart:convert';

import 'package:flutter/services.dart';

/// Chemin de l'unique fichier de parametres embarque dans l'application.
/// Copie automatiquement depuis configuration/cifi_parametres.json
/// par scripts/appliquer_configuration.ps1 (ou .sh).
const String cheminAssetParametres = 'assets/configuration/cifi_parametres.json';

/// Identite legale et technique de l'application compilee.
class IdentiteApplication {
  const IdentiteApplication({
    required this.nomAffiche,
    required this.versionAffichee,
    required this.editeur,
    required this.ville,
    required this.pays,
  });

  final String nomAffiche;
  final String versionAffichee;
  final String editeur;
  final String ville;
  final String pays;

  factory IdentiteApplication.depuisCarte(Map<String, dynamic> carte) {
    return IdentiteApplication(
      nomAffiche: carte['nom_affiche'] as String? ?? 'CiFi Tech',
      versionAffichee: carte['version_affichee'] as String? ?? '1.0.0',
      editeur: carte['editeur'] as String? ?? 'CiFi',
      ville: carte['ville'] as String? ?? '',
      pays: carte['pays'] as String? ?? '',
    );
  }
}

/// Site web affiche par la coque native.
class SiteCible {
  const SiteCible({
    required this.urlAccueil,
    required this.domainesAutorises,
    required this.ouvrirDomainesExternesDansNavigateur,
    required this.agentUtilisateurSuffixe,
    required this.autoriserZoom,
    required this.autoriserSelectionTexte,
  });

  final String urlAccueil;
  final List<String> domainesAutorises;
  final bool ouvrirDomainesExternesDansNavigateur;
  final String agentUtilisateurSuffixe;
  final bool autoriserZoom;
  final bool autoriserSelectionTexte;

  factory SiteCible.depuisCarte(Map<String, dynamic> carte) {
    return SiteCible(
      urlAccueil: carte['url_accueil'] as String? ?? 'https://www.cifi.td',
      domainesAutorises:
          (carte['domaines_autorises'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic element) => element.toString().toLowerCase())
              .toList(growable: false),
      ouvrirDomainesExternesDansNavigateur:
          carte['ouvrir_domaines_externes_dans_navigateur'] as bool? ?? true,
      agentUtilisateurSuffixe:
          carte['agent_utilisateur_suffixe'] as String? ?? 'CiFiApp/1.0',
      autoriserZoom: carte['autoriser_zoom'] as bool? ?? false,
      autoriserSelectionTexte:
          carte['autoriser_selection_texte'] as bool? ?? true,
    );
  }

  /// Vrai si [url] appartient a l'un des domaines declares comme internes.
  bool estInterne(Uri url) {
    final String hote = url.host.toLowerCase();
    if (hote.isEmpty) {
      return true;
    }
    for (final String domaine in domainesAutorises) {
      if (hote == domaine || hote.endsWith('.$domaine')) {
        return true;
      }
    }
    return false;
  }
}

/// Couleurs et comportement visuel, exprimes en valeurs brutes.
class Apparence {
  const Apparence({
    required this.couleurPrimaire,
    required this.couleurSecondaire,
    required this.couleurFondClair,
    required this.couleurFondSombre,
    required this.couleurTexteClair,
    required this.couleurTexteSombre,
    required this.couleurSplash,
    required this.modeSombreAutomatique,
    required this.orientationVerrouillee,
  });

  final String couleurPrimaire;
  final String couleurSecondaire;
  final String couleurFondClair;
  final String couleurFondSombre;
  final String couleurTexteClair;
  final String couleurTexteSombre;
  final String couleurSplash;
  final bool modeSombreAutomatique;

  /// Valeurs acceptees : aucune, portrait, paysage.
  final String orientationVerrouillee;

  factory Apparence.depuisCarte(Map<String, dynamic> carte) {
    return Apparence(
      couleurPrimaire: carte['couleur_primaire'] as String? ?? '#0B5FFF',
      couleurSecondaire: carte['couleur_secondaire'] as String? ?? '#00B894',
      couleurFondClair: carte['couleur_fond_clair'] as String? ?? '#FFFFFF',
      couleurFondSombre: carte['couleur_fond_sombre'] as String? ?? '#0E1116',
      couleurTexteClair: carte['couleur_texte_clair'] as String? ?? '#11161D',
      couleurTexteSombre: carte['couleur_texte_sombre'] as String? ?? '#EDF1F7',
      couleurSplash: carte['couleur_splash'] as String? ?? '#0B5FFF',
      modeSombreAutomatique: carte['mode_sombre_automatique'] as bool? ?? true,
      orientationVerrouillee:
          carte['orientation_verrouillee'] as String? ?? 'aucune',
    );
  }
}

/// Interrupteurs des fonctionnalites a valeur ajoutee.
/// Chaque drapeau desactive proprement le service correspondant.
class Fonctionnalites {
  const Fonctionnalites(this._drapeaux, this._nombres);

  final Map<String, bool> _drapeaux;
  final Map<String, int> _nombres;

  factory Fonctionnalites.depuisCarte(Map<String, dynamic> carte) {
    final Map<String, bool> drapeaux = <String, bool>{};
    final Map<String, int> nombres = <String, int>{};
    carte.forEach((String cle, dynamic valeur) {
      if (valeur is bool) {
        drapeaux[cle] = valeur;
      } else if (valeur is num) {
        nombres[cle] = valeur.toInt();
      }
    });
    return Fonctionnalites(drapeaux, nombres);
  }

  bool actif(String cle) => _drapeaux[cle] ?? false;

  int nombre(String cle, int parDefaut) => _nombres[cle] ?? parDefaut;

  bool get modeHorsLigne => actif('mode_hors_ligne');
  bool get notificationsPush => actif('notifications_push');
  bool get notificationsGeolocalisees => actif('notifications_geolocalisees');
  bool get accesCamera => actif('acces_camera');
  bool get accesMicrophone => actif('acces_microphone');
  bool get accesGalerie => actif('acces_galerie');
  bool get accesGeolocalisation => actif('acces_geolocalisation');
  bool get accesFichiers => actif('acces_fichiers');
  bool get vibration => actif('vibration_retour_haptique');
  bool get partageNatif => actif('partage_natif');
  bool get scannerQr => actif('scanner_qr');
  bool get widgetEcranAccueil => actif('widget_ecran_accueil');
  bool get tirerPourRafraichir => actif('tirer_pour_rafraichir');
  bool get barreProgression => actif('barre_progression_chargement');
  bool get navigationGestesRetour => actif('navigation_gestes_retour');

  int get dureeCacheJours => nombre('duree_cache_jours', 7);
  int get rayonGeofenceMetres => nombre('rayon_geofence_metres', 500);
}

/// Zone geographique declenchant une notification a l'entree ou a la sortie.
class ZoneGeographique {
  const ZoneGeographique({
    required this.identifiant,
    required this.libelle,
    required this.latitude,
    required this.longitude,
    required this.rayonMetres,
    required this.messageEntree,
    required this.messageSortie,
  });

  final String identifiant;
  final String libelle;
  final double latitude;
  final double longitude;
  final double rayonMetres;
  final String messageEntree;
  final String messageSortie;

  factory ZoneGeographique.depuisCarte(Map<String, dynamic> carte) {
    return ZoneGeographique(
      identifiant: carte['identifiant'] as String? ?? 'zone',
      libelle: carte['libelle'] as String? ?? '',
      latitude: (carte['latitude'] as num? ?? 0).toDouble(),
      longitude: (carte['longitude'] as num? ?? 0).toDouble(),
      rayonMetres: (carte['rayon_metres'] as num? ?? 500).toDouble(),
      messageEntree: carte['message_entree'] as String? ?? '',
      messageSortie: carte['message_sortie'] as String? ?? '',
    );
  }
}

/// Reglages du canal de notification.
class ReglagesNotifications {
  const ReglagesNotifications({
    required this.canalIdentifiant,
    required this.canalLibelle,
    required this.canalDescription,
    required this.sujetDiffusion,
  });

  final String canalIdentifiant;
  final String canalLibelle;
  final String canalDescription;
  final String sujetDiffusion;

  factory ReglagesNotifications.depuisCarte(Map<String, dynamic> carte) {
    return ReglagesNotifications(
      canalIdentifiant:
          carte['canal_identifiant'] as String? ?? 'cifi_canal_principal',
      canalLibelle: carte['canal_libelle'] as String? ?? 'Notifications CiFi',
      canalDescription: carte['canal_description'] as String? ?? '',
      sujetDiffusion: carte['sujet_diffusion'] as String? ?? 'cifi_tous',
    );
  }
}

/// Agregat immuable de tous les parametres de l'application.
/// Unique point d'entree : [ParametresApplication.charger].
class ParametresApplication {
  const ParametresApplication({
    required this.identite,
    required this.site,
    required this.apparence,
    required this.fonctionnalites,
    required this.zones,
    required this.notifications,
  });

  final IdentiteApplication identite;
  final SiteCible site;
  final Apparence apparence;
  final Fonctionnalites fonctionnalites;
  final List<ZoneGeographique> zones;
  final ReglagesNotifications notifications;

  static ParametresApplication? _instance;

  /// Parametres deja charges. Lever une erreur claire si [charger] n'a pas
  /// ete appele : cela signale un oubli dans main.dart, pas un bug utilisateur.
  static ParametresApplication get courants {
    final ParametresApplication? instance = _instance;
    if (instance == null) {
      throw StateError(
        'ParametresApplication.charger() doit etre appele avant tout acces.',
      );
    }
    return instance;
  }

  /// Lit le fichier JSON embarque et construit l'agregat.
  static Future<ParametresApplication> charger() async {
    final String contenu = await rootBundle.loadString(cheminAssetParametres);
    final Map<String, dynamic> racine =
        jsonDecode(contenu) as Map<String, dynamic>;

    Map<String, dynamic> section(String cle) =>
        (racine[cle] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final List<dynamic> zonesBrutes =
        (racine['geofences'] as List<dynamic>?) ?? const <dynamic>[];

    _instance = ParametresApplication(
      identite: IdentiteApplication.depuisCarte(section('identite')),
      site: SiteCible.depuisCarte(section('site_cible')),
      apparence: Apparence.depuisCarte(section('apparence')),
      fonctionnalites: Fonctionnalites.depuisCarte(section('fonctionnalites')),
      zones: zonesBrutes
          .map((dynamic element) =>
              ZoneGeographique.depuisCarte(element as Map<String, dynamic>))
          .toList(growable: false),
      notifications: ReglagesNotifications.depuisCarte(section('notifications')),
    );

    return _instance!;
  }
}
