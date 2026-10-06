import 'package:flutter/material.dart';

import '../noyau/registre_services.dart';
import '../services/service_cache_hors_ligne.dart';

/// Liste des pages enregistrees, consultables sans reseau.
///
/// Ecran natif Flutter : il reste utilisable meme quand la WebView
/// n'a rien a afficher. Retourne au navigateur l'URL choisie.
class EcranHorsLigne extends StatefulWidget {
  const EcranHorsLigne({super.key, required this.registre});

  final RegistreServices registre;

  @override
  State<EcranHorsLigne> createState() => _EtatEcranHorsLigne();
}

class _EtatEcranHorsLigne extends State<EcranHorsLigne> {
  late List<PageArchivee> _pages;

  @override
  void initState() {
    super.initState();
    _pages = widget.registre.cache.pagesArchivees;
  }

  Future<void> _viderCache() async {
    final bool confirme = await _demanderConfirmation();
    if (!confirme) {
      return;
    }
    await widget.registre.cache.viderTout();
    if (!mounted) {
      return;
    }
    setState(() => _pages = widget.registre.cache.pagesArchivees);
  }

  Future<bool> _demanderConfirmation() async {
    final bool? reponse = await showDialog<bool>(
      context: context,
      builder: (BuildContext contexte) => AlertDialog(
        title: const Text('Vider les pages enregistrees ?'),
        content: const Text(
          'Les pages ne seront plus lisibles hors ligne. '
          'Elles se reconstituent au fil de la navigation.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(true),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
    return reponse ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pages enregistrees'),
        actions: <Widget>[
          if (_pages.isNotEmpty)
            IconButton(
              tooltip: 'Vider',
              onPressed: _viderCache,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _pages.isEmpty ? _vide() : _liste(),
    );
  }

  Widget _vide() {
    final ColorScheme schema = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.cloud_off_outlined,
              size: 54,
              color: schema.onSurface.withAlpha(90),
            ),
            const SizedBox(height: 18),
            const Text(
              'Aucune page enregistree',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 9),
            Text(
              'Les pages que vous consultez sont conservees '
              'automatiquement pour une relecture sans reseau.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: schema.onSurface.withAlpha(150),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _liste() {
    return ListView.separated(
      itemCount: _pages.length,
      separatorBuilder: (BuildContext contexte, int index) =>
          const Divider(height: 1),
      itemBuilder: (BuildContext contexte, int index) {
        final PageArchivee page = _pages[index];
        return ListTile(
          leading: const Icon(Icons.article_outlined),
          title: Text(
            page.titre,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            _horodatageLisible(page.horodatage),
            style: const TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => Navigator.of(context).pop(page.url),
        );
      },
    );
  }

  /// Format court sans dependance de localisation : "05/10 a 14:32".
  String _horodatageLisible(DateTime instant) {
    String deuxChiffres(int valeur) => valeur.toString().padLeft(2, '0');
    return '${deuxChiffres(instant.day)}/${deuxChiffres(instant.month)} '
        'a ${deuxChiffres(instant.hour)}:${deuxChiffres(instant.minute)}';
  }
}
