import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../configuration/parametres_application.dart';
import '../noyau/journal.dart';
import '../noyau/service.dart';

/// Sens du franchissement d'une zone.
enum SensFranchissement { entree, sortie }

/// Evenement emis quand l'appareil entre dans une zone ou en sort.
class FranchissementZone {
  const FranchissementZone({
    required this.zone,
    required this.sens,
    required this.message,
  });

  final ZoneGeographique zone;
  final SensFranchissement sens;
  final String message;
}

/// Geolocalisation et declenchement des notifications geolocalisees.
///
/// Le service ne fabrique aucune notification : il appelle le rappel
/// [surFranchissement] fourni au demarrage. C'est l'appelant qui decide
/// quoi en faire (notification, journal, appel reseau...).
class ServiceGeolocalisation extends Service {
  ServiceGeolocalisation(
    this._fonctionnalites,
    this._zones, {
    required this.surFranchissement,
  });

  final Fonctionnalites _fonctionnalites;
  final List<ZoneGeographique> _zones;
  final void Function(FranchissementZone evenement) surFranchissement;

  StreamSubscription<Position>? _abonnement;
  Position? _dernierePosition;

  /// Zones ou l'appareil se trouve actuellement, pour ne notifier
  /// qu'au changement d'etat et non a chaque relevé.
  final Set<String> _zonesOccupees = <String>{};

  @override
  String get nom => 'geolocalisation';

  @override
  bool get estActif =>
      _fonctionnalites.accesGeolocalisation ||
      _fonctionnalites.notificationsGeolocalisees;

  Position? get dernierePosition => _dernierePosition;

  @override
  Future<void> demarrer() async {
    if (!await _obtenirAutorisation()) {
      Journal.alerter('geolocalisation refusee par l utilisateur');
      return;
    }

    try {
      _dernierePosition = await Geolocator.getLastKnownPosition();
    } catch (erreur) {
      Journal.deboguer('derniere position inconnue : $erreur');
    }

    if (!_fonctionnalites.notificationsGeolocalisees || _zones.isEmpty) {
      Journal.informer(
        'geolocalisation active sans surveillance de zone',
      );
      return;
    }

    const LocationSettings reglages = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50,
    );

    _abonnement ??= Geolocator.getPositionStream(locationSettings: reglages)
        .listen(_traiterPosition, onError: (Object erreur) {
      Journal.alerter('flux de position interrompu : $erreur');
    });

    Journal.informer(
      'surveillance de ${_zones.length} zone(s) geographique(s) demarree',
    );
  }

  @override
  Future<void> arreter() async {
    await _abonnement?.cancel();
    _abonnement = null;
  }

  /// Releve ponctuel, utilise par la passerelle JavaScript.
  Future<Position?> positionActuelle() async {
    if (!await _obtenirAutorisation()) {
      return null;
    }
    try {
      // Appel sans parametre : signature stable sur toutes les versions
      // du greffon geolocator.
      final Position position = await Geolocator.getCurrentPosition();
      _dernierePosition = position;
      return position;
    } catch (erreur) {
      Journal.alerter('position actuelle indisponible : $erreur');
      return null;
    }
  }

  // ------------------------------------------------------------ interne

  Future<bool> _obtenirAutorisation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      Journal.alerter('service de localisation desactive sur l appareil');
      return false;
    }

    LocationPermission autorisation = await Geolocator.checkPermission();
    if (autorisation == LocationPermission.denied) {
      autorisation = await Geolocator.requestPermission();
    }

    return autorisation == LocationPermission.always ||
        autorisation == LocationPermission.whileInUse;
  }

  void _traiterPosition(Position position) {
    _dernierePosition = position;

    for (final ZoneGeographique zone in _zones) {
      final double rayon = zone.rayonMetres > 0
          ? zone.rayonMetres
          : _fonctionnalites.rayonGeofenceMetres.toDouble();

      final double distance = distanceEnMetres(
        position.latitude,
        position.longitude,
        zone.latitude,
        zone.longitude,
      );

      final bool dedans = distance <= rayon;
      final bool etaitDedans = _zonesOccupees.contains(zone.identifiant);

      if (dedans && !etaitDedans) {
        _zonesOccupees.add(zone.identifiant);
        _publier(zone, SensFranchissement.entree, zone.messageEntree);
      } else if (!dedans && etaitDedans) {
        _zonesOccupees.remove(zone.identifiant);
        _publier(zone, SensFranchissement.sortie, zone.messageSortie);
      }
    }
  }

  void _publier(
    ZoneGeographique zone,
    SensFranchissement sens,
    String message,
  ) {
    if (message.trim().isEmpty) {
      return;
    }
    Journal.informer('zone ${zone.identifiant} : ${sens.name}');
    surFranchissement(
      FranchissementZone(zone: zone, sens: sens, message: message),
    );
  }
}

/// Distance orthodromique entre deux points, en metres (formule de haversine).
/// Fonction libre : testable sans aucun appareil ni greffon.
double distanceEnMetres(
  double latitudeDepart,
  double longitudeDepart,
  double latitudeArrivee,
  double longitudeArrivee,
) {
  const double rayonTerrestre = 6371000;

  double enRadians(double degres) => degres * math.pi / 180;

  final double deltaLatitude =
      enRadians(latitudeArrivee - latitudeDepart);
  final double deltaLongitude =
      enRadians(longitudeArrivee - longitudeDepart);

  final double a = math.pow(math.sin(deltaLatitude / 2), 2) +
      math.cos(enRadians(latitudeDepart)) *
          math.cos(enRadians(latitudeArrivee)) *
          math.pow(math.sin(deltaLongitude / 2), 2);

  return 2 * rayonTerrestre * math.asin(math.min(1, math.sqrt(a)));
}
