import 'package:flutter/services.dart';

import '../configuration/parametres_application.dart';

/// Fabrique le code HTML de la page hors ligne.
///
/// Le gabarit vit dans assets/pages/hors_ligne.html et ne contient aucune
/// ressource externe. Cette classe se contente de remplacer les marqueurs
/// {{...}} par les valeurs de cifi_parametres.json.
class FabriquePageHorsLigne {
  FabriquePageHorsLigne(this._parametres);

  final ParametresApplication _parametres;

  static const String _cheminGabarit = 'assets/pages/hors_ligne.html';

  String? _gabarit;

  /// Charge le gabarit une seule fois puis le garde en memoire.
  Future<String> construire({
    required String urlDemandee,
    required bool modeSombre,
  }) async {
    _gabarit ??= await rootBundle.loadString(_cheminGabarit);

    final Apparence apparence = _parametres.apparence;

    final String fond =
        modeSombre ? apparence.couleurFondSombre : apparence.couleurFondClair;
    final String texte =
        modeSombre ? apparence.couleurTexteSombre : apparence.couleurTexteClair;

    return _gabarit!
        .replaceAll('{{COULEUR_PRIMAIRE}}', apparence.couleurPrimaire)
        .replaceAll('{{COULEUR_FOND}}', fond)
        .replaceAll('{{COULEUR_TEXTE}}', texte)
        .replaceAll('{{COULEUR_DISCRETE}}', _versRgba(texte, 0.62))
        .replaceAll('{{COULEUR_BORDURE}}', _versRgba(texte, 0.12))
        .replaceAll('{{NOM_APPLICATION}}', _echapper(_parametres.identite.nomAffiche))
        .replaceAll('{{URL_DEMANDEE}}', _echapper(urlDemandee));
  }

  /// Transforme "#RRGGBB" en "rgba(r, g, b, opacite)" : evite d'avoir
  /// a declarer une couleur de plus dans le fichier de parametres.
  ///
  /// On lit les composantes directement dans la chaine plutot que de
  /// passer par un objet Color : aucune dependance a la version de
  /// Flutter, et une couleur mal saisie retombe sur du noir.
  String _versRgba(String hexadecimal, double opacite) {
    final String nettoye =
        hexadecimal.trim().replaceFirst('#', '').toUpperCase();
    final String corps =
        nettoye.length == 8 ? nettoye.substring(2) : nettoye;

    int composante(int position) {
      if (corps.length < position + 2) {
        return 0;
      }
      return int.tryParse(corps.substring(position, position + 2), radix: 16) ?? 0;
    }

    return 'rgba(${composante(0)}, ${composante(2)}, ${composante(4)}, $opacite)';
  }

  /// Neutralise les caracteres qui casseraient le HTML.
  String _echapper(String brut) => brut
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
