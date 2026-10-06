import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../composants/bandeau_reseau.dart';
import '../composants/fabrique_page_hors_ligne.dart';
import '../composants/indicateur_chargement.dart';
import '../composants/menu_actions.dart';
import '../configuration/palette_couleurs.dart';
import '../configuration/parametres_application.dart';
import '../noyau/journal.dart';
import '../noyau/registre_services.dart';
import '../passerelle/passerelle_javascript.dart';
import 'ecran_hors_ligne.dart';
import 'ecran_scanner_qr.dart';

/// Ecran unique de l'application : le site cible, augmente des
/// fonctionnalites natives.
///
/// L'ecran orchestre, il n'implemente rien : chaque capacite vient d'un
/// service du registre.
class EcranNavigateur extends StatefulWidget {
  const EcranNavigateur({super.key, required this.registre});

  final RegistreServices registre;

  @override
  State<EcranNavigateur> createState() => _EtatEcranNavigateur();
}

class _EtatEcranNavigateur extends State<EcranNavigateur> {
  InAppWebViewController? _controleur;
  PullToRefreshController? _controleurRafraichissement;
  late final PasserelleJavaScript _passerelle;
  late final FabriquePageHorsLigne _fabriqueHorsLigne;
  late final PaletteCouleurs _palette;

  double _progression = 0;
  bool _premierRenduTermine = false;
  bool _pageHorsLigneAffichee = false;
  String _urlCourante = '';

  ParametresApplication get _parametres => widget.registre.parametres;
  Fonctionnalites get _fonctionnalites => _parametres.fonctionnalites;

  @override
  void initState() {
    super.initState();

    _palette = PaletteCouleurs.depuisParametres();
    _passerelle = PasserelleJavaScript(widget.registre);
    _fabriqueHorsLigne = FabriquePageHorsLigne(_parametres);
    _urlCourante = _parametres.site.urlAccueil;

    if (_fonctionnalites.tirerPourRafraichir) {
      _controleurRafraichissement = PullToRefreshController(
        settings: PullToRefreshSettings(color: _palette.primaire),
        onRefresh: _rafraichir,
      );
    }

    widget.registre.notifications.urlDemandee
        .addListener(_traiterUrlDeNotification);
    widget.registre.connectivite.enLigne.addListener(_traiterChangementReseau);
  }

  @override
  void dispose() {
    widget.registre.notifications.urlDemandee
        .removeListener(_traiterUrlDeNotification);
    widget.registre.connectivite.enLigne
        .removeListener(_traiterChangementReseau);
    super.dispose();
  }

  // ------------------------------------------------------------ reglages WebView

  InAppWebViewSettings get _reglagesWebView {
    final SiteCible site = _parametres.site;
    return InAppWebViewSettings(
      javaScriptEnabled: true,
      transparentBackground: true,
      supportZoom: site.autoriserZoom,
      disableHorizontalScroll: false,
      mediaPlaybackRequiresUserGesture: false,
      useShouldOverrideUrlLoading: true,
      useOnDownloadStart: true,
      cacheEnabled: true,
      // Le cache systeme sert la navigation ordinaire ; notre service
      // de cache prend le relais quand le reseau tombe completement.
      cacheMode: CacheMode.LOAD_DEFAULT,
      // Suffixe ajoute a l'agent utilisateur d'origine : le site peut
      // ainsi reconnaitre l'application et activer ses specificites.
      applicationNameForUserAgent: site.agentUtilisateurSuffixe,
      allowsInlineMediaPlayback: true,
      allowFileAccess: _fonctionnalites.accesFichiers,
      allowContentAccess: _fonctionnalites.accesFichiers,
      geolocationEnabled: _fonctionnalites.accesGeolocalisation,
      disableLongPressContextMenuOnLinks: false,
      disableContextMenu: !site.autoriserSelectionTexte,
      verticalScrollBarEnabled: false,
      horizontalScrollBarEnabled: false,
    );
  }

  // ------------------------------------------------------------ cycle de la page

  void _surWebViewCreee(InAppWebViewController controleur) {
    _controleur = controleur;
    _passerelle.brancher(controleur);

    controleur.addJavaScriptHandler(
      handlerName: 'cifiHorsLigne.reessayer',
      callback: (List<dynamic> arguments) {
        _rafraichir();
        return null;
      },
    );

    controleur.addJavaScriptHandler(
      handlerName: 'cifiHorsLigne.ouvrirArchives',
      callback: (List<dynamic> arguments) {
        _ouvrirArchives();
        return null;
      },
    );
  }

  void _surDebutChargement(InAppWebViewController controleur, WebUri? url) {
    if (url == null) {
      return;
    }
    setState(() {
      _urlCourante = url.toString();
      _progression = 0.02;
    });
  }

  Future<void> _surFinChargement(
    InAppWebViewController controleur,
    WebUri? url,
  ) async {
    _controleurRafraichissement?.endRefreshing();

    setState(() {
      _progression = 1;
      _premierRenduTermine = true;
    });

    if (url == null || _pageHorsLigneAffichee) {
      return;
    }

    final String adresse = url.toString();
    await controleur.evaluateJavascript(
      source: PasserelleJavaScript.scriptInjecte,
    );

    await widget.registre.cache.memoriserDerniereUrl(adresse);
    await _archiverPageCourante(controleur, adresse);
    await _mettreAJourWidget(controleur, adresse);
  }

  Future<void> _archiverPageCourante(
    InAppWebViewController controleur,
    String adresse,
  ) async {
    if (!_fonctionnalites.modeHorsLigne) {
      return;
    }
    if (!widget.registre.connectivite.enLigne.value) {
      return;
    }
    final String? html = await controleur.getHtml();
    if (html == null) {
      return;
    }
    await widget.registre.cache.archiver(
      url: adresse,
      titre: await controleur.getTitle() ?? adresse,
      html: html,
    );
  }

  Future<void> _mettreAJourWidget(
    InAppWebViewController controleur,
    String adresse,
  ) async {
    if (!_fonctionnalites.widgetEcranAccueil) {
      return;
    }
    await widget.registre.widgetAccueil.mettreAJour(
      titre: _parametres.identite.nomAffiche,
      resume: await controleur.getTitle() ?? 'Derniere page consultee',
      url: adresse,
    );
  }

  void _surProgression(InAppWebViewController controleur, int pourcentage) {
    setState(() => _progression = pourcentage / 100);
  }

  // ------------------------------------------------------------ navigation

  Future<NavigationActionPolicy> _surDemandeNavigation(
    InAppWebViewController controleur,
    NavigationAction action,
  ) async {
    final WebUri? url = action.request.url;
    if (url == null) {
      return NavigationActionPolicy.ALLOW;
    }

    // Protocoles systeme : telephone, courriel, SMS, boutiques.
    const List<String> protocolesSystemes = <String>[
      'tel',
      'mailto',
      'sms',
      'whatsapp',
      'market',
      'intent',
    ];
    if (protocolesSystemes.contains(url.scheme)) {
      await _ouvrirAvecSysteme(url);
      return NavigationActionPolicy.CANCEL;
    }

    final bool interne = _parametres.site.estInterne(url);
    if (!interne && _parametres.site.ouvrirDomainesExternesDansNavigateur) {
      await _ouvrirAvecSysteme(url);
      return NavigationActionPolicy.CANCEL;
    }

    if (interne) {
      _pageHorsLigneAffichee = false;
    }
    return NavigationActionPolicy.ALLOW;
  }

  Future<void> _ouvrirAvecSysteme(WebUri url) async {
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (erreur) {
      Journal.alerter('ouverture externe refusee pour $url : $erreur');
    }
  }

  Future<void> _retourEnArriere() async {
    final InAppWebViewController? controleur = _controleur;
    if (controleur == null) {
      return;
    }
    if (await controleur.canGoBack()) {
      await widget.registre.materiel.vibrer(dureeMillisecondes: 18);
      await controleur.goBack();
      return;
    }
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  // ------------------------------------------------------------ hors ligne

  void _traiterChangementReseau() {
    final bool enLigne = widget.registre.connectivite.enLigne.value;
    if (enLigne && _pageHorsLigneAffichee) {
      _rafraichir();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _rafraichir() async {
    final InAppWebViewController? controleur = _controleur;
    if (controleur == null) {
      return;
    }
    if (_pageHorsLigneAffichee) {
      _pageHorsLigneAffichee = false;
      await controleur.loadUrl(
        urlRequest: URLRequest(url: WebUri(_urlCourante)),
      );
      return;
    }
    await controleur.reload();
  }

  Future<void> _surErreurChargement(
    InAppWebViewController controleur,
    WebResourceRequest requete,
    WebResourceError erreur,
  ) async {
    _controleurRafraichissement?.endRefreshing();

    // Une image ou un script absent ne doit pas remplacer la page entiere.
    if (requete.isForMainFrame == false) {
      return;
    }
    Journal.alerter('chargement echoue : ${erreur.description}');
    await _afficherSecoursHorsLigne(controleur, requete.url.toString());
  }

  /// Tente d'abord la version enregistree de la page ; a defaut, montre
  /// la page hors ligne locale.
  Future<void> _afficherSecoursHorsLigne(
    InAppWebViewController controleur,
    String adresse,
  ) async {
    if (_fonctionnalites.modeHorsLigne) {
      final String? htmlArchive = await widget.registre.cache.lireHtml(adresse);
      if (htmlArchive != null) {
        _pageHorsLigneAffichee = true;
        await controleur.loadData(
          data: htmlArchive,
          baseUrl: WebUri(adresse),
          mimeType: 'text/html',
          encoding: 'utf-8',
        );
        setState(() => _premierRenduTermine = true);
        return;
      }
    }

    if (!mounted) {
      return;
    }
    final bool modeSombre =
        Theme.of(context).brightness == Brightness.dark;
    final String html = await _fabriqueHorsLigne.construire(
      urlDemandee: adresse,
      modeSombre: modeSombre,
    );

    _pageHorsLigneAffichee = true;
    await controleur.loadData(
      data: html,
      mimeType: 'text/html',
      encoding: 'utf-8',
    );
    setState(() => _premierRenduTermine = true);
  }

  Future<void> _ouvrirArchives() async {
    if (!mounted) {
      return;
    }
    final String? urlChoisie = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext contexte) =>
            EcranHorsLigne(registre: widget.registre),
      ),
    );
    if (urlChoisie == null) {
      return;
    }
    final InAppWebViewController? controleur = _controleur;
    if (controleur == null) {
      return;
    }
    final String? html = await widget.registre.cache.lireHtml(urlChoisie);
    if (html == null) {
      return;
    }
    _pageHorsLigneAffichee = true;
    await controleur.loadData(
      data: html,
      baseUrl: WebUri(urlChoisie),
      mimeType: 'text/html',
      encoding: 'utf-8',
    );
  }

  // ------------------------------------------------------------ notifications

  void _traiterUrlDeNotification() {
    final String? url = widget.registre.notifications.urlDemandee.value;
    if (url == null || url.isEmpty) {
      return;
    }
    widget.registre.notifications.urlDemandee.value = null;
    _controleur?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  // ------------------------------------------------------------ menu d'actions

  /// Construit la liste des actions selon les fonctionnalites activees :
  /// une entree absente du fichier de parametres n'apparait jamais.
  List<ActionNative> _construireActions() {
    final List<ActionNative> actions = <ActionNative>[
      ActionNative(
        icone: Icons.refresh,
        libelle: 'Rafraichir',
        description: 'Recharger la page depuis le site',
        action: _rafraichir,
      ),
    ];

    if (_fonctionnalites.partageNatif) {
      actions.add(ActionNative(
        icone: Icons.ios_share,
        libelle: 'Partager cette page',
        description: 'Via le menu de partage du telephone',
        action: _partagerPageCourante,
      ));
    }

    if (_fonctionnalites.modeHorsLigne) {
      actions.add(ActionNative(
        icone: Icons.cloud_done_outlined,
        libelle: 'Pages enregistrees',
        description: 'Relire sans connexion',
        action: _ouvrirArchives,
      ));
    }

    if (_fonctionnalites.scannerQr) {
      actions.add(ActionNative(
        icone: Icons.qr_code_scanner,
        libelle: 'Scanner un code',
        description: 'Ouvrir l adresse contenue dans un code QR',
        action: _scannerCode,
      ));
    }

    actions.add(ActionNative(
      icone: Icons.info_outline,
      libelle: 'A propos',
      description: _parametres.identite.editeur,
      action: _afficherAPropos,
    ));

    return actions;
  }

  Future<void> _partagerPageCourante() async {
    final String titre =
        await _controleur?.getTitle() ?? _parametres.identite.nomAffiche;
    await widget.registre.materiel.partager(
      texte: '$titre\n$_urlCourante',
      sujet: titre,
    );
  }

  Future<void> _scannerCode() async {
    if (!mounted) {
      return;
    }
    final String? contenu = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext contexte) =>
            EcranScannerQr(couleurAccent: _palette.primaire),
      ),
    );
    if (contenu == null || !mounted) {
      return;
    }

    await widget.registre.materiel.vibrer();

    final Uri? adresse = Uri.tryParse(contenu);
    if (adresse != null && adresse.hasScheme && adresse.host.isNotEmpty) {
      if (_parametres.site.estInterne(adresse)) {
        await _controleur?.loadUrl(
          urlRequest: URLRequest(url: WebUri(contenu)),
        );
      } else {
        await _ouvrirAvecSysteme(WebUri(contenu));
      }
      return;
    }

    // Texte simple : on le remet au site, qui en fait ce qu'il veut.
    await _controleur?.evaluateJavascript(
      source: 'document.dispatchEvent(new CustomEvent('
          '"cifi-code-scanne", { detail: ${_enChaineJs(contenu)} }));',
    );
  }

  /// Encode une chaine en litteral JavaScript valide.
  /// jsonEncode produit exactement la syntaxe attendue, guillemets inclus.
  String _enChaineJs(String brut) => jsonEncode(brut);

  Future<void> _afficherAPropos() async {
    final IdentiteApplication identite = _parametres.identite;
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext contexte) => AlertDialog(
        title: Text(identite.nomAffiche),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Version ${identite.versionAffichee}'),
            const SizedBox(height: 10),
            Text(identite.editeur),
            Text('${identite.ville}, ${identite.pays}'),
            const SizedBox(height: 10),
            Text(
              widget.registre.materiel.descriptionAppareil,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ autorisations WebView

  Future<PermissionResponse?> _surDemandeAutorisation(
    InAppWebViewController controleur,
    PermissionRequest requete,
  ) async {
    final bool accordee = requete.resources.every((PermissionResourceType type) {
      if (type == PermissionResourceType.CAMERA) {
        return _fonctionnalites.accesCamera;
      }
      if (type == PermissionResourceType.MICROPHONE) {
        return _fonctionnalites.accesMicrophone;
      }
      return true;
    });

    return PermissionResponse(
      resources: requete.resources,
      action: accordee
          ? PermissionResponseAction.GRANT
          : PermissionResponseAction.DENY,
    );
  }

  // ------------------------------------------------------------ rendu

  @override
  Widget build(BuildContext context) {
    final bool enLigne = widget.registre.connectivite.enLigne.value;

    // Quand le geste retour est desactive, on laisse le systeme
    // fermer l'application plutot que de remonter l'historique du site.
    return PopScope(
      canPop: !_fonctionnalites.navigationGestesRetour,
      onPopInvokedWithResult: (bool sorti, Object? resultat) {
        if (!sorti) {
          _retourEnArriere();
        }
      },
      child: Scaffold(
        floatingActionButton: FloatingActionButton.small(
          tooltip: 'Actions',
          backgroundColor: _palette.primaire,
          foregroundColor: Colors.white,
          onPressed: () => MenuActions.afficher(context, _construireActions()),
          child: const Icon(Icons.more_horiz),
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              if (_fonctionnalites.barreProgression)
                BarreProgressionChargement(
                  progression: _progression,
                  couleur: _palette.primaire,
                ),
              BandeauReseau(
                enLigne: enLigne,
                pageDisponibleHorsLigne:
                    widget.registre.cache.estArchivee(_urlCourante),
                surReessayer: _rafraichir,
              ),
              Expanded(
                child: Stack(
                  children: <Widget>[
                    InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(_parametres.site.urlAccueil),
                      ),
                      initialSettings: _reglagesWebView,
                      pullToRefreshController: _controleurRafraichissement,
                      onWebViewCreated: _surWebViewCreee,
                      onLoadStart: _surDebutChargement,
                      onLoadStop: _surFinChargement,
                      onProgressChanged: _surProgression,
                      onReceivedError: _surErreurChargement,
                      onPermissionRequest: _surDemandeAutorisation,
                      shouldOverrideUrlLoading: _surDemandeNavigation,
                    ),
                    VoileChargement(
                      visible: !_premierRenduTermine,
                      couleurFond: Theme.of(context).scaffoldBackgroundColor,
                      couleurAccent: _palette.primaire,
                      libelle: _parametres.identite.nomAffiche,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
