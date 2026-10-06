import 'package:home_widget/home_widget.dart';

import '../configuration/parametres_application.dart';
import '../noyau/journal.dart';
import '../noyau/service.dart';

/// Widget pose sur l'ecran d'accueil du telephone.
///
/// Android : fournisseur declare dans
///   plateforme_android/app/src/main/res/xml/cifi_widget_information.xml
/// iOS : extension WidgetKit a creer dans Xcode
///   (voir docs/05_fonctionnalites.md, section Widgets)
///
/// Le service se contente de deposer des valeurs partagees et de demander
/// un rafraichissement. Le rendu graphique appartient a chaque plateforme.
class ServiceWidgetAccueil extends Service {
  ServiceWidgetAccueil(this._fonctionnalites, this._identite);

  final Fonctionnalites _fonctionnalites;
  final IdentiteApplication _identite;

  /// Identifiants partages avec le code natif. Ces chaines doivent etre
  /// identiques cote Android et cote iOS, sinon le widget reste vide.
  static const String cleTitre = 'cifi_widget_titre';
  static const String cleResume = 'cifi_widget_resume';
  static const String cleHorodatage = 'cifi_widget_horodatage';
  static const String cleUrl = 'cifi_widget_url';

  /// Nom complet de la classe Android du fournisseur de widget.
  /// Il depend du "namespace" du code Android, qui reste fixe meme quand
  /// l'applicationId change : c'est pourquoi il est ecrit en entier.
  /// Voir plateforme_android/app/src/main/AndroidManifest.xml
  static const String _classeWidgetAndroid =
      'td.cifi.tech.cifi_navigateur.CifiFournisseurWidget';

  static const String _nomWidgetApple = 'CifiWidget';

  /// Groupe d'application iOS. A creer dans Xcode avec exactement ce nom,
  /// sinon le widget iOS ne lira aucune donnee.
  static const String groupeApple = 'group.td.cifi.tech.navigateur';

  @override
  String get nom => 'widget ecran accueil';

  @override
  bool get estActif => _fonctionnalites.widgetEcranAccueil;

  @override
  Future<void> demarrer() async {
    try {
      await HomeWidget.setAppGroupId(groupeApple);
      await mettreAJour(
        titre: _identite.nomAffiche,
        resume: 'Appuyez pour ouvrir l application.',
        url: '',
      );
      Journal.informer('widget d ecran d accueil initialise');
    } catch (erreur) {
      Journal.alerter('widget d ecran d accueil indisponible : $erreur');
    }
  }

  /// Ecrit le contenu du widget puis demande son rafraichissement.
  Future<void> mettreAJour({
    required String titre,
    required String resume,
    required String url,
  }) async {
    if (!estActif) {
      return;
    }
    try {
      await HomeWidget.saveWidgetData<String>(cleTitre, titre);
      await HomeWidget.saveWidgetData<String>(cleResume, resume);
      await HomeWidget.saveWidgetData<String>(cleUrl, url);
      await HomeWidget.saveWidgetData<String>(
        cleHorodatage,
        _horodatageLisible(DateTime.now()),
      );
      await HomeWidget.updateWidget(
        qualifiedAndroidName: _classeWidgetAndroid,
        iOSName: _nomWidgetApple,
      );
    } catch (erreur) {
      Journal.alerter('mise a jour du widget impossible : $erreur');
    }
  }

  /// Format court jj/mm a hh:mm, sans dependance de localisation externe.
  String _horodatageLisible(DateTime instant) {
    String deuxChiffres(int valeur) => valeur.toString().padLeft(2, '0');
    return '${deuxChiffres(instant.day)}/${deuxChiffres(instant.month)} '
        'a ${deuxChiffres(instant.hour)}:${deuxChiffres(instant.minute)}';
  }
}
