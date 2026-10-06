import 'package:flutter/material.dart';

/// Barre de progression fine affichee en haut de la WebView.
///
/// Disparait d'elle-meme a 100 %. C'est l'indicateur de chargement natif
/// qui distingue l'application d'un simple navigateur : la progression
/// reelle du rendu, pas une animation decorative.
class BarreProgressionChargement extends StatelessWidget {
  const BarreProgressionChargement({
    super.key,
    required this.progression,
    required this.couleur,
  });

  /// Valeur entre 0.0 et 1.0.
  final double progression;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final bool termine = progression >= 1.0;

    return AnimatedOpacity(
      opacity: termine ? 0 : 1,
      duration: const Duration(milliseconds: 260),
      child: SizedBox(
        height: 3,
        child: LinearProgressIndicator(
          value: progression,
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(couleur),
        ),
      ),
    );
  }
}

/// Voile de chargement affiche au tout premier rendu, pour masquer
/// la page blanche de la WebView tant que le site n'a rien peint.
class VoileChargement extends StatelessWidget {
  const VoileChargement({
    super.key,
    required this.visible,
    required this.couleurFond,
    required this.couleurAccent,
    required this.libelle,
  });

  final bool visible;
  final Color couleurFond;
  final Color couleurAccent;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: ColoredBox(
        color: couleurFond,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(couleurAccent),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              libelle,
              style: TextStyle(
                fontSize: 14,
                color: couleurAccent,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
