#!/usr/bin/env bash
#
# CiFi Tech - Compilation iOS (.ipa)
#
# OBLIGATOIRE : un Mac avec Xcode. Aucune autre machine ne peut produire
# un .ipa, c'est une restriction d'Apple, pas du projet.
#
#     ./scripts/compiler_ios.sh
#
# Options :
#     --sans-signature   construit sans signer (test sur simulateur)
#     --debogage         version de test
#
# Resultat depose dans :
#     livrables/ios/
#

set -u

SANS_SIGNATURE=0
MODE="--release"

while [ $# -gt 0 ]; do
    case "$1" in
        --sans-signature) SANS_SIGNATURE=1; shift ;;
        --debogage)       MODE="--debug"; shift ;;
        *) echo "option inconnue : $1"; exit 1 ;;
    esac
done

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOSSIER_FLUTTER="${RACINE}/cifi_application"
DOSSIER_LIVRABLES="${RACINE}/livrables/ios"

VERT="\033[0;32m"; JAUNE="\033[0;33m"; ROUGE="\033[0;31m"; CYAN="\033[0;36m"; FIN="\033[0m"
ecrire_titre()  { echo -e "\n${CYAN}==================================================================${FIN}"; echo -e "${CYAN}  $1${FIN}"; echo -e "${CYAN}==================================================================${FIN}"; }
ecrire_succes() { echo -e "${VERT}  [OK]     $1${FIN}"; }
ecrire_info()   { echo "  [INFO]   $1"; }
ecrire_alerte() { echo -e "${JAUNE}  [ALERTE] $1${FIN}"; }
ecrire_echec()  { echo -e "${ROUGE}  [ECHEC]  $1${FIN}"; }

ecrire_titre "Compilation iOS"

# ---------------------------------------------------------------- controles

if [ "$(uname -s)" != "Darwin" ]; then
    ecrire_echec "systeme non macOS : la compilation .ipa est impossible ici"
    echo ""
    ecrire_info "Trois solutions :"
    ecrire_info "  1. un Mac physique ou loue (MacStadium, MacInCloud)"
    ecrire_info "  2. GitHub Actions avec un executeur macos-latest"
    ecrire_info "  3. Codemagic, qui compile Flutter pour iOS sans Mac local"
    exit 1
fi

if [ ! -d /Applications/Xcode.app ]; then
    ecrire_echec "Xcode absent"
    ecrire_info  "Installez-le depuis le Mac App Store, puis relancez"
    exit 1
fi

if [ ! -d "${DOSSIER_FLUTTER}/ios" ]; then
    ecrire_echec "projet iOS absent"
    ecrire_info  "Lancez d abord : ./scripts/initialiser_projet.sh"
    exit 1
fi

PYTHON="python3"
NOM_SORTIE="$("$PYTHON" -c "import json;print(json.load(open('${RACINE}/configuration/cifi_parametres.json'))['identite']['nom_fichier_sortie'])")"
VERSION="$("$PYTHON" -c "import json;print(json.load(open('${RACINE}/configuration/cifi_parametres.json'))['identite']['version_affichee'])")"
NOM_AFFICHE="$("$PYTHON" -c "import json;print(json.load(open('${RACINE}/configuration/cifi_parametres.json'))['identite']['nom_affiche'])")"

ecrire_info "application : ${NOM_AFFICHE}"
ecrire_info "version     : ${VERSION}"

# ---------------------------------------------------------------- compilation

mkdir -p "$DOSSIER_LIVRABLES"

(
    cd "$DOSSIER_FLUTTER" || exit 1

    ecrire_info "nettoyage"
    flutter clean >/dev/null
    flutter pub get >/dev/null

    ecrire_info "mise a jour des pods"
    (cd ios && pod install --repo-update) || ecrire_alerte "pod install imparfait"

    if [ "$SANS_SIGNATURE" -eq 1 ]; then
        ecrire_info "compilation sans signature (test uniquement)"
        flutter build ios "$MODE" --no-codesign || exit 1
        ecrire_alerte "sortie non signee : utilisable en simulateur, pas sur un iPhone"
    else
        ecrire_info "compilation et archivage .ipa"
        flutter build ipa "$MODE" \
            --export-options-plist=ios/ExportOptions.plist 2>/dev/null \
            || flutter build ipa "$MODE" || exit 1
    fi
) || { ecrire_echec "compilation echouee"; exit 1; }

# ---------------------------------------------------------------- collecte

ecrire_titre "Livrables"

COLLECTES=0
SOURCE_IPA="${DOSSIER_FLUTTER}/build/ios/ipa"

if [ -d "$SOURCE_IPA" ]; then
    for fichier in "${SOURCE_IPA}"/*.ipa; do
        [ -e "$fichier" ] || continue
        destination="${DOSSIER_LIVRABLES}/${NOM_SORTIE}_${VERSION}.ipa"
        cp "$fichier" "$destination"
        taille="$(du -m "$destination" | cut -f1)"
        ecrire_succes "$(basename "$destination")  (${taille} Mo)"
        COLLECTES=$((COLLECTES + 1))
    done
fi

if [ "$COLLECTES" -eq 0 ]; then
    ecrire_alerte "aucun .ipa produit"
    ecrire_info   "Si la signature manque : ouvrez ios/Runner.xcworkspace dans Xcode,"
    ecrire_info   "onglet Signing & Capabilities, choisissez votre equipe Apple,"
    ecrire_info   "puis relancez ce script."
    exit 1
fi

echo ""
echo -e "${CYAN}  Dossier : ${DOSSIER_LIVRABLES}${FIN}"
echo "  Envoyer sur TestFlight : xcrun altool --upload-app -f <fichier.ipa>"
