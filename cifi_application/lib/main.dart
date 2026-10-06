import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'configuration/palette_couleurs.dart';
import 'configuration/parametres_application.dart';
import 'ecrans/ecran_demarrage.dart';
import 'noyau/journal.dart';

/// Point d'entree unique.
///
/// Ne contient volontairement aucune logique metier : il lit les
/// parametres, regle l'orientation, puis delegue a [EcranDemarrage].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final ParametresApplication parametres =
      await ParametresApplication.charger();

  await _reglerOrientation(parametres.apparence.orientationVerrouillee);
  _reglerBarresSysteme();

  Journal.informer(
    'lancement de ${parametres.identite.nomAffiche} '
    'vers ${parametres.site.urlAccueil}',
  );

  runApp(ApplicationCifi(parametres: parametres));
}

/// Verrouille l'orientation si le fichier de parametres le demande.
Future<void> _reglerOrientation(String orientation) async {
  const Map<String, List<DeviceOrientation>> correspondances =
      <String, List<DeviceOrientation>>{
    'portrait': <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
    'paysage': <DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
  };

  final List<DeviceOrientation>? choix = correspondances[orientation];
  if (choix == null) {
    return;
  }
  await SystemChrome.setPreferredOrientations(choix);
}

/// Barre d'etat transparente : le site occupe tout l'ecran.
void _reglerBarresSysteme() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
}

class ApplicationCifi extends StatelessWidget {
  const ApplicationCifi({super.key, required this.parametres});

  final ParametresApplication parametres;

  @override
  Widget build(BuildContext context) {
    final PaletteCouleurs palette = PaletteCouleurs(parametres.apparence);

    return MaterialApp(
      title: parametres.identite.nomAffiche,
      debugShowCheckedModeBanner: false,
      theme: palette.themeClair,
      darkTheme: palette.themeSombre,
      themeMode: parametres.apparence.modeSombreAutomatique
          ? ThemeMode.system
          : ThemeMode.light,
      home: EcranDemarrage(parametres: parametres),
    );
  }
}
