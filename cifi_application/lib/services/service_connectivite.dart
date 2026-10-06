import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../noyau/journal.dart';
import '../noyau/service.dart';

/// Surveille en continu la presence d'un acces reseau.
///
/// Expose un [ValueListenable] : l'interface s'y abonne sans connaitre
/// la bibliotheque utilisee en dessous.
class ServiceConnectivite extends Service {
  ServiceConnectivite();

  final ValueNotifier<bool> enLigne = ValueNotifier<bool>(true);

  final Connectivity _connectivite = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _abonnement;

  @override
  String get nom => 'connectivite';

  @override
  bool get estActif => true;

  @override
  Future<void> demarrer() async {
    await _rafraichir();
    _abonnement ??= _connectivite.onConnectivityChanged.listen(
      _traiterChangement,
      onError: (Object erreur) =>
          Journal.erreur('surveillance reseau interrompue', erreur),
    );
    Journal.informer('service connectivite demarre');
  }

  @override
  Future<void> arreter() async {
    await _abonnement?.cancel();
    _abonnement = null;
  }

  Future<void> _rafraichir() async {
    try {
      _traiterChangement(await _connectivite.checkConnectivity());
    } catch (erreur) {
      Journal.alerter('etat reseau indisponible, on suppose en ligne : $erreur');
      enLigne.value = true;
    }
  }

  void _traiterChangement(List<ConnectivityResult> resultats) {
    final bool connecte = resultats.any(
      (ConnectivityResult resultat) => resultat != ConnectivityResult.none,
    );
    if (enLigne.value != connecte) {
      Journal.informer(connecte ? 'reseau retrouve' : 'reseau perdu');
    }
    enLigne.value = connecte;
  }
}
