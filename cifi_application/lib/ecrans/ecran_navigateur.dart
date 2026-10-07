import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../composants/bandeau_reseau.dart';
import '../composants/fabrique_page_hors_ligne.dart';
import '../composants/indicateur_chargement.dart';
import '../composants/menu_actions.dart';
import '../composants/tirer_pour_rafraichir.dart';
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
  late final WebViewController _controleur;
  late final PasserelleJavaScript _passerelle;
  late final FabriquePageHorsLigne _fabriqueHorsLigne;
  late final PaletteCouleurs _palette;

  double _progression = 0;
  bool _premierRenduTermine = false;
  bool _pageHorsLigneAffichee = false;
  bool _auSommet = true;
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

    _controleur = _construireControleur();

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

  // ------------------------------------------------------------ construction

  /// Construit le controleur et tous ses reglages.
  ///
  /// Les parametres de creation different selon la plateforme : c'est le
  /// seul endroit du projet ou Android et iOS se separent.
  WebViewController _construireControleur() {
    final SiteCible site = _parametres.site;

    late final PlatformWebViewControllerCreationParams reglagesCreation;
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      reglagesCreation = AndroidWebViewControllerCreationParams();
    } else if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      reglagesCreation = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      reglagesCreation = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controleur =
        WebViewController.fromPlatformCreationParams(reglagesCreation);

    controleur
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..enableZoom(site.autoriserZoom)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: _surProgression,
          onPageStarted: _surDebutChargement,
          onPageFinished: _surFinChargement,
          onWebResourceError: _surErreurChargement,
          onNavigationRequest: _surDemandeNavigation,
        ),
      )
      ..addJavaScriptChannel(
        PasserelleJavaScript.nomCanal,
        onMessageReceived: (JavaScriptMessage message) {
          _passerelle.traiterMessage(message.message);
        },
      )
      ..setOnScrollPositionChange(_surDefilement);

    _passerelle.brancher(controleur);
    _appliquerReglagesPlateforme(controleur);
    _appliquerAgentUtilisateur(controleur, site);

    controleur.loadRequest(Uri.parse(site.urlAccueil));
    return controleur;
  }

  /// Ajoute notre suffixe a l'agent utilisateur d'origine, sans
  /// l'ecraser : le site continue de reconnaitre le vrai navigateur.
  Future<void> _appliquerAgentUtilisateur(
    WebViewController controleur,
    SiteCible site,
  ) async {
    if (site.agentUtilisateurSuffixe.trim().isEmpty) {
      return;
    }
    try {
      final Object resultat =
          await controleur.runJavaScriptReturningResult('navigator.userAgent');
      final String origine = _texteDepuisJavaScript(resultat);
      if (origine.isNotEmpty) {
        await controleur
            .setUserAgent('$origine ${site.agentUtilisateurSuffixe}');
      }
    } catch (erreur) {
      Journal.deboguer('agent utilisateur inchange : $erreur');
    }
  }

  /// Reglages qui n'existent que sur une plateforme donnee.
  void _appliquerReglagesPlateforme(WebViewController controleur) {
    // Type infere : PlatformWebViewController n'est pas reexporte par
    // webview_flutter, et l'ecrire exigerait un import de plus.
    final plateforme = controleur.platform;

    if (plateforme is AndroidWebViewController) {
      plateforme
        ..setMediaPlaybackRequiresUserGesture(false)
        ..setOnShowFileSelector(_choisirFichiersPourLeSite)
        ..setOnPlatformPermissionRequest(_surDemandeAutorisation)
        ..setGeolocationPermissionsPromptCallbacks(
          onShowPrompt: _surDemandePosition,
          onHidePrompt: () {},
        );
    } else if (plateforme is WebKitWebViewController) {
      plateforme.setAllowsBackForwardNavigationGestures(
        _fonctionnalites.navigationGestesRetour,
      );
    }
  }

  // ------------------------------------------------------------ cycle de la page

  void _surDebutChargement(String url) {
    setState(() {
      _urlCourante = url;
      _progression = 0.02;
    });
  }

  Future<void> _surFinChargement(String url) async {
    setState(() {
      _progression = 1;
      _premierRenduTermine = true;
    });

    // Le script est pose a chaque page : une navigation interne remet
    // window.CiFi a zero.
    try {
      await _controleur.runJavaScript(PasserelleJavaScript.scriptInjecte);
    } catch (erreur) {
      Journal.deboguer('passerelle non injectee : $erreur');
    }

    if (_pageHorsLigneAffichee) {
      return;
    }

    await widget.registre.cache.memoriserDerniereUrl(url);
    await _archiverPageCourante(url);
    await _mettreAJourWidget(url);
  }

  void _surProgression(int pourcentage) {
    setState(() => _progression = pourcentage / 100);
  }

  void _surDefilement(ScrollPositionChange position) {
    final bool sommet = position.y <= 1;
    if (sommet != _auSommet) {
      setState(() => _auSommet = sommet);
    }
  }

  Future<void> _archiverPageCourante(String adresse) async {
    if (!_fonctionnalites.modeHorsLigne) {
      return;
    }
    if (!widget.registre.connectivite.enLigne.value) {
      return;
    }
    try {
      final Object resultat = await _controleur
          .runJavaScriptReturningResult('document.documentElement.outerHTML');
      final String html = _texteDepuisJavaScript(resultat);
      if (html.trim().isEmpty) {
        return;
      }
      await widget.registre.cache.archiver(
        url: adresse,
        titre: await _titreCourant(adresse),
        html: html,
      );
    } catch (erreur) {
      Journal.deboguer('archivage ignore : $erreur');
    }
  }

  Future<void> _mettreAJourWidget(String adresse) async {
    if (!_fonctionnalites.widgetEcranAccueil) {
      return;
    }
    await widget.registre.widgetAccueil.mettreAJour(
      titre: _parametres.identite.nomAffiche,
      resume: await _titreCourant('Derniere page consultee'),
      url: adresse,
    );
  }

  Future<String> _titreCourant(String parDefaut) async {
    try {
      final String? titre = await _controleur.getTitle();
      if (titre != null && titre.trim().isNotEmpty) {
        return titre;
      }
    } catch (erreur) {
      Journal.deboguer('titre indisponible : $erreur');
    }
    return parDefaut;
  }

  /// runJavaScriptReturningResult rend une chaine encodee en JSON sur
  /// Android, et la chaine brute sur iOS. On ramene les deux au meme.
  String _texteDepuisJavaScript(Object resultat) {
    final String brut = resultat.toString();
    if (brut.length >= 2 && brut.startsWith('"') && brut.endsWith('"')) {
      try {
        return jsonDecode(brut) as String;
      } catch (erreur) {
        return brut;
      }
    }
    return brut;
  }

  // ------------------------------------------------------------ navigation

  Future<NavigationDecision> _surDemandeNavigation(
    NavigationRequest requete,
  ) async {
    final Uri? url = Uri.tryParse(requete.url);
    if (url == null) {
      return NavigationDecision.navigate;
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
      return NavigationDecision.prevent;
    }

    final bool interne = _parametres.site.estInterne(url);
    if (!interne && _parametres.site.ouvrirDomainesExternesDansNavigateur) {
      await _ouvrirAvecSysteme(url);
      return NavigationDecision.prevent;
    }

    if (interne) {
      _pageHorsLigneAffichee = false;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _ouvrirAvecSysteme(Uri url) async {
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (erreur) {
      Journal.alerter('ouverture externe refusee pour $url : $erreur');
    }
  }

  Future<void> _retourEnArriere() async {
    if (_pageHorsLigneAffichee) {
      await _rafraichir();
      return;
    }
    if (await _controleur.canGoBack()) {
      await widget.registre.materiel.vibrer(dureeMillisecondes: 18);
      await _controleur.goBack();
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
    if (_pageHorsLigneAffichee) {
      _pageHorsLigneAffichee = false;
      await _controleur.loadRequest(Uri.parse(_urlCourante));
      return;
    }
    await _controleur.reload();
  }

  Future<void> _surErreurChargement(WebResourceError erreur) async {
    // Une image ou un script absent ne doit pas remplacer la page entiere.
    if (erreur.isForMainFrame == false) {
      return;
    }
    Journal.alerter('chargement echoue : ${erreur.description}');
    await _afficherSecoursHorsLigne(erreur.url ?? _urlCourante);
  }

  /// Tente d'abord la version enregistree de la page ; a defaut, montre
  /// la page hors ligne locale.
  Future<void> _afficherSecoursHorsLigne(String adresse) async {
    if (_fonctionnalites.modeHorsLigne) {
      final String? htmlArchive = await widget.registre.cache.lireHtml(adresse);
      if (htmlArchive != null) {
        _pageHorsLigneAffichee = true;
        await _controleur.loadHtmlString(htmlArchive, baseUrl: adresse);
        if (mounted) {
          setState(() => _premierRenduTermine = true);
        }
        return;
      }
    }

    if (!mounted) {
      return;
    }
    final bool modeSombre = Theme.of(context).brightness == Brightness.dark;
    final String html = await _fabriqueHorsLigne.construire(
      urlDemandee: adresse,
      modeSombre: modeSombre,
    );

    _pageHorsLigneAffichee = true;
    await _controleur.loadHtmlString(html);
    if (mounted) {
      setState(() => _premierRenduTermine = true);
    }
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
    final String? html = await widget.registre.cache.lireHtml(urlChoisie);
    if (html == null) {
      return;
    }
    _pageHorsLigneAffichee = true;
    await _controleur.loadHtmlString(html, baseUrl: urlChoisie);
  }

  // ------------------------------------------------------------ notifications

  void _traiterUrlDeNotification() {
    final String? url = widget.registre.notifications.urlDemandee.value;
    if (url == null || url.isEmpty) {
      return;
    }
    widget.registre.notifications.urlDemandee.value = null;
    final Uri? adresse = Uri.tryParse(url);
    if (adresse != null) {
      _controleur.loadRequest(adresse);
    }
  }

  // ------------------------------------------------------------ materiel du site

  /// Repond au clic sur un <input type="file"> de la page.
  Future<List<String>> _choisirFichiersPourLeSite(
    FileSelectorParams reglages,
  ) async {
    if (!_fonctionnalites.accesFichiers && !_fonctionnalites.accesGalerie) {
      return <String>[];
    }

    // Le site demande explicitement une image.
    final bool veutImage =
        reglages.acceptTypes.any((String type) => type.startsWith('image/'));

    String? chemin;
    if (veutImage && _fonctionnalites.accesGalerie) {
      chemin = await widget.registre.materiel.choisirImage();
    }
    chemin ??= await widget.registre.materiel.choisirFichier();

    if (chemin == null) {
      return <String>[];
    }
    return <String>[Uri.file(chemin).toString()];
  }

  /// Autorisations demandees par la page elle-meme (camera, micro).
  Future<void> _surDemandeAutorisation(
    PlatformWebViewPermissionRequest requete,
  ) async {
    final bool accordee =
        requete.types.every((WebViewPermissionResourceType type) {
      if (type == WebViewPermissionResourceType.camera) {
        return _fonctionnalites.accesCamera;
      }
      if (type == WebViewPermissionResourceType.microphone) {
        return _fonctionnalites.accesMicrophone;
      }
      return true;
    });

    if (accordee) {
      await requete.grant();
    } else {
      await requete.deny();
    }
  }

  /// Autorisation de geolocalisation demandee par la page.
  ///
  /// La reponse ne vaut que pour la page affichee : le service de
  /// geolocalisation demande de son cote l'autorisation systeme.
  /// retain reste a false, pour que la decision soit redemandee a
  /// chaque page plutot que gardee indefiniment.
  Future<GeolocationPermissionsResponse> _surDemandePosition(
    GeolocationPermissionsRequestParams requete,
  ) async {
    Journal.deboguer('position demandee par ${requete.origin}');
    return GeolocationPermissionsResponse(
      allow: _fonctionnalites.accesGeolocalisation,
      retain: false,
    );
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
    final String titre = await _titreCourant(_parametres.identite.nomAffiche);
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
        await _controleur.loadRequest(adresse);
      } else {
        await _ouvrirAvecSysteme(adresse);
      }
      return;
    }

    // Texte simple : on le remet au site, qui en fait ce qu'il veut.
    await _controleur.runJavaScript(
      'document.dispatchEvent(new CustomEvent('
      '"cifi-code-scanne", { detail: ${jsonEncode(contenu)} }));',
    );
  }

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

  // ------------------------------------------------------------ rendu

  @override
  Widget build(BuildContext context) {
    final bool enLigne = widget.registre.connectivite.enLigne.value;

    // Quand le geste retour est desactive, on laisse le systeme fermer
    // l'application plutot que de remonter l'historique du site.
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
                    TirerPourRafraichir(
                      actif: _fonctionnalites.tirerPourRafraichir,
                      auSommet: _auSommet,
                      couleur: _palette.primaire,
                      surRafraichir: _rafraichir,
                      enfant: WebViewWidget(controller: _controleur),
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
