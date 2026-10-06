import 'package:flutter/foundation.dart';

/// Niveaux de gravite des messages de journal.
enum NiveauJournal { debogage, information, alerte, erreur }

/// Journal unique de l'application.
///
/// En mode release rien n'est ecrit sur la sortie standard : seuls les
/// messages de niveau [NiveauJournal.erreur] remontent, pour ne pas fuiter
/// d'information technique sur un appareil utilisateur.
class Journal {
  const Journal._();

  static const String _prefixe = 'CiFi';

  static void deboguer(String message) =>
      _ecrire(NiveauJournal.debogage, message);

  static void informer(String message) =>
      _ecrire(NiveauJournal.information, message);

  static void alerter(String message) => _ecrire(NiveauJournal.alerte, message);

  static void erreur(String message, [Object? cause, StackTrace? pile]) {
    _ecrire(NiveauJournal.erreur, message);
    if (cause != null) {
      _ecrire(NiveauJournal.erreur, 'cause : $cause');
    }
    if (pile != null && kDebugMode) {
      debugPrintStack(stackTrace: pile, maxFrames: 8);
    }
  }

  static void _ecrire(NiveauJournal niveau, String message) {
    final bool visible = kDebugMode || niveau == NiveauJournal.erreur;
    if (!visible) {
      return;
    }
    debugPrint('[$_prefixe][${niveau.name}] $message');
  }
}
