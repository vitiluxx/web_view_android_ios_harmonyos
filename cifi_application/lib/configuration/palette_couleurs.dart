import 'package:flutter/material.dart';

import 'parametres_application.dart';

/// Convertit une couleur ecrite en hexadecimal ("#RRGGBB" ou "#AARRGGBB")
/// en couleur Flutter. Retourne [repli] si la chaine est invalide : une
/// couleur mal saisie dans le JSON ne doit jamais faire planter l'application.
Color couleurDepuisHexadecimal(String valeur, {Color repli = Colors.black}) {
  String nettoye = valeur.trim().replaceFirst('#', '').toUpperCase();
  if (nettoye.length == 6) {
    nettoye = 'FF$nettoye';
  }
  if (nettoye.length != 8) {
    return repli;
  }
  final int? entier = int.tryParse(nettoye, radix: 16);
  if (entier == null) {
    return repli;
  }
  return Color(entier);
}

/// Themes clair et sombre construits exclusivement depuis le fichier
/// de parametres. Aucune couleur n'est codee en dur ailleurs dans l'interface.
class PaletteCouleurs {
  PaletteCouleurs(this._apparence);

  final Apparence _apparence;

  factory PaletteCouleurs.depuisParametres() =>
      PaletteCouleurs(ParametresApplication.courants.apparence);

  Color get primaire =>
      couleurDepuisHexadecimal(_apparence.couleurPrimaire, repli: Colors.blue);

  Color get secondaire => couleurDepuisHexadecimal(
        _apparence.couleurSecondaire,
        repli: Colors.teal,
      );

  Color get fondClair => couleurDepuisHexadecimal(
        _apparence.couleurFondClair,
        repli: Colors.white,
      );

  Color get fondSombre => couleurDepuisHexadecimal(
        _apparence.couleurFondSombre,
        repli: const Color(0xFF0E1116),
      );

  Color get texteClair => couleurDepuisHexadecimal(
        _apparence.couleurTexteClair,
        repli: const Color(0xFF11161D),
      );

  Color get texteSombre => couleurDepuisHexadecimal(
        _apparence.couleurTexteSombre,
        repli: const Color(0xFFEDF1F7),
      );

  Color get splash => couleurDepuisHexadecimal(
        _apparence.couleurSplash,
        repli: primaire,
      );

  ThemeData get themeClair => _construireTheme(
        luminosite: Brightness.light,
        fond: fondClair,
        texte: texteClair,
      );

  ThemeData get themeSombre => _construireTheme(
        luminosite: Brightness.dark,
        fond: fondSombre,
        texte: texteSombre,
      );

  ThemeData _construireTheme({
    required Brightness luminosite,
    required Color fond,
    required Color texte,
  }) {
    final ColorScheme schema = ColorScheme.fromSeed(
      seedColor: primaire,
      brightness: luminosite,
    ).copyWith(
      primary: primaire,
      secondary: secondaire,
      surface: fond,
      onSurface: texte,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: schema,
      scaffoldBackgroundColor: fond,
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaire,
        // withAlpha reste la voie non obsolete pour eclaircir une
        // couleur : .red, .green et .blue ne le sont plus.
        linearTrackColor: primaire.withAlpha(46),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: texte,
        contentTextStyle: TextStyle(color: fond),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
