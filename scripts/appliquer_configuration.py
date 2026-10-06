#!/usr/bin/env python3
"""
Propage configuration/cifi_parametres.json vers les trois plateformes.

Un seul moteur, appele par les deux lanceurs :
    scripts/appliquer_configuration.ps1   (Windows)
    scripts/appliquer_configuration.sh    (Mac / Linux)

Ce que le script modifie, dans l'ordre :
    1. copie des parametres et des pages vers Flutter et HarmonyOS
    2. copie des logos
    3. pubspec.yaml          : splash screen et icone
    4. build.gradle.kts      : applicationId, versionCode, versionName
    5. AndroidManifest.xml   : nom affiche, domaine, canal de notification
    6. cifi_widget_fond.xml  : couleur du widget
    7. Info.plist            : nom affiche iOS
    8. project.pbxproj       : identifiant de paquet iOS
    9. AppScope/app.json5    : bundleName et version HarmonyOS
   10. string.json / color.json / module.json5 : nom, couleurs, domaine

Le script n'ecrit RIEN hors du projet et signale chaque fichier touche.
"""

import json
import os
import re
import shutil
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CHEMIN_PARAMETRES = os.path.join(RACINE, 'configuration', 'cifi_parametres.json')
DOSSIER_FLUTTER = os.path.join(RACINE, 'cifi_application')
DOSSIER_HARMONY = os.path.join(RACINE, 'cifi_harmonyos')
DOSSIER_MARQUE = os.path.join(RACINE, 'marque')

modifications = []
avertissements = []


# --------------------------------------------------------------------- sortie

def titre(texte):
    print('\n' + '=' * 66)
    print('  ' + texte)
    print('=' * 66)


def succes(texte):
    print('  [OK]     ' + texte)


def info(texte):
    print('  [INFO]   ' + texte)


def alerte(texte):
    print('  [ALERTE] ' + texte)
    avertissements.append(texte)


# --------------------------------------------------------------------- outils

def lire_parametres():
    if not os.path.exists(CHEMIN_PARAMETRES):
        print('fichier de parametres introuvable : %s' % CHEMIN_PARAMETRES)
        sys.exit(1)
    with open(CHEMIN_PARAMETRES, encoding='utf-8') as fichier:
        return json.load(fichier)


def copier(source, destination):
    """Copie un fichier en creant le dossier d'accueil au besoin."""
    if not os.path.exists(source):
        alerte('source absente, copie ignoree : %s' % source)
        return False
    os.makedirs(os.path.dirname(destination), exist_ok=True)
    shutil.copy2(source, destination)
    succes('copie -> %s' % destination)
    modifications.append(destination)
    return True


def remplacer(chemin, regles, obligatoire=True):
    """
    Applique une liste de (motif, remplacement) sur un fichier texte.
    Chaque motif DOIT trouver une occurrence, sinon le script le signale :
    un patch silencieusement inapplique est le pire des cas.
    """
    if not os.path.exists(chemin):
        if obligatoire:
            alerte('fichier absent : %s' % chemin)
        return False

    with open(chemin, encoding='utf-8') as fichier:
        contenu = fichier.read()

    origine = contenu
    for motif, remplacement in regles:
        contenu, nombre = re.subn(motif, remplacement, contenu, count=1,
                                  flags=re.MULTILINE)
        if nombre == 0:
            alerte('motif non trouve dans %s : %s' %
                   (os.path.basename(chemin), motif))

    if contenu == origine:
        info('inchange : %s' % chemin)
        return False

    with open(chemin, 'w', encoding='utf-8', newline='\n') as fichier:
        fichier.write(contenu)
    succes('modifie -> %s' % chemin)
    modifications.append(chemin)
    return True


def echapper(valeur):
    """Protege une valeur inseree dans un remplacement par expression."""
    return valeur.replace('\\', '\\\\')


def domaine_principal(parametres):
    """Premier domaine autorise, utilise pour les liens profonds."""
    domaines = parametres['site_cible'].get('domaines_autorises') or []
    if domaines:
        return domaines[-1]
    url = parametres['site_cible']['url_accueil']
    sans_protocole = re.sub(r'^[a-z]+://', '', url)
    return sans_protocole.split('/')[0]


# --------------------------------------------- etape 1 : copies des ressources

def etape_copies(parametres):
    titre('ETAPE 1 / 6  -  Copie des parametres et des pages')

    copier(
        CHEMIN_PARAMETRES,
        os.path.join(DOSSIER_FLUTTER, 'assets', 'configuration',
                     'cifi_parametres.json')
    )
    copier(
        CHEMIN_PARAMETRES,
        os.path.join(DOSSIER_HARMONY, 'entry', 'src', 'main', 'resources',
                     'rawfile', 'cifi_parametres.json')
    )
    copier(
        os.path.join(DOSSIER_FLUTTER, 'assets', 'pages', 'hors_ligne.html'),
        os.path.join(DOSSIER_HARMONY, 'entry', 'src', 'main', 'resources',
                     'rawfile', 'hors_ligne.html')
    )


def etape_logos(parametres):
    titre('ETAPE 2 / 6  -  Copie des logos')

    marque = parametres.get('marque', {})
    cibles = [
        (marque.get('logo_application', 'marque/logo.png'), 'logo.png'),
        (marque.get('logo_splash', 'marque/logo_splash.png'), 'logo_splash.png'),
        (marque.get('logo_notification', 'marque/logo_notification.png'),
         'logo_notification.png'),
    ]

    for relatif, nom_cible in cibles:
        source = os.path.join(RACINE, relatif.replace('/', os.sep))
        if not os.path.exists(source):
            source = os.path.join(DOSSIER_MARQUE, nom_cible)

        copier(source, os.path.join(DOSSIER_FLUTTER, 'assets', 'marque', nom_cible))

    # HarmonyOS attend des noms precis dans son dossier media
    media_harmony = os.path.join(DOSSIER_HARMONY, 'entry', 'src', 'main',
                                 'resources', 'base', 'media')
    copier(os.path.join(DOSSIER_MARQUE, 'logo.png'),
           os.path.join(media_harmony, 'app_icon.png'))
    copier(os.path.join(DOSSIER_MARQUE, 'logo_splash.png'),
           os.path.join(media_harmony, 'splash_logo.png'))
    copier(os.path.join(DOSSIER_MARQUE, 'logo.png'),
           os.path.join(DOSSIER_HARMONY, 'AppScope', 'resources', 'base',
                        'media', 'app_icon.png'))


# ------------------------------------------------------- etape 3 : pubspec

def etape_pubspec(parametres):
    titre('ETAPE 3 / 6  -  pubspec.yaml (splash et icone)')

    identite = parametres['identite']
    apparence = parametres['apparence']

    chemin = os.path.join(DOSSIER_FLUTTER, 'pubspec.yaml')
    remplacer(chemin, [
        (r'^version: .*$',
         'version: %s+%d' % (identite['version_affichee'],
                             identite['numero_build'])),
        (r'^  adaptive_icon_background: ".*"$',
         '  adaptive_icon_background: "%s"' % apparence['couleur_fond_clair']),
        (r'^  color: ".*"$',
         '  color: "%s"' % apparence['couleur_splash']),
        (r'^  color_dark: ".*"$',
         '  color_dark: "%s"' % apparence['couleur_fond_sombre']),
        (r'^    color: ".*"$',
         '    color: "%s"' % apparence['couleur_splash']),
        (r'^    color_dark: ".*"$',
         '    color_dark: "%s"' % apparence['couleur_fond_sombre']),
    ])


# ------------------------------------------------------- etape 4 : Android

def etape_android(parametres):
    titre('ETAPE 4 / 6  -  Android')

    identite = parametres['identite']
    apparence = parametres['apparence']
    notifications = parametres['notifications']
    domaine = domaine_principal(parametres)

    # --- build.gradle.kts : dans le projet genere ET dans l'overlay
    for base in (os.path.join(DOSSIER_FLUTTER, 'android', 'app'),
                 os.path.join(RACINE, 'plateforme_android', 'app')):
        # versionCode et versionName ne sont PAS touches ici : build.gradle.kts
        # les lit dans pubspec.yaml (flutter.versionCode / flutter.versionName),
        # et pubspec.yaml est deja reecrit a l'etape 3. Une seule source.
        remplacer(os.path.join(base, 'build.gradle.kts'), [
            (r'applicationId = "[^"]*"',
             'applicationId = "%s"' % echapper(identite['nom_paquet_android'])),
        ], obligatoire=False)

    # --- AndroidManifest.xml
    for base in (os.path.join(DOSSIER_FLUTTER, 'android', 'app', 'src', 'main'),
                 os.path.join(RACINE, 'plateforme_android', 'app', 'src', 'main')):
        remplacer(os.path.join(base, 'AndroidManifest.xml'), [
            (r'android:label="[^"]*"',
             'android:label="%s"' % echapper(identite['nom_affiche'])),
            (r'(<data android:scheme="https" android:host=")[^"]*(")',
             r'\g<1>%s\g<2>' % echapper(domaine)),
            (r'(default_notification_channel_id"\s*\n\s*android:value=")[^"]*(")',
             r'\g<1>%s\g<2>' % echapper(notifications['canal_identifiant'])),
        ], obligatoire=False)

    # --- couleur du widget
    for base in (os.path.join(DOSSIER_FLUTTER, 'android', 'app', 'src', 'main',
                              'res', 'drawable'),
                 os.path.join(RACINE, 'plateforme_android', 'app', 'src', 'main',
                              'res', 'drawable')):
        remplacer(os.path.join(base, 'cifi_widget_fond.xml'), [
            (r'android:color="#[0-9A-Fa-f]{6,8}"',
             'android:color="%s"' % apparence['couleur_primaire']),
        ], obligatoire=False)


# ------------------------------------------------------- etape 5 : iOS

def etape_ios(parametres):
    titre('ETAPE 5 / 6  -  iOS')

    identite = parametres['identite']

    for base in (os.path.join(DOSSIER_FLUTTER, 'ios', 'Runner'),
                 os.path.join(RACINE, 'plateforme_ios', 'Runner')):
        remplacer(os.path.join(base, 'Info.plist'), [
            (r'(<key>CFBundleDisplayName</key>\s*\n\s*<string>)[^<]*(</string>)',
             r'\g<1>%s\g<2>' % echapper(identite['nom_affiche'])),
        ], obligatoire=False)

    pbxproj = os.path.join(DOSSIER_FLUTTER, 'ios', 'Runner.xcodeproj',
                           'project.pbxproj')
    if os.path.exists(pbxproj):
        with open(pbxproj, encoding='utf-8') as fichier:
            contenu = fichier.read()
        nouveau, nombre = re.subn(
            r'PRODUCT_BUNDLE_IDENTIFIER = [^;]+;',
            'PRODUCT_BUNDLE_IDENTIFIER = %s;' % identite['nom_paquet_ios'],
            contenu
        )
        # Les extensions (widget) gardent leur suffixe : on les restaure.
        nouveau = nouveau.replace(
            'PRODUCT_BUNDLE_IDENTIFIER = %s;\n\t\t\t\tPRODUCT_NAME = "CifiWidget"'
            % identite['nom_paquet_ios'],
            'PRODUCT_BUNDLE_IDENTIFIER = %s.CifiWidget;\n\t\t\t\tPRODUCT_NAME = "CifiWidget"'
            % identite['nom_paquet_ios']
        )
        if nombre:
            with open(pbxproj, 'w', encoding='utf-8', newline='\n') as fichier:
                fichier.write(nouveau)
            succes('modifie -> %s (%d identifiant(s))' % (pbxproj, nombre))
            modifications.append(pbxproj)
    else:
        info('projet Xcode absent : lancez initialiser_projet sur un Mac')


# ------------------------------------------------------- etape 6 : HarmonyOS

def etape_harmonyos(parametres):
    titre('ETAPE 6 / 6  -  HarmonyOS NEXT')

    identite = parametres['identite']
    apparence = parametres['apparence']
    domaine = domaine_principal(parametres)

    remplacer(os.path.join(DOSSIER_HARMONY, 'AppScope', 'app.json5'), [
        (r'"bundleName": "[^"]*"',
         '"bundleName": "%s"' % echapper(identite['nom_paquet_harmonyos'])),
        (r'"versionCode": \d+',
         '"versionCode": %d' % identite['numero_build']),
        (r'"versionName": "[^"]*"',
         '"versionName": "%s"' % echapper(identite['version_affichee'])),
        (r'"vendor": "[^"]*"', '"vendor": "CiFi"'),
    ])

    for dossier in ('AppScope/resources/base/element',
                    'entry/src/main/resources/base/element'):
        chemin = os.path.join(DOSSIER_HARMONY, dossier.replace('/', os.sep),
                              'string.json')
        remplacer(chemin, [
            (r'("name": "nom_application",\s*"value": ")[^"]*(")',
             r'\g<1>%s\g<2>' % echapper(identite['nom_affiche'])),
        ], obligatoire=False)

    correspondances_couleurs = [
        ('couleur_primaire', apparence['couleur_primaire']),
        ('couleur_secondaire', apparence['couleur_secondaire']),
        ('couleur_splash', apparence['couleur_splash']),
        ('couleur_fond', apparence['couleur_fond_clair']),
        ('couleur_texte', apparence['couleur_texte_clair']),
    ]
    regles_claires = [
        (r'("name": "%s",\s*"value": ")[^"]*(")' % nom, r'\g<1>%s\g<2>' % valeur)
        for nom, valeur in correspondances_couleurs
    ]
    remplacer(
        os.path.join(DOSSIER_HARMONY, 'entry', 'src', 'main', 'resources',
                     'base', 'element', 'color.json'),
        regles_claires
    )

    remplacer(
        os.path.join(DOSSIER_HARMONY, 'entry', 'src', 'main', 'module.json5'),
        [(r'("host": ")[^"]*(")', r'\g<1>%s\g<2>' % echapper(domaine))]
    )


# --------------------------------------------------------------------- bilan

def bilan(parametres):
    titre('BILAN')

    identite = parametres['identite']
    site = parametres['site_cible']

    print('  Nom affiche        : %s' % identite['nom_affiche'])
    print('  Site cible         : %s' % site['url_accueil'])
    print('  Paquet Android     : %s' % identite['nom_paquet_android'])
    print('  Paquet iOS         : %s' % identite['nom_paquet_ios'])
    print('  Paquet HarmonyOS   : %s' % identite['nom_paquet_harmonyos'])
    print('  Version            : %s (build %d)'
          % (identite['version_affichee'], identite['numero_build']))
    print('  Fichiers modifies  : %d' % len(set(modifications)))

    if avertissements:
        print('\n  %d avertissement(s) :' % len(avertissements))
        for message in avertissements:
            print('    - %s' % message)
        print('\n  Les avertissements "fichier absent" sont normaux tant que')
        print('  scripts/initialiser_projet n a pas ete lance.')

    print('\n  Etapes suivantes :')
    print('    1. cd cifi_application')
    print('    2. flutter pub get')
    print('    3. dart run flutter_launcher_icons')
    print('    4. dart run flutter_native_splash:create')
    print('    (les lanceurs .ps1 / .sh font ces quatre commandes pour vous)')


def main():
    parametres = lire_parametres()

    print('\n  CiFi - Application de la configuration')
    print('  Source : %s' % CHEMIN_PARAMETRES)

    etape_copies(parametres)
    etape_logos(parametres)
    etape_pubspec(parametres)
    etape_android(parametres)
    etape_ios(parametres)
    etape_harmonyos(parametres)
    bilan(parametres)

    return 0


if __name__ == '__main__':
    sys.exit(main())
