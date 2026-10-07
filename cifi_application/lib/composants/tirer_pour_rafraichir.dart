import 'package:flutter/material.dart';

/// Tirer vers le bas pour recharger la page.
///
/// POURQUOI PAS RefreshIndicator
/// -----------------------------
/// RefreshIndicator ecoute les notifications de defilement de Flutter.
/// Or une WebView defile a l'interieur de la vue native : elle n'emet
/// aucune notification Flutter. RefreshIndicator resterait donc muet.
///
/// On observe plutot les evenements du doigt avec [Listener], qui ne
/// participe pas a la competition de gestes : la page garde le controle
/// total de son defilement, on se contente de regarder.
///
/// Le geste n'est pris en compte que lorsque la page est deja tout en
/// haut, information fournie par [auSommet].
class TirerPourRafraichir extends StatefulWidget {
  const TirerPourRafraichir({
    super.key,
    required this.enfant,
    required this.auSommet,
    required this.surRafraichir,
    required this.couleur,
    this.actif = true,
  });

  final Widget enfant;

  /// Vrai quand la page est en haut. Fourni par l'ecran, qui suit la
  /// position de defilement de la WebView.
  final bool auSommet;

  final Future<void> Function() surRafraichir;
  final Color couleur;
  final bool actif;

  @override
  State<TirerPourRafraichir> createState() => _EtatTirerPourRafraichir();
}

class _EtatTirerPourRafraichir extends State<TirerPourRafraichir> {
  /// Distance a parcourir avec le doigt pour declencher le rechargement.
  static const double _seuilDeclenchement = 110;

  /// Au-dela, l'indicateur n'avance plus : evite qu'il parte trop bas.
  static const double _etirementMaximum = 160;

  double _distanceTiree = 0;
  bool _gesteEnCours = false;
  bool _rechargementEnCours = false;

  void _surDoigtPose(PointerDownEvent evenement) {
    if (!widget.actif || _rechargementEnCours) {
      return;
    }
    _gesteEnCours = widget.auSommet;
    _distanceTiree = 0;
  }

  void _surDoigtDeplace(PointerMoveEvent evenement) {
    if (!_gesteEnCours) {
      return;
    }

    // Un defilement vers le haut annule le geste : l'utilisateur lit,
    // il ne cherche pas a recharger.
    if (evenement.delta.dy < 0 && _distanceTiree <= 0) {
      _gesteEnCours = false;
      return;
    }

    if (!widget.auSommet) {
      _gesteEnCours = false;
      _reinitialiser();
      return;
    }

    final double nouvelle =
        (_distanceTiree + evenement.delta.dy).clamp(0, _etirementMaximum);
    if (nouvelle != _distanceTiree) {
      setState(() => _distanceTiree = nouvelle);
    }
  }

  Future<void> _surDoigtLeve(PointerUpEvent evenement) async {
    if (!_gesteEnCours) {
      return;
    }
    _gesteEnCours = false;

    if (_distanceTiree < _seuilDeclenchement) {
      _reinitialiser();
      return;
    }

    setState(() {
      _rechargementEnCours = true;
      _distanceTiree = _seuilDeclenchement;
    });

    try {
      await widget.surRafraichir();
    } finally {
      if (mounted) {
        setState(() {
          _rechargementEnCours = false;
          _distanceTiree = 0;
        });
      }
    }
  }

  void _reinitialiser() {
    if (_distanceTiree != 0) {
      setState(() => _distanceTiree = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.actif) {
      return widget.enfant;
    }

    final double avancement =
        (_distanceTiree / _seuilDeclenchement).clamp(0.0, 1.0);

    return Listener(
      onPointerDown: _surDoigtPose,
      onPointerMove: _surDoigtDeplace,
      onPointerUp: _surDoigtLeve,
      onPointerCancel: (PointerCancelEvent evenement) {
        _gesteEnCours = false;
        _reinitialiser();
      },
      child: Stack(
        children: <Widget>[
          widget.enfant,
          if (_distanceTiree > 0) _indicateur(avancement),
        ],
      ),
    );
  }

  Widget _indicateur(double avancement) {
    return Positioned(
      top: _distanceTiree * 0.42,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withAlpha(38),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: _rechargementEnCours
              ? CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(widget.couleur),
                )
              : Transform.rotate(
                  angle: avancement * 3.14159,
                  child: CircularProgressIndicator(
                    value: avancement,
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(widget.couleur),
                  ),
                ),
        ),
      ),
    );
  }
}
