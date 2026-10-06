import 'package:flutter/material.dart';

/// Bandeau affiche sous la barre de progression quand le reseau manque.
///
/// Il ne masque jamais le contenu : il se replie a zero de hauteur
/// des que la connexion revient.
class BandeauReseau extends StatelessWidget {
  const BandeauReseau({
    super.key,
    required this.enLigne,
    required this.pageDisponibleHorsLigne,
    required this.surReessayer,
  });

  final bool enLigne;

  /// Vrai si la page courante existe dans le cache : le message change
  /// alors de ton, puisque l'utilisateur peut continuer a lire.
  final bool pageDisponibleHorsLigne;

  final VoidCallback surReessayer;

  @override
  Widget build(BuildContext context) {
    final bool visible = !enLigne;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      child: SizedBox(
        height: visible ? 40 : 0,
        child: visible ? _contenu(context) : null,
      ),
    );
  }

  Widget _contenu(BuildContext context) {
    final ColorScheme schema = Theme.of(context).colorScheme;
    final Color fond = pageDisponibleHorsLigne
        ? schema.secondary
        : schema.error;

    final String message = pageDisponibleHorsLigne
        ? 'Hors ligne - version enregistree affichee'
        : 'Hors ligne - connexion introuvable';

    return ColoredBox(
      color: fond,
      child: Row(
        children: <Widget>[
          const SizedBox(width: 14),
          Icon(
            pageDisponibleHorsLigne ? Icons.download_done : Icons.wifi_off,
            size: 17,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: surReessayer,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Reessayer'),
          ),
        ],
      ),
    );
  }
}
