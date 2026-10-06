import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../configuration/parametres_application.dart';
import '../noyau/journal.dart';
import '../noyau/service.dart';

/// Une page consultee, conservee sur l'appareil pour relecture hors ligne.
class PageArchivee {
  const PageArchivee({
    required this.url,
    required this.titre,
    required this.nomFichier,
    required this.horodatage,
  });

  final String url;
  final String titre;
  final String nomFichier;
  final DateTime horodatage;

  Map<String, dynamic> versCarte() => <String, dynamic>{
        'url': url,
        'titre': titre,
        'nom_fichier': nomFichier,
        'horodatage': horodatage.toIso8601String(),
      };

  factory PageArchivee.depuisCarte(Map<String, dynamic> carte) {
    return PageArchivee(
      url: carte['url'] as String? ?? '',
      titre: carte['titre'] as String? ?? '',
      nomFichier: carte['nom_fichier'] as String? ?? '',
      horodatage:
          DateTime.tryParse(carte['horodatage'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Mode hors ligne.
///
/// Trois responsabilites, volontairement regroupees car elles partagent
/// le meme dossier de stockage :
///   1. archiver le code HTML des pages visitees ;
///   2. les restituer quand le reseau manque ;
///   3. purger ce qui depasse la duree de conservation declaree.
class ServiceCacheHorsLigne extends Service {
  ServiceCacheHorsLigne(this._fonctionnalites);

  final Fonctionnalites _fonctionnalites;

  static const String _cleIndex = 'cifi_index_pages_archivees';
  static const String _cleDerniereUrl = 'cifi_derniere_url';
  static const int _nombreMaximumPages = 40;

  Directory? _dossier;
  SharedPreferences? _preferences;
  final List<PageArchivee> _index = <PageArchivee>[];

  @override
  String get nom => 'cache hors ligne';

  @override
  bool get estActif => _fonctionnalites.modeHorsLigne;

  List<PageArchivee> get pagesArchivees => List<PageArchivee>.unmodifiable(
        _index.reversed,
      );

  @override
  Future<void> demarrer() async {
    _preferences = await SharedPreferences.getInstance();

    final Directory support = await getApplicationSupportDirectory();
    _dossier = Directory('${support.path}${Platform.pathSeparator}pages_cifi');
    if (!await _dossier!.exists()) {
      await _dossier!.create(recursive: true);
    }

    _chargerIndex();
    await _purgerPagesExpirees();

    Journal.informer(
      'cache hors ligne pret : ${_index.length} page(s), dossier ${_dossier!.path}',
    );
  }

  // ------------------------------------------------------------ ecriture

  /// Archive le HTML d'une page. Les echecs sont silencieux pour
  /// l'utilisateur : une page non archivee ne doit pas casser la navigation.
  Future<void> archiver({
    required String url,
    required String titre,
    required String html,
  }) async {
    final Directory? dossier = _dossier;
    if (dossier == null || html.trim().isEmpty) {
      return;
    }

    try {
      final String nomFichier = '${_empreinte(url)}.html';
      final File fichier =
          File('${dossier.path}${Platform.pathSeparator}$nomFichier');
      await fichier.writeAsString(html, flush: true);

      _index.removeWhere((PageArchivee page) => page.url == url);
      _index.add(PageArchivee(
        url: url,
        titre: titre.isEmpty ? url : titre,
        nomFichier: nomFichier,
        horodatage: DateTime.now(),
      ));

      while (_index.length > _nombreMaximumPages) {
        await _supprimerPage(_index.removeAt(0));
      }

      await _enregistrerIndex();
      Journal.deboguer('page archivee : $url');
    } catch (erreur, pile) {
      Journal.erreur('archivage impossible pour $url', erreur, pile);
    }
  }

  Future<void> memoriserDerniereUrl(String url) async {
    await _preferences?.setString(_cleDerniereUrl, url);
  }

  String? get derniereUrl => _preferences?.getString(_cleDerniereUrl);

  // ------------------------------------------------------------ lecture

  /// Code HTML archive pour [url], ou null si absent.
  Future<String?> lireHtml(String url) async {
    final Directory? dossier = _dossier;
    if (dossier == null) {
      return null;
    }
    final PageArchivee? page = _trouver(url);
    if (page == null) {
      return null;
    }
    final File fichier =
        File('${dossier.path}${Platform.pathSeparator}${page.nomFichier}');
    if (!await fichier.exists()) {
      return null;
    }
    try {
      return await fichier.readAsString();
    } catch (erreur) {
      Journal.alerter('lecture du cache impossible : $erreur');
      return null;
    }
  }

  bool estArchivee(String url) => _trouver(url) != null;

  // ------------------------------------------------------------ entretien

  Future<void> viderTout() async {
    for (final PageArchivee page in List<PageArchivee>.from(_index)) {
      await _supprimerPage(page);
    }
    _index.clear();
    await _enregistrerIndex();
    Journal.informer('cache hors ligne vide');
  }

  Future<void> _purgerPagesExpirees() async {
    final Duration conservation =
        Duration(days: _fonctionnalites.dureeCacheJours);
    final DateTime limite = DateTime.now().subtract(conservation);

    final List<PageArchivee> expirees = _index
        .where((PageArchivee page) => page.horodatage.isBefore(limite))
        .toList(growable: false);

    if (expirees.isEmpty) {
      return;
    }
    for (final PageArchivee page in expirees) {
      await _supprimerPage(page);
      _index.remove(page);
    }
    await _enregistrerIndex();
    Journal.informer('${expirees.length} page(s) expiree(s) supprimee(s)');
  }

  // ------------------------------------------------------------ interne

  PageArchivee? _trouver(String url) {
    for (final PageArchivee page in _index) {
      if (page.url == url) {
        return page;
      }
    }
    return null;
  }

  Future<void> _supprimerPage(PageArchivee page) async {
    final Directory? dossier = _dossier;
    if (dossier == null) {
      return;
    }
    final File fichier =
        File('${dossier.path}${Platform.pathSeparator}${page.nomFichier}');
    if (await fichier.exists()) {
      await fichier.delete();
    }
  }

  void _chargerIndex() {
    _index.clear();
    final String? brut = _preferences?.getString(_cleIndex);
    if (brut == null || brut.isEmpty) {
      return;
    }
    try {
      final List<dynamic> liste = jsonDecode(brut) as List<dynamic>;
      _index.addAll(liste.map((dynamic element) =>
          PageArchivee.depuisCarte(element as Map<String, dynamic>)));
    } catch (erreur) {
      Journal.alerter('index du cache illisible, remise a zero : $erreur');
      _index.clear();
    }
  }

  Future<void> _enregistrerIndex() async {
    final String brut = jsonEncode(
      _index.map((PageArchivee page) => page.versCarte()).toList(),
    );
    await _preferences?.setString(_cleIndex, brut);
  }

  /// Nom de fichier stable et sans caractere interdit, derive de l'URL.
  String _empreinte(String url) {
    int accumulateur = 7;
    for (final int unite in url.codeUnits) {
      accumulateur = (accumulateur * 31 + unite) & 0x7FFFFFFF;
    }
    return 'page_$accumulateur';
  }
}
