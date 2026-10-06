import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:geolocator/geolocator.dart';

import '../noyau/journal.dart';
import '../noyau/registre_services.dart';
import '../services/service_cache_hors_ligne.dart';

/// Expose le materiel de l'appareil au site web affiche.
///
/// Cote site, les fonctions sont disponibles sous l'objet global
/// `window.CiFi` (voir docs/05_fonctionnalites.md pour les exemples).
/// Toutes repondent une promesse JavaScript.
///
/// Le nom du canal natif est volontairement unique pour eviter toute
/// collision avec un script tiers charge par le site.
class PasserelleJavaScript {
  PasserelleJavaScript(this._registre);

  final RegistreServices _registre;

  static const String _nomCanal = 'cifiPasserelleNative';

  /// Branche les gestionnaires sur le controleur de la WebView.
  /// A appeler une seule fois, dans onWebViewCreated.
  void brancher(InAppWebViewController controleur) {
    _enregistrer(controleur, 'appareilInformations', _appareilInformations);
    _enregistrer(controleur, 'prendrePhoto', _prendrePhoto);
    _enregistrer(controleur, 'choisirImage', _choisirImage);
    _enregistrer(controleur, 'choisirFichier', _choisirFichier);
    _enregistrer(controleur, 'positionActuelle', _positionActuelle);
    _enregistrer(controleur, 'vibrer', _vibrer);
    _enregistrer(controleur, 'partager', _partager);
    _enregistrer(controleur, 'notifier', _notifier);
    _enregistrer(controleur, 'majWidget', _majWidget);
    _enregistrer(controleur, 'etatReseau', _etatReseau);
    _enregistrer(controleur, 'pagesHorsLigne', _pagesHorsLigne);
  }

  void _enregistrer(
    InAppWebViewController controleur,
    String nomFonction,
    Future<dynamic> Function(List<dynamic> arguments) gestionnaire,
  ) {
    controleur.addJavaScriptHandler(
      handlerName: '$_nomCanal.$nomFonction',
      callback: (List<dynamic> arguments) async {
        try {
          return await gestionnaire(arguments);
        } catch (erreur, pile) {
          Journal.erreur('passerelle $nomFonction en echec', erreur, pile);
          return <String, dynamic>{
            'succes': false,
            'erreur': erreur.toString(),
          };
        }
      },
    );
  }

  /// Script injecte dans chaque page pour fabriquer l'objet window.CiFi.
  /// Ecrit en JavaScript brut, sans aucune bibliotheque externe.
  static String get scriptInjecte => '''
(function () {
  if (window.CiFi) { return; }

  function appeler(nomFonction) {
    var arguments_ = Array.prototype.slice.call(arguments, 1);
    return window.flutter_inappwebview.callHandler
      .apply(null, ['$_nomCanal.' + nomFonction].concat(arguments_));
  }

  window.CiFi = {
    disponible: true,
    appareilInformations: function () { return appeler('appareilInformations'); },
    prendrePhoto:         function () { return appeler('prendrePhoto'); },
    choisirImage:         function () { return appeler('choisirImage'); },
    choisirFichier:       function () { return appeler('choisirFichier'); },
    positionActuelle:     function () { return appeler('positionActuelle'); },
    vibrer:               function (duree) { return appeler('vibrer', duree || 40); },
    partager:             function (texte, sujet) { return appeler('partager', texte, sujet || ''); },
    notifier:             function (titre, corps, url) { return appeler('notifier', titre, corps, url || ''); },
    majWidget:            function (titre, resume, url) { return appeler('majWidget', titre, resume, url || ''); },
    etatReseau:           function () { return appeler('etatReseau'); },
    pagesHorsLigne:       function () { return appeler('pagesHorsLigne'); }
  };

  document.dispatchEvent(new Event('cifi-passerelle-prete'));
})();
''';

  // ------------------------------------------------------------ gestionnaires

  Future<dynamic> _appareilInformations(List<dynamic> arguments) async {
    return <String, dynamic>{
      'succes': true,
      'appareil': _registre.materiel.descriptionAppareil,
      'version_application': _registre.materiel.versionApplication,
      'nom_application': _registre.parametres.identite.nomAffiche,
      'en_ligne': _registre.connectivite.enLigne.value,
    };
  }

  Future<dynamic> _prendrePhoto(List<dynamic> arguments) async {
    final String? chemin = await _registre.materiel.prendrePhoto();
    return <String, dynamic>{'succes': chemin != null, 'chemin': chemin};
  }

  Future<dynamic> _choisirImage(List<dynamic> arguments) async {
    final String? chemin = await _registre.materiel.choisirImage();
    return <String, dynamic>{'succes': chemin != null, 'chemin': chemin};
  }

  Future<dynamic> _choisirFichier(List<dynamic> arguments) async {
    final String? chemin = await _registre.materiel.choisirFichier();
    return <String, dynamic>{'succes': chemin != null, 'chemin': chemin};
  }

  Future<dynamic> _positionActuelle(List<dynamic> arguments) async {
    final Position? position = await _registre.geolocalisation.positionActuelle();
    if (position == null) {
      return <String, dynamic>{
        'succes': false,
        'erreur': 'position indisponible ou autorisation refusee',
      };
    }
    return <String, dynamic>{
      'succes': true,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'precision_metres': position.accuracy,
    };
  }

  Future<dynamic> _vibrer(List<dynamic> arguments) async {
    final int duree = _entier(arguments, 0, 40);
    await _registre.materiel.vibrer(dureeMillisecondes: duree);
    return <String, dynamic>{'succes': true};
  }

  Future<dynamic> _partager(List<dynamic> arguments) async {
    final String texte = _texte(arguments, 0);
    if (texte.isEmpty) {
      return <String, dynamic>{'succes': false, 'erreur': 'texte vide'};
    }
    final String sujet = _texte(arguments, 1);
    await _registre.materiel.partager(
      texte: texte,
      sujet: sujet.isEmpty ? null : sujet,
    );
    return <String, dynamic>{'succes': true};
  }

  Future<dynamic> _notifier(List<dynamic> arguments) async {
    final String titre = _texte(arguments, 0);
    final String corps = _texte(arguments, 1);
    if (titre.isEmpty && corps.isEmpty) {
      return <String, dynamic>{'succes': false, 'erreur': 'contenu vide'};
    }
    final String url = _texte(arguments, 2);
    await _registre.notifications.afficher(
      titre: titre.isEmpty ? _registre.parametres.identite.nomAffiche : titre,
      corps: corps,
      urlAssociee: url.isEmpty ? null : url,
    );
    return <String, dynamic>{'succes': true};
  }

  Future<dynamic> _majWidget(List<dynamic> arguments) async {
    await _registre.widgetAccueil.mettreAJour(
      titre: _texte(arguments, 0),
      resume: _texte(arguments, 1),
      url: _texte(arguments, 2),
    );
    return <String, dynamic>{'succes': true};
  }

  Future<dynamic> _etatReseau(List<dynamic> arguments) async {
    return <String, dynamic>{
      'succes': true,
      'en_ligne': _registre.connectivite.enLigne.value,
    };
  }

  Future<dynamic> _pagesHorsLigne(List<dynamic> arguments) async {
    return <String, dynamic>{
      'succes': true,
      'pages': _registre.cache.pagesArchivees
          .map((PageArchivee page) => page.versCarte())
          .toList(growable: false),
    };
  }

  // ------------------------------------------------------------ lecture des arguments

  String _texte(List<dynamic> arguments, int position) {
    if (position >= arguments.length) {
      return '';
    }
    final dynamic valeur = arguments[position];
    if (valeur == null) {
      return '';
    }
    return valeur.toString();
  }

  int _entier(List<dynamic> arguments, int position, int parDefaut) {
    if (position >= arguments.length) {
      return parDefaut;
    }
    final dynamic valeur = arguments[position];
    if (valeur is num) {
      return valeur.toInt();
    }
    return int.tryParse(valeur?.toString() ?? '') ?? parDefaut;
  }
}
