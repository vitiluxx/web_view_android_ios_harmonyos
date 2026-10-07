#!/usr/bin/env python3
"""
Verifie quels greffons Android appliquent encore le greffon Kotlin (KGP).

POURQUOI CE SCRIPT
------------------
Flutter migre vers le "Built-in Kotlin". Les greffons qui appliquent
encore le greffon Kotlin a l'ancienne (apply plugin: 'kotlin-android')
provoquent un avertissement aujourd'hui, et feront echouer la
compilation dans une version future de Flutter.

Le reglage qui maintient l'ancien comportement se trouve dans
    cifi_application/android/gradle.properties
        android.builtInKotlin=false

On ne peut le passer a true que lorsque PLUS AUCUN greffon n'applique
KGP. Ce script dit ou on en est.

LANCEMENT
---------
    python scripts/auditer_greffons_kotlin.py

A FAIRE A CHAQUE MONTEE DE VERSION des dependances. Si la liste des
greffons en retard devient vide, passez android.builtInKotlin a true
et compilez pour confirmer.
"""

import glob
import io
import json
import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERROU = os.path.join(RACINE, 'cifi_application', 'pubspec.lock')

# Marqueurs d'application du greffon Kotlin a l'ancienne.
MARQUEURS = (
    "apply plugin: 'kotlin-android'",
    'apply plugin: "kotlin-android"',
    "id 'org.jetbrains.kotlin.android'",
    'id "org.jetbrains.kotlin.android"',
    'id("org.jetbrains.kotlin.android")',
    'kotlin-android',
)


def dossier_cache():
    """Dossier du cache pub, depuis PUB_CACHE ou l'emplacement par defaut."""
    cache = os.environ.get('PUB_CACHE')
    if not cache:
        cache = os.path.join(os.path.expanduser('~'), 'AppData', 'Local',
                             'Pub', 'Cache')
    return os.path.join(cache, 'hosted', 'pub.dev')


def paquets_verrouilles():
    """Couples (nom, version) lus dans pubspec.lock."""
    if not os.path.exists(VERROU):
        print('pubspec.lock introuvable : lancez d abord flutter pub get')
        sys.exit(1)
    contenu = io.open(VERROU, encoding='utf-8').read()
    return re.findall(r'\n  ([a-z0-9_]+):\n(?:.*?\n)*?    version: "([^"]+)"',
                      contenu)


def applique_kgp(dossier_android):
    """Retourne le marqueur trouve, ou None."""
    for fichier in glob.glob(os.path.join(dossier_android, 'build.gradle*')):
        try:
            contenu = io.open(fichier, encoding='utf-8', errors='replace').read()
        except OSError:
            continue
        # On ignore les lignes mises en commentaire.
        utile = '\n'.join(ligne for ligne in contenu.split('\n')
                          if not ligne.strip().startswith('//'))
        for marqueur in MARQUEURS:
            if marqueur in utile:
                return marqueur
    return None


def main():
    cache = dossier_cache()
    if not os.path.isdir(cache):
        print('cache pub introuvable : %s' % cache)
        sys.exit(1)

    en_retard = []
    a_jour = []

    for nom, version in paquets_verrouilles():
        dossier = os.path.join(cache, '%s-%s' % (nom, version), 'android')
        if not os.path.isdir(dossier):
            continue
        marqueur = applique_kgp(dossier)
        if marqueur:
            en_retard.append((nom, version, marqueur))
        else:
            a_jour.append((nom, version))

    total = len(en_retard) + len(a_jour)

    print('')
    print('=' * 66)
    print('  Audit des greffons Android - greffon Kotlin')
    print('=' * 66)
    print('  greffons examines : %d' % total)
    print('')

    if en_retard:
        print('  EN RETARD (%d) : appliquent encore le greffon Kotlin' % len(en_retard))
        for nom, version, marqueur in sorted(en_retard):
            print('    %-38s %-12s %s' % (nom, version, marqueur))
        print('')
        print('  Consequence : android.builtInKotlin doit rester a false dans')
        print('    cifi_application/android/gradle.properties')
        print('')
        print('  Que faire :')
        print('    1. Verifiez si une version plus recente existe :')
        print('         cd cifi_application && flutter pub outdated')
        print('    2. Si le greffon est deja a sa derniere version, il n y a')
        print('       rien a faire de votre cote : attendez sa correction.')
        print('    3. Relancez cet audit apres chaque montee de version.')
    else:
        print('  AUCUN greffon en retard.')
        print('')
        print('  Vous pouvez tenter le Built-in Kotlin :')
        print('    1. Dans plateforme_android/gradle.properties, passez')
        print('         android.builtInKotlin=true')
        print('    2. powershell -File scripts/appliquer_configuration.ps1')
        print('    3. powershell -File scripts/compiler_android.ps1')
        print('    4. Si la compilation echoue, revenez a false.')

    print('')
    print('  A jour : %d greffon(s)' % len(a_jour))
    print('')

    # Code de sortie 0 dans tous les cas : c'est un rapport, pas un test
    # qui doit faire echouer une chaine d'integration continue.
    return 0


if __name__ == '__main__':
    sys.exit(main())
