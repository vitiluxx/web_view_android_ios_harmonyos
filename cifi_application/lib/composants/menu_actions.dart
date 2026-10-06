import 'package:flutter/material.dart';

/// Une entree du menu d'actions natives.
class ActionNative {
  const ActionNative({
    required this.icone,
    required this.libelle,
    required this.description,
    required this.action,
  });

  final IconData icone;
  final String libelle;
  final String description;
  final Future<void> Function() action;
}

/// Feuille d'actions natives, ouverte par le bouton flottant.
///
/// Elle rassemble ce qu'un navigateur mobile ne sait pas faire :
/// partager via le systeme, relire hors ligne, scanner un code.
/// Le composant ne connait aucun service : il recoit des [ActionNative].
class MenuActions extends StatelessWidget {
  const MenuActions({super.key, required this.actions});

  final List<ActionNative> actions;

  /// Affiche la feuille et execute l'action choisie.
  static Future<void> afficher(
    BuildContext context,
    List<ActionNative> actions,
  ) async {
    final ActionNative? choisie = await showModalBottomSheet<ActionNative>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext contexte) => MenuActions(actions: actions),
    );
    if (choisie != null) {
      await choisie.action();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: actions
            .map(
              (ActionNative entree) => ListTile(
                leading: Icon(entree.icone),
                title: Text(entree.libelle),
                subtitle: Text(
                  entree.description,
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () => Navigator.of(context).pop(entree),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
