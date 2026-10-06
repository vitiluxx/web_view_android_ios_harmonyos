# ---------------------------------------------------------------------------
# Regles de reduction du code pour la version release.
#
# Recopie par scripts/initialiser_projet.ps1 vers :
#     cifi_application/android/app/proguard-regles.pro
#
# On conserve ce que les greffons appellent par reflexion : sans ces lignes,
# l'APK release compile mais plante au lancement.
# ---------------------------------------------------------------------------

# --- Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- WebView
-keep class com.pichillilorenzo.flutter_inappwebview_android.** { *; }
-keep class android.webkit.** { *; }

# --- Firebase et notifications
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class * extends com.google.firebase.messaging.FirebaseMessagingService { *; }

# --- Widget d'ecran d'accueil
-keep class td.cifi.tech.cifi_navigateur.CifiFournisseurWidget { *; }
-keep class es.antonborri.home_widget.** { *; }

# --- Lecture de codes QR
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# --- Objets serialises par les greffons
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keepattributes Signature, InnerClasses, EnclosingMethod
-keepattributes RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations
