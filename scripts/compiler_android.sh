#!/usr/bin/env bash
#
# CiFi Tech - Compilation Android (Mac / Linux)
#
#     ./scripts/compiler_android.sh
#
# Options :
#     --type apk | aab | tout   format de sortie (defaut : apk)
#     --debogage                version de test
#     --sans-decoupage          un seul APK au lieu d un par architecture
#
# Resultat depose dans :
#     livrables/android/
#

set -u

TYPE="apk"
MODE="--release"
DECOUPAGE="--split-per-abi"

while [ $# -gt 0 ]; do
    case "$1" in
        --type)           TYPE="$2"; shift 2 ;;
        --debogage)       MODE="--debug"; shift ;;
        --sans-decoupage) DECOUPAGE=""; shift ;;
        *) echo "option inconnue : $1"; exit 1 ;;
    esac
done

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOSSIER_FLUTTER="${RACINE}/cifi_application"
DOSSIER_LIVRABLES="${RACINE}/livrables/android"

VERT="\033[0;32m"; JAUNE="\033[0;33m"; ROUGE="\033[0;31m"; CYAN="\033[0;36m"; FIN="\033[0m"
ecrire_titre()  { echo -e "\n${CYAN}==================================================================${FIN}"; echo -e "${CYAN}  $1${FIN}"; echo -e "${CYAN}==================================================================${FIN}"; }
ecrire_succes() { echo -e "${VERT}  [OK]     $1${FIN}"; }
ecrire_info()   { echo "  [INFO]   $1"; }
ecrire_alerte() { echo -e "${JAUNE}  [ALERTE] $1${FIN}"; }
ecrire_echec()  { echo -e "${ROUGE}  [ECHEC]  $1${FIN}"; }

ecrire_titre "Compilation Android"

if [ ! -d "${DOSSIER_FLUTTER}/android" ]; then
    ecrire_echec "projet Android absent"
    ecrire_info  "Lancez d abord : ./scripts/initialiser_projet.sh"
    exit 1
fi

PYTHON="python3"
if ! command -v python3 >/dev/null 2>&1; then PYTHON="python"; fi

lire_parametre() {
    "$PYTHON" -c "import json;print(json.load(open('${RACINE}/configuration/cifi_parametres.json'))['identite']['$1'])"
}

NOM_SORTIE="$(lire_parametre nom_fichier_sortie)"
VERSION="$(lire_parametre version_affichee)"

ecrire_info "application : $(lire_parametre nom_affiche)"
ecrire_info "version     : ${VERSION}"

if [ "$MODE" = "--release" ]; then
    if [ -f "${DOSSIER_FLUTTER}/android/cles/cle.proprietes" ]; then
        ecrire_succes "cle de signature trouvee : version publiable"
    else
        ecrire_alerte "AUCUNE cle de signature : l APK sera signe avec la cle de debogage"
        ecrire_alerte "Il ne sera PAS acceptable par le Play Store."
        ecrire_info   "Modele a remplir : ${DOSSIER_FLUTTER}/android/cles/cle.proprietes.modele"
    fi
fi

# ---------------------------------------------------------------- compilation

mkdir -p "$DOSSIER_LIVRABLES"

(
    cd "$DOSSIER_FLUTTER" || exit 1

    ecrire_info "nettoyage"
    flutter clean >/dev/null
    flutter pub get >/dev/null

    if [ "$TYPE" = "apk" ] || [ "$TYPE" = "tout" ]; then
        ecrire_info "compilation APK ${MODE}"
        # Le decoupage ne concerne que les APK. Le bundle AAB est decoupe
        # par le Play Store lui-meme, il ne prend jamais cette option.
        if [ -n "$DECOUPAGE" ]; then
            flutter build apk "$MODE" "$DECOUPAGE" || exit 1
        else
            flutter build apk "$MODE" || exit 1
        fi
    fi

    if [ "$TYPE" = "aab" ] || [ "$TYPE" = "tout" ]; then
        ecrire_info "compilation AAB ${MODE}"
        flutter build appbundle "$MODE" || exit 1
    fi
) || { ecrire_echec "compilation echouee"; exit 1; }

# ---------------------------------------------------------------- collecte

ecrire_titre "Livrables"

COLLECTES=0

for fichier in "${DOSSIER_FLUTTER}"/build/app/outputs/flutter-apk/*.apk; do
    [ -e "$fichier" ] || continue
    base="$(basename "$fichier" .apk)"
    # app-arm64-v8a-release.apk  ->  arm64-v8a
    # app-release.apk            ->  universel
    suffixe="${base#app-}"
    suffixe="${suffixe%-release}"
    suffixe="${suffixe%-debug}"
    suffixe="${suffixe#release}"
    suffixe="${suffixe#debug}"
    if [ -z "$suffixe" ] || [ "$suffixe" = "app" ]; then suffixe="universel"; fi
    destination="${DOSSIER_LIVRABLES}/${NOM_SORTIE}_${VERSION}_${suffixe}.apk"
    cp "$fichier" "$destination"
    taille="$(du -m "$destination" | cut -f1)"
    ecrire_succes "$(basename "$destination")  (${taille} Mo)"
    COLLECTES=$((COLLECTES + 1))
done

while IFS= read -r fichier; do
    [ -n "$fichier" ] || continue
    destination="${DOSSIER_LIVRABLES}/${NOM_SORTIE}_${VERSION}.aab"
    cp "$fichier" "$destination"
    taille="$(du -m "$destination" | cut -f1)"
    ecrire_succes "$(basename "$destination")  (${taille} Mo)"
    COLLECTES=$((COLLECTES + 1))
done < <(find "${DOSSIER_FLUTTER}/build/app/outputs/bundle" -name "*.aab" 2>/dev/null)

if [ "$COLLECTES" -eq 0 ]; then
    ecrire_echec "aucun livrable produit"
    exit 1
fi

echo ""
echo -e "${CYAN}  Dossier : ${DOSSIER_LIVRABLES}${FIN}"
echo "  Installer sur un telephone branche : adb install -r <fichier.apk>"
