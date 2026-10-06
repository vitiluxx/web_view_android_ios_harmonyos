import 'package:flutter/material.dart';

import '../configuration/palette_couleurs.dart';
import '../configuration/parametres_application.dart';
import '../noyau/journal.dart';
import '../noyau/registre_services.dart';
import 'ecran_navigateur.dart';

/// Ecran affiche pendant le demarrage des services.
///
/// Il prolonge visuellement le splash natif : meme couleur, meme logo,
/// pour que l'utilisateur ne voie aucune rupture. Il ne disparait que
/// lorsque tous les services actifs sont prets.
class EcranDemarrage extends StatefulWidget {
  const EcranDemarrage({super.key, required this.parametres});

  final ParametresApplication parametres;

  @override
  State<EcranDemarrage> createState() => _EtatEcranDemarrage();
}

class _EtatEcranDemarrage extends State<EcranDemarrage> {
  String _etape = 'Preparation';
  String? _messageErreur;

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  Future<void> _demarrer() async {
    try {
      setState(() => _etape = 'Demarrage des services');
      final RegistreServices registre =
          await RegistreServices.demarrer(widget.parametres);

      setState(() => _etape = 'Autorisations');
      await registre.materiel.demanderAutorisationsInitiales();

      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (BuildContext contexte) =>
              EcranNavigateur(registre: registre),
        ),
      );
    } catch (erreur, pile) {
      Journal.erreur('demarrage impossible', erreur, pile);
      if (mounted) {
        setState(() => _messageErreur = erreur.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final PaletteCouleurs palette = PaletteCouleurs(widget.parametres.apparence);

    return Scaffold(
      backgroundColor: palette.splash,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _messageErreur == null
              ? _chargement(palette)
              : _erreur(palette),
        ),
      ),
    );
  }

  Widget _chargement(PaletteCouleurs palette) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Image.asset(
          'assets/marque/logo_splash.png',
          width: 118,
          errorBuilder: (BuildContext contexte, Object erreur, StackTrace? pile) =>
              Text(
            widget.parametres.identite.nomAffiche,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 40),
        const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _etape,
          style: TextStyle(color: Colors.white.withAlpha(205), fontSize: 13),
        ),
      ],
    );
  }

  Widget _erreur(PaletteCouleurs palette) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Icon(Icons.error_outline, color: Colors.white, size: 46),
        const SizedBox(height: 18),
        const Text(
          'Demarrage impossible',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _messageErreur ?? '',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 12.5),
        ),
        const SizedBox(height: 26),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: palette.splash,
          ),
          onPressed: () {
            setState(() => _messageErreur = null);
            _demarrer();
          },
          child: const Text('Reessayer'),
        ),
      ],
    );
  }
}
