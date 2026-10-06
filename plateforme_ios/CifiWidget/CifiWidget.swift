//
//  Widget d'ecran d'accueil iOS (WidgetKit).
//
//  CE FICHIER N'EST PAS COMPILE AUTOMATIQUEMENT.
//  Il doit etre ajoute a la main dans Xcode, en creant une extension
//  "Widget Extension" nommee exactement CifiWidget.
//  Mode operatoire complet : docs/05_fonctionnalites.md, section Widgets.
//
//  Il lit les valeurs ecrites par
//      cifi_application/lib/services/service_widget_accueil.dart
//  via le groupe d'application partage. Le nom du groupe doit etre
//  IDENTIQUE des deux cotes, sinon le widget reste vide.
//

import WidgetKit
import SwiftUI

// Doit correspondre a ServiceWidgetAccueil.groupeApple (cote Dart)
private let groupePartage = "group.td.cifi.tech.navigateur"

private let cleTitre = "cifi_widget_titre"
private let cleResume = "cifi_widget_resume"
private let cleHorodatage = "cifi_widget_horodatage"

/// Une image du widget a un instant donne.
struct ContenuCifi: TimelineEntry {
    let date: Date
    let titre: String
    let resume: String
    let horodatage: String
}

/// Fournit les contenus a WidgetKit en lisant le stockage partage.
struct FournisseurCifi: TimelineProvider {

    func placeholder(in context: Context) -> ContenuCifi {
        ContenuCifi(
            date: Date(),
            titre: "CiFi Tech",
            resume: "Appuyez pour ouvrir l application.",
            horodatage: ""
        )
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (ContenuCifi) -> Void) {
        completion(lireContenu())
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<ContenuCifi>) -> Void) {
        let contenu = lireContenu()
        // Rafraichissement de securite dans 30 minutes : les mises a jour
        // reelles viennent de l'application, pas du minuteur.
        let prochain = Calendar.current.date(byAdding: .minute,
                                             value: 30,
                                             to: Date()) ?? Date()
        completion(Timeline(entries: [contenu], policy: .after(prochain)))
    }

    private func lireContenu() -> ContenuCifi {
        let stockage = UserDefaults(suiteName: groupePartage)
        return ContenuCifi(
            date: Date(),
            titre: stockage?.string(forKey: cleTitre) ?? "CiFi Tech",
            resume: stockage?.string(forKey: cleResume)
                ?? "Appuyez pour ouvrir l application.",
            horodatage: stockage?.string(forKey: cleHorodatage) ?? ""
        )
    }
}

/// Rendu graphique. Les couleurs reprennent apparence.couleur_primaire
/// du fichier de parametres : adaptez-les si vous changez la marque.
struct VueCifiWidget: View {
    var contenu: ContenuCifi

    private let couleurPrimaire = Color(
        red: 11.0 / 255.0,
        green: 95.0 / 255.0,
        blue: 255.0 / 255.0
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(contenu.titre)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(contenu.resume)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(3)

            Spacer(minLength: 0)

            Text(contenu.horodatage)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.65))
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(couleurPrimaire)
    }
}

@main
struct CifiWidget: Widget {
    let kind = "CifiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FournisseurCifi()) { contenu in
            if #available(iOS 17.0, *) {
                VueCifiWidget(contenu: contenu)
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                VueCifiWidget(contenu: contenu)
            }
        }
        .configurationDisplayName("CiFi Tech")
        .description("Derniere page consultee et acces direct a l application.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
