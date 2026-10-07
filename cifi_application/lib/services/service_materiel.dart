import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vibration/vibration.dart';

import '../configuration/parametres_application.dart';
import '../noyau/journal.dart';
import '../noyau/service.dart';

/// Acces au materiel de l'appareil.
///
/// Chaque methode verifie d'abord le drapeau correspondant dans
/// cifi_parametres.json : une fonctionnalite desactivee renvoie null
/// plutot que de demander une autorisation inutile.
class ServiceMateriel extends Service {
  ServiceMateriel(this._fonctionnalites);

  final Fonctionnalites _fonctionnalites;

  final ImagePicker _selecteurImage = ImagePicker();

  bool _vibrationDisponible = false;
  String _descriptionAppareil = 'inconnu';
  String _versionApplication = '';

  @override
  String get nom => 'materiel';

  @override
  bool get estActif => true;

  String get descriptionAppareil => _descriptionAppareil;
  String get versionApplication => _versionApplication;

  @override
  Future<void> demarrer() async {
    await _releverAppareil();
    if (_fonctionnalites.vibration) {
      try {
        _vibrationDisponible = await Vibration.hasVibrator();
      } catch (erreur) {
        Journal.deboguer('vibreur indetectable : $erreur');
      }
    }
    Journal.informer('service materiel pret sur $_descriptionAppareil');
  }

  // ------------------------------------------------------------ photo

  /// Prend une photo avec l'appareil. Retourne le chemin du fichier.
  Future<String?> prendrePhoto() async {
    if (!_fonctionnalites.accesCamera) {
      return null;
    }
    if (!await _demanderAutorisation(Permission.camera)) {
      return null;
    }
    try {
      final XFile? image = await _selecteurImage.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      return image?.path;
    } catch (erreur) {
      Journal.alerter('prise de photo impossible : $erreur');
      return null;
    }
  }

  /// Choisit une image dans la galerie.
  Future<String?> choisirImage() async {
    if (!_fonctionnalites.accesGalerie) {
      return null;
    }
    try {
      final XFile? image = await _selecteurImage.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      return image?.path;
    } catch (erreur) {
      Journal.alerter('selection d image impossible : $erreur');
      return null;
    }
  }

  // ------------------------------------------------------------ fichiers

  /// Choisit un fichier quelconque. Retourne son chemin absolu.
  Future<String?> choisirFichier() async {
    if (!_fonctionnalites.accesFichiers) {
      return null;
    }
    try {
      // file_picker 13 : methode statique, qui rend directement la liste
      // des fichiers choisis. Le chemin est nul pour un fichier distant,
      // d'ou le passage par firstOrNull plutot que par first.
      final List<PlatformFile> fichiers = await FilePicker.pickFiles();
      if (fichiers.isEmpty) {
        return null;
      }
      return fichiers.first.path;
    } catch (erreur) {
      Journal.alerter('selection de fichier impossible : $erreur');
      return null;
    }
  }

  // ------------------------------------------------------------ retours physiques

  /// Vibration courte, en retour a une action de l'utilisateur.
  Future<void> vibrer({int dureeMillisecondes = 40}) async {
    if (!_fonctionnalites.vibration || !_vibrationDisponible) {
      return;
    }
    try {
      await Vibration.vibrate(duration: dureeMillisecondes);
    } catch (erreur) {
      Journal.deboguer('vibration refusee : $erreur');
    }
  }

  // ------------------------------------------------------------ partage

  /// Ouvre la feuille de partage native du systeme.
  Future<void> partager({required String texte, String? sujet}) async {
    if (!_fonctionnalites.partageNatif) {
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(text: texte, subject: sujet),
      );
    } catch (erreur) {
      Journal.alerter('partage impossible : $erreur');
    }
  }

  /// Partage un fichier local (document telecharge, capture...).
  Future<void> partagerFichier(String chemin, {String? texte}) async {
    if (!_fonctionnalites.partageNatif) {
      return;
    }
    if (!await File(chemin).exists()) {
      Journal.alerter('fichier a partager introuvable : $chemin');
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(files: <XFile>[XFile(chemin)], text: texte),
      );
    } catch (erreur) {
      Journal.alerter('partage de fichier impossible : $erreur');
    }
  }

  // ------------------------------------------------------------ autorisations

  Future<bool> _demanderAutorisation(Permission permission) async {
    final PermissionStatus etat = await permission.status;
    if (etat.isGranted) {
      return true;
    }
    if (etat.isPermanentlyDenied) {
      Journal.alerter('autorisation refusee definitivement : $permission');
      return false;
    }
    return (await permission.request()).isGranted;
  }

  /// Demande en une fois les autorisations necessaires aux fonctionnalites
  /// activees. Appele au premier lancement par l'ecran de demarrage.
  Future<void> demanderAutorisationsInitiales() async {
    final List<Permission> aDemander = <Permission>[];
    if (_fonctionnalites.accesCamera) {
      aDemander.add(Permission.camera);
    }
    if (_fonctionnalites.accesMicrophone) {
      aDemander.add(Permission.microphone);
    }
    if (aDemander.isEmpty) {
      return;
    }
    try {
      await aDemander.request();
    } catch (erreur) {
      Journal.alerter('demande d autorisations interrompue : $erreur');
    }
  }

  // ------------------------------------------------------------ interne

  Future<void> _releverAppareil() async {
    try {
      final PackageInfo paquet = await PackageInfo.fromPlatform();
      _versionApplication = '${paquet.version}+${paquet.buildNumber}';
    } catch (erreur) {
      Journal.deboguer('version de l application inconnue : $erreur');
    }

    try {
      final DeviceInfoPlugin informations = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo android = await informations.androidInfo;
        _descriptionAppareil =
            '${android.manufacturer} ${android.model} (Android ${android.version.release})';
      } else if (Platform.isIOS) {
        final IosDeviceInfo apple = await informations.iosInfo;
        _descriptionAppareil =
            '${apple.utsname.machine} (iOS ${apple.systemVersion})';
      }
    } catch (erreur) {
      Journal.deboguer('description de l appareil inconnue : $erreur');
    }
  }
}
