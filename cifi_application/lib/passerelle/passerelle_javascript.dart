import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../noyau/journal.dart';
import '../noyau/registre_services.dart';
import '../services/service_cache_hors_ligne.dart';

/// Expose le materiel de l'appareil au site web affiche.
///
/// Cote site, les fonctions sont disponibles sous l'objet global
/// `window.CiFi` et repondent toutes une promesse JavaScript.
/// Voir docs/05_fonctionnalites.md pour les exemples.
///
/// POURQUOI UN PROTOCOLE A NUMEROS
/// -------------------------------
/// webview_flutter n'offre qu'un canal a sens unique : le site peut
/// envoyer un message au code natif, mais ne recoit aucune reponse en
/// retour. On construit donc le retour nous-memes :
///
///   1. le site appelle window.CiFi.prendrePhoto()
///   2. la passerelle attribue un numero a l'appel et l'envoie sur le
///      canal natif, puis rend une promesse au site
///   3. le code natif travaille, puis rappelle le site avec
///      window.CiFi._repondre(numero, resultat)
///   4. la promesse portant ce numero se resout
///
/// Un appel sans reponse au bout de 90 secondes est abandonne, pour que
/// le site ne reste jamais bloque sur une promesse morte.
class PasserelleJavaScript {
  PasserelleJavaScript(this._registre);

  final RegistreServices _registre;

  /// Nom du canal natif. Volontairement distinctif pour ne jamais
  /// entrer en collision avec un script tiers charge par le site.
  static const String nomCanal = 'cifiPasserelleNative';

  WebViewController? _controleur;

  /// Memorise le controleur pour pouvoir repondre au site.
  void brancher(WebViewController controleur) {
    _controleur = controleur;
  }

  /// Traite un message venu du site et renvoie la reponse.
  /// Appele par l'ecran, qui a enregistre le canal sur le controleur.
  Future<void> traiterMessage(String messageBrut) async {
    int numero = -1;
    try {
      final Map<String, dynamic> message =
          jsonDecode(messageBrut) as Map<String, dynamic>;

      numero = (message['numero'] as num?)?.toInt() ?? -1;
      final String fonction = message['fonction'] as String? ?? '';
      final List<dynamic> arguments =
          (message['arguments'] as List<dynamic>?) ?? const <dynamic>[];

      final Map<String, dynamic> reponse = await _executer(fonction, arguments);
      await _repondre(numero, reponse);
    } catch (erreur, pile) {
      Journal.erreur('passerelle : message illisible', erreur, pile);
      if (numero >= 0) {
        await _repondre(numero, <String, dynamic>{
          'succes': false,
          'erreur': erreur.toString(),
        });
      }
    }
  }

  Future<void> _repondre(int numero, Map<String, dynamic> reponse) async {
    final WebViewController? controleur = _controleur;
    if (controleur == null || numero < 0) {
      return;
    }
    final String charge = jsonEncode(reponse);
    try {
      await controleur.runJavaScript(
        'window.CiFi && window.CiFi._repondre($numero, $charge);',
      );
    } catch (erreur) {
      Journal.deboguer('reponse non remise au site : $erreur');
    }
  }

  // ------------------------------------------------------------ aiguillage

  Future<Map<String, dynamic>> _executer(
    String fonction,
    List<dynamic> arguments,
  ) async {
    switch (fonction) {
      case 'appareilInformations':
        return _appareilInformations();
      case 'prendrePhoto':
        return _cheminOuEchec(await _registre.materiel.prendrePhoto());
      case 'choisirImage':
        return _cheminOuEchec(await _registre.materiel.choisirImage());
      case 'choisirFichier':
        return _cheminOuEchec(await _registre.materiel.choisirFichier());
      case 'positionActuelle':
        return _positionActuelle();
      case 'vibrer':
        return _vibrer(arguments);
      case 'partager':
        return _partager(arguments);
      case 'notifier':
        return _notifier(arguments);
      case 'majWidget':
        return _majWidget(arguments);
      case 'etatReseau':
        return <String, dynamic>{
          'succes': true,
          'en_ligne': _registre.connectivite.enLigne.value,
        };
      case 'pagesHorsLigne':
        return <String, dynamic>{
          'succes': true,
          'pages': _registre.cache.pagesArchivees
              .map((PageArchivee page) => page.versCarte())
              .toList(growable: false),
        };
      default:
        return <String, dynamic>{
          'succes': false,
          'erreur': 'fonction inconnue : $fonction',
        };
    }
  }

  // ------------------------------------------------------------ fonctions

  Map<String, dynamic> _appareilInformations() => <String, dynamic>{
        'succes': true,
        'appareil': _registre.materiel.descriptionAppareil,
        'version_application': _registre.materiel.versionApplication,
        'nom_application': _registre.parametres.identite.nomAffiche,
        'en_ligne': _registre.connectivite.enLigne.value,
      };

  Map<String, dynamic> _cheminOuEchec(String? chemin) => <String, dynamic>{
        'succes': chemin != null,
        'chemin': chemin,
      };

  Future<Map<String, dynamic>> _positionActuelle() async {
    final Position? position =
        await _registre.geolocalisation.positionActuelle();
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

  Future<Map<String, dynamic>> _vibrer(List<dynamic> arguments) async {
    await _registre.materiel.vibrer(
      dureeMillisecondes: _entier(arguments, 0, 40),
    );
    return <String, dynamic>{'succes': true};
  }

  Future<Map<String, dynamic>> _partager(List<dynamic> arguments) async {
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

  Future<Map<String, dynamic>> _notifier(List<dynamic> arguments) async {
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

  Future<Map<String, dynamic>> _majWidget(List<dynamic> arguments) async {
    await _registre.widgetAccueil.mettreAJour(
      titre: _texte(arguments, 0),
      resume: _texte(arguments, 1),
      url: _texte(arguments, 2),
    );
    return <String, dynamic>{'succes': true};
  }

  // ------------------------------------------------------------ arguments

  String _texte(List<dynamic> arguments, int position) {
    if (position >= arguments.length) {
      return '';
    }
    return arguments[position]?.toString() ?? '';
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

  // ------------------------------------------------------------ script injecte

  /// Script pose dans chaque page pour fabriquer window.CiFi.
  /// JavaScript brut, sans aucune bibliotheque externe.
  ///
  /// L'interface rendue au site est identique a celle de la version
  /// HarmonyOS : le meme code de site fonctionne sur les trois plateformes.
  static String get scriptInjecte => '''
(function () {
  if (window.CiFi) { return; }

  var numeroSuivant = 1;
  var enAttente = {};
  var DELAI_MAXIMUM = 90000;

  function appeler(nomFonction) {
    var arguments_ = Array.prototype.slice.call(arguments, 1);
    var numero = numeroSuivant++;

    return new Promise(function (resoudre) {
      var minuteur = setTimeout(function () {
        if (enAttente[numero]) {
          delete enAttente[numero];
          resoudre({ succes: false, erreur: 'delai depasse' });
        }
      }, DELAI_MAXIMUM);

      enAttente[numero] = function (reponse) {
        clearTimeout(minuteur);
        resoudre(reponse);
      };

      try {
        $nomCanal.postMessage(JSON.stringify({
          numero: numero,
          fonction: nomFonction,
          arguments: arguments_
        }));
      } catch (erreur) {
        clearTimeout(minuteur);
        delete enAttente[numero];
        resoudre({ succes: false, erreur: String(erreur) });
      }
    });
  }

  window.CiFi = {
    disponible: true,

    // Appele par le code natif. Ne l'appelez pas vous-meme.
    _repondre: function (numero, reponse) {
      var attendu = enAttente[numero];
      if (attendu) {
        delete enAttente[numero];
        attendu(reponse);
      }
    },

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
}
