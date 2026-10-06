// Tests unitaires de la logique metier.
//
// On teste ici ce qui n'a besoin ni d'appareil, ni de reseau, ni de
// greffon : le calcul de distance, la lecture des couleurs et le
// filtrage des domaines. Ces trois fonctions decident du comportement
// des notifications par zone, du theme et de la navigation.
//
// Lancement :
//     flutter test

import 'package:cifi_navigateur/configuration/palette_couleurs.dart';
import 'package:cifi_navigateur/configuration/parametres_application.dart';
import 'package:cifi_navigateur/services/service_geolocalisation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('distanceEnMetres', () {
    test('renvoie zero entre un point et lui-meme', () {
      expect(distanceEnMetres(12.1348, 15.0557, 12.1348, 15.0557), 0);
    });

    test('mesure correctement un deplacement court', () {
      // Un centieme de degre de latitude vaut environ 1111 metres.
      final double distance =
          distanceEnMetres(12.1348, 15.0557, 12.1448, 15.0557);
      expect(distance, closeTo(1111, 5));
    });

    test('reste symetrique', () {
      final double aller = distanceEnMetres(12.1348, 15.0557, 9.3077, 13.3917);
      final double retour = distanceEnMetres(9.3077, 13.3917, 12.1348, 15.0557);
      expect(aller, closeTo(retour, 0.001));
    });

    test('mesure la distance N Djamena - Moundou', () {
      // Environ 370 km a vol d'oiseau.
      final double distance =
          distanceEnMetres(12.1348, 15.0557, 8.5667, 16.0833);
      expect(distance / 1000, closeTo(410, 30));
    });
  });

  group('couleurDepuisHexadecimal', () {
    test('lit une couleur a six chiffres', () {
      expect(couleurDepuisHexadecimal('#0B5FFF'), const Color(0xFF0B5FFF));
    });

    test('lit une couleur a huit chiffres', () {
      expect(couleurDepuisHexadecimal('#800B5FFF'), const Color(0x800B5FFF));
    });

    test('accepte l absence de diese et les espaces', () {
      expect(couleurDepuisHexadecimal('  0b5fff '), const Color(0xFF0B5FFF));
    });

    test('retombe sur la valeur de repli si la chaine est invalide', () {
      expect(
        couleurDepuisHexadecimal('pas une couleur', repli: Colors.red),
        Colors.red,
      );
    });
  });

  group('SiteCible.estInterne', () {
    final SiteCible site = SiteCible.depuisCarte(<String, dynamic>{
      'url_accueil': 'https://www.cifi.td',
      'domaines_autorises': <String>['cifi.td', 'www.cifi.td'],
    });

    test('accepte le domaine declare', () {
      expect(site.estInterne(Uri.parse('https://cifi.td/accueil')), isTrue);
    });

    test('accepte un sous-domaine', () {
      expect(site.estInterne(Uri.parse('https://boutique.cifi.td')), isTrue);
    });

    test('refuse un domaine etranger', () {
      expect(site.estInterne(Uri.parse('https://example.com')), isFalse);
    });

    test('refuse un domaine qui imite le notre', () {
      // Protection contre une adresse du type "pirate-cifi.td".
      expect(site.estInterne(Uri.parse('https://pirate-cifi.td')), isFalse);
    });

    test('accepte une adresse sans hote, comme une page locale', () {
      expect(site.estInterne(Uri.parse('/contact')), isTrue);
    });
  });
}
