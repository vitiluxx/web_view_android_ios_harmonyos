/// Contrat commun a tous les services de l'application.
///
/// Un service est autonome : il ne connait ni l'interface, ni les autres
/// services. Le demarrage se fait une seule fois, depuis
/// [RegistreServices.demarrer].
abstract class Service {
  /// Nom lisible, utilise dans les messages de journal.
  String get nom;

  /// Vrai si la fonctionnalite est activee dans cifi_parametres.json.
  /// Un service inactif n'est jamais initialise.
  bool get estActif;

  /// Preparation du service. Doit tolerer un appel repete.
  Future<void> demarrer();

  /// Liberation des ressources (ecouteurs, flux, minuteurs).
  Future<void> arreter() async {}
}
