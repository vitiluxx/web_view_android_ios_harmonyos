import 'package:flutter/services.dart';

import '../configuration/parametres_application.dart';

/// Nature du probleme qui empeche d'afficher la page demandee.
///
/// Chaque cas merite un message different : dire "verifiez votre Wi-Fi"
/// alors que le certificat du site est invalide envoie l'utilisateur
/// chercher au mauvais endroit.
enum MotifSecours {
  /// Le reseau est absent ou injoignable.
  reseauAbsent,

  /// Le certificat du site est invalide, expire ou auto-signe.
  /// Le systeme refuse alors la connexion, sans rien afficher.
  certificatInvalide,

  /// Le serveur a repondu, mais par une erreur (404, 500...).
  erreurServeur,
}

/// Fabrique le code HTML de la page de secours.
///
/// Le gabarit vit dans assets/pages/hors_ligne.html et ne contient aucune
/// ressource externe. Cette classe remplace les marqueurs {{...}} par les
/// valeurs de cifi_parametres.json et par le message adapte au motif.
class FabriquePageHorsLigne {
  FabriquePageHorsLigne(this._parametres);

  final ParametresApplication _parametres;

  static const String _cheminGabarit = 'assets/pages/hors_ligne.html';

  String? _gabarit;

  /// Charge le gabarit une seule fois puis le garde en memoire.
  Future<String> construire({
    required String urlDemandee,
    required bool modeSombre,
    MotifSecours motif = MotifSecours.reseauAbsent,
    String detailTechnique = '',
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
        .replaceAll('{{NOM_APPLICATION}}',
            _echapper(_parametres.identite.nomAffiche))
        .replaceAll('{{TITRE}}', _echapper(_titre(motif)))
        .replaceAll('{{EXPLICATION}}', _echapper(_explication(motif)))
        .replaceAll('{{CONSEILS}}', _conseils(motif))
        .replaceAll('{{URL_DEMANDEE}}',
            _echapper(_adresseAffichee(urlDemandee, detailTechnique)));
  }

  // ------------------------------------------------------------ messages

  String _titre(MotifSecours motif) {
    switch (motif) {
      case MotifSecours.reseauAbsent:
        return 'Pas de connexion';
      case MotifSecours.certificatInvalide:
        return 'Site non securise';
      case MotifSecours.erreurServeur:
        return 'Site indisponible';
    }
  }

  String _explication(MotifSecours motif) {
    final String nom = _parametres.identite.nomAffiche;
    switch (motif) {
      case MotifSecours.reseauAbsent:
        return "$nom n'arrive pas a joindre le reseau. "
            'Les pages deja consultees restent lisibles hors ligne.';
      case MotifSecours.certificatInvalide:
        return "Le certificat de securite du site n'est pas valide. "
            'Par precaution, la connexion a ete refusee : vos donnees '
            "pourraient etre lues par un tiers.";
      case MotifSecours.erreurServeur:
        return 'Le site a repondu par une erreur. '
            'Le probleme vient du serveur, pas de votre telephone.';
    }
  }

  /// Conseils adaptes, rendus directement en elements de liste.
  String _conseils(MotifSecours motif) {
    late final List<String> lignes;
    switch (motif) {
      case MotifSecours.reseauAbsent:
        lignes = <String>[
          'Verifiez les donnees mobiles ou le Wi-Fi.',
          "Desactivez le mode avion s'il est actif.",
          'Changez de place : le signal varie beaucoup en interieur.',
        ];
      case MotifSecours.certificatInvalide:
        lignes = <String>[
          "Verifiez la date et l'heure de votre telephone : "
              'une horloge fausse invalide tous les certificats.',
          'Si vous etes sur un Wi-Fi public, il intercepte peut-etre '
              'la connexion.',
          "Si le probleme persiste, prevenez l'administrateur du site : "
              'son certificat doit etre renouvele.',
        ];
      case MotifSecours.erreurServeur:
        lignes = <String>[
          'Reessayez dans quelques minutes.',
          "L'adresse demandee a peut-etre ete deplacee ou supprimee.",
          "Si cela dure, prevenez l'administrateur du site.",
        ];
    }

    return lignes
        .map((String ligne) =>
            '<li><span class="puce"></span><span>${_echapper(ligne)}</span></li>')
        .join();
  }

  String _adresseAffichee(String url, String detail) {
    if (detail.trim().isEmpty) {
      return url;
    }
    return '$url\n$detail';
  }

  // ------------------------------------------------------------ outils

  /// Transforme "#RRGGBB" en "rgba(r, g, b, opacite)" : evite d'avoir
  /// a declarer une couleur de plus dans le fichier de parametres.
  ///
  /// On lit les composantes directement dans la chaine plutot que de
  /// passer par un objet Color : aucune dependance a la version de
  /// Flutter, et une couleur mal saisie retombe sur du noir.
  String _versRgba(String hexadecimal, double opacite) {
    final String nettoye =
        hexadecimal.trim().replaceFirst('#', '').toUpperCase();
    final String corps = nettoye.length == 8 ? nettoye.substring(2) : nettoye;

    int composante(int position) {
      if (corps.length < position + 2) {
        return 0;
      }
      return int.tryParse(corps.substring(position, position + 2), radix: 16) ??
          0;
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
