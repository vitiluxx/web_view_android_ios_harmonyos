#!/usr/bin/env python3
"""
Genere les logos PNG par defaut de la marque CiFi.

Utilise uniquement la bibliotheque standard de Python : aucune
installation requise, aucune ressource telechargee.

Lancement :
    python scripts/generer_logo_defaut.py

Sortie :
    marque/logo.png            1024x1024  icone de l'application
    marque/logo_splash.png     1024x1024  logo du splash screen
    marque/logo_notification.png 256x256  icone de notification

REMPLACEZ ces fichiers par vos propres images pour changer de marque.
Formats attendus : PNG carre, 1024x1024, fond transparent accepte.
"""

import math
import os
import struct
import sys
import zlib

LARGEUR_ICONE = 1024
LARGEUR_NOTIFICATION = 256

COULEUR_PRIMAIRE = (0x0B, 0x5F, 0xFF)
COULEUR_SECONDAIRE = (0x00, 0xB8, 0x94)
COULEUR_BLANC = (0xFF, 0xFF, 0xFF)


def ecrire_png(chemin, largeur, hauteur, pixels):
    """Ecrit un PNG RGBA 8 bits sans compression perdue."""

    lignes = bytearray()
    for y in range(hauteur):
        lignes.append(0)  # filtre "aucun"
        debut = y * largeur * 4
        lignes.extend(pixels[debut:debut + largeur * 4])

    def morceau(nom, donnees):
        bloc = nom + donnees
        return (struct.pack('>I', len(donnees)) + bloc +
                struct.pack('>I', zlib.crc32(bloc) & 0xFFFFFFFF))

    entete = struct.pack('>2I5B', largeur, hauteur, 8, 6, 0, 0, 0)

    contenu = b'\x89PNG\r\n\x1a\n'
    contenu += morceau(b'IHDR', entete)
    contenu += morceau(b'IDAT', zlib.compress(bytes(lignes), 9))
    contenu += morceau(b'IEND', b'')

    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    with open(chemin, 'wb') as fichier:
        fichier.write(contenu)
    print('ecrit : %s (%dx%d)' % (chemin, largeur, hauteur))


def melanger(fond, dessus, alpha):
    """Fusionne deux couleurs selon un facteur de 0.0 a 1.0."""
    return tuple(
        int(round(fond[canal] * (1 - alpha) + dessus[canal] * alpha))
        for canal in range(3)
    )


def couverture_cercle(distance, rayon, lissage):
    """Retourne 1 a l'interieur, 0 a l'exterieur, et un degrade au bord."""
    if lissage <= 0:
        return 1.0 if distance <= rayon else 0.0
    valeur = (rayon - distance) / lissage + 0.5
    return max(0.0, min(1.0, valeur))


def dessiner_marque(largeur, fond_transparent):
    """
    Dessine le symbole CiFi : un anneau ouvert (le C) et un point (le i).
    Le rendu est calcule pixel par pixel, avec un anti-aliasing simple.
    """
    taille = largeur
    centre = taille / 2.0
    lissage = taille / 320.0

    rayon_pastille = taille * 0.46
    rayon_exterieur = taille * 0.30
    rayon_interieur = taille * 0.195
    rayon_point = taille * 0.052
    centre_point_y = centre + taille * 0.175

    # Ouverture du C : secteur angulaire laisse vide, oriente a droite.
    demi_ouverture = math.radians(46)

    pixels = bytearray(taille * taille * 4)

    for y in range(taille):
        decalage_y = y - centre + 0.5
        for x in range(taille):
            decalage_x = x - centre + 0.5
            distance_centre = math.hypot(decalage_x, decalage_y)

            # --- fond : pastille arrondie de couleur primaire
            couverture_fond = couverture_cercle(
                distance_centre, rayon_pastille, lissage)

            if fond_transparent:
                couleur = COULEUR_PRIMAIRE
                alpha = couverture_fond
            else:
                couleur = COULEUR_PRIMAIRE
                alpha = 1.0 if couverture_fond > 0 else 0.0
                if couverture_fond <= 0:
                    couleur = COULEUR_PRIMAIRE

            # --- anneau blanc (le C)
            dans_anneau = (
                couverture_cercle(distance_centre, rayon_exterieur, lissage) *
                (1.0 - couverture_cercle(distance_centre, rayon_interieur, lissage))
            )
            if dans_anneau > 0:
                angle = math.atan2(decalage_y, decalage_x)
                if abs(angle) > demi_ouverture:
                    couleur = melanger(couleur, COULEUR_BLANC, dans_anneau)

            # --- point (le i), en couleur secondaire
            distance_point = math.hypot(decalage_x, y - centre_point_y + 0.5)
            dans_point = couverture_cercle(distance_point, rayon_point, lissage)
            if dans_point > 0:
                couleur = melanger(couleur, COULEUR_SECONDAIRE, dans_point)

            position = (y * taille + x) * 4
            pixels[position] = couleur[0]
            pixels[position + 1] = couleur[1]
            pixels[position + 2] = couleur[2]
            pixels[position + 3] = int(round(alpha * 255))

    return pixels


def main():
    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    dossier_marque = os.path.join(racine, 'marque')

    cibles = [
        ('logo.png', LARGEUR_ICONE),
        ('logo_splash.png', LARGEUR_ICONE),
        ('logo_notification.png', LARGEUR_NOTIFICATION),
    ]

    for nom, largeur in cibles:
        chemin = os.path.join(dossier_marque, nom)
        if os.path.exists(chemin) and '--forcer' not in sys.argv:
            print('conserve (deja present) : %s' % chemin)
            continue
        pixels = dessiner_marque(largeur, fond_transparent=True)
        ecrire_png(chemin, largeur, largeur, pixels)

    print('\nLogos par defaut prets dans : %s' % dossier_marque)
    print('Remplacez-les par vos images, puis relancez')
    print('    scripts/appliquer_configuration.ps1')


if __name__ == '__main__':
    main()
