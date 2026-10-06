package td.cifi.tech.cifi_navigateur

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Fournisseur du widget d'ecran d'accueil Android.
 *
 * Il ne calcule rien : il lit les valeurs deposees par
 * cifi_application/lib/services/service_widget_accueil.dart
 * et les peint dans res/layout/cifi_widget_disposition.xml
 *
 * Les cles doivent rester identiques de part et d'autre.
 */
class CifiFournisseurWidget : AppWidgetProvider() {

    private companion object {
        const val CLE_TITRE = "cifi_widget_titre"
        const val CLE_RESUME = "cifi_widget_resume"
        const val CLE_HORODATAGE = "cifi_widget_horodatage"

        const val TITRE_PAR_DEFAUT = "CiFi Tech"
        const val RESUME_PAR_DEFAUT = "Appuyez pour ouvrir l application."
    }

    override fun onUpdate(
        contexte: Context,
        gestionnaire: AppWidgetManager,
        identifiants: IntArray
    ) {
        val donnees = HomeWidgetPlugin.getData(contexte)

        val titre = donnees.getString(CLE_TITRE, TITRE_PAR_DEFAUT)
            ?: TITRE_PAR_DEFAUT
        val resume = donnees.getString(CLE_RESUME, RESUME_PAR_DEFAUT)
            ?: RESUME_PAR_DEFAUT
        val horodatage = donnees.getString(CLE_HORODATAGE, "") ?: ""

        identifiants.forEach { identifiant ->
            val vues = RemoteViews(contexte.packageName, R.layout.cifi_widget_disposition)

            vues.setTextViewText(R.id.cifi_widget_titre, titre)
            vues.setTextViewText(R.id.cifi_widget_resume, resume)
            vues.setTextViewText(R.id.cifi_widget_horodatage, horodatage)
            vues.setOnClickPendingIntent(
                R.id.cifi_widget_racine,
                construireIntentionOuverture(contexte)
            )

            gestionnaire.updateAppWidget(identifiant, vues)
        }
    }

    /** Un appui sur le widget ramene l'application au premier plan. */
    private fun construireIntentionOuverture(contexte: Context): PendingIntent {
        val intention = Intent(contexte, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            contexte,
            0,
            intention,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
