#!/usr/bin/env bash
#
# CiFi Tech - Compilation HarmonyOS NEXT (.hap) - Mac / Linux
#
#     ./scripts/compiler_harmonyos.sh
#
# Options :
#     --mode debug | release   (defaut : debug)
#
# Prerequis : DevEco Studio installe. Son telechargement exige un compte
# Huawei : https://developer.huawei.com/consumer/en/deveco-studio
#
# Resultat depose dans :
#     livrables/harmonyos/
#

set -u

MODE="debug"
while [ $# -gt 0 ]; do
    case "$1" in
        --mode) MODE="$2"; shift 2 ;;
        *) echo "option inconnue : $1"; exit 1 ;;
    esac
done

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOSSIER_HARMONY="${RACINE}/cifi_harmonyos"
DOSSIER_LIVRABLES="${RACINE}/livrables/harmonyos"

VERT="\033[0;32m"; JAUNE="\033[0;33m"; ROUGE="\033[0;31m"; CYAN="\033[0;36m"; FIN="\033[0m"
ecrire_titre()  { echo -e "\n${CYAN}==================================================================${FIN}"; echo -e "${CYAN}  $1${FIN}"; echo -e "${CYAN}==================================================================${FIN}"; }
ecrire_succes() { echo -e "${VERT}  [OK]     $1${FIN}"; }
ecrire_info()   { echo "  [INFO]   $1"; }
ecrire_alerte() { echo -e "${JAUNE}  [ALERTE] $1${FIN}"; }
ecrire_echec()  { echo -e "${ROUGE}  [ECHEC]  $1${FIN}"; }

ecrire_titre "Compilation HarmonyOS NEXT"

# ---------------------------------------------------------------- outils

trouver_hvigor() {
    if command -v hvigorw >/dev/null 2>&1; then
        command -v hvigorw
        return
    fi
    for chemin in \
        "/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw" \
        "${HOME}/DevEco-Studio/tools/hvigor/bin/hvigorw" \
        "/opt/deveco-studio/tools/hvigor/bin/hvigorw"
    do
        if [ -x "$chemin" ]; then echo "$chemin"; return; fi
    done
}

HVIGOR="$(trouver_hvigor)"
if [ -z "${HVIGOR:-}" ]; then
    ecrire_echec "hvigorw introuvable : DevEco Studio n est pas installe"
    ecrire_info  "1. Compte gratuit : https://developer.huawei.com"
    ecrire_info  "2. DevEco Studio  : https://developer.huawei.com/consumer/en/deveco-studio"
    ecrire_info  "3. Relancez       : ./scripts/installer_environnement.sh"
    echo ""
    ecrire_info  "Solution de repli, sans ligne de commande :"
    ecrire_info  "  ouvrez ${DOSSIER_HARMONY} dans DevEco Studio,"
    ecrire_info  "  puis menu Build > Build Hap(s)/APP(s) > Build Hap(s)"
    exit 1
fi
ecrire_succes "hvigor : ${HVIGOR}"

if [ -z "${DEVECO_SDK_HOME:-}" ]; then
    ecrire_alerte "DEVECO_SDK_HOME non definie : la compilation peut echouer"
    ecrire_info   "Relancez ./scripts/installer_environnement.sh pour la poser"
fi

# ---------------------------------------------------------------- controles

PYTHON="python3"
if ! command -v python3 >/dev/null 2>&1; then PYTHON="python"; fi

lire_parametre() {
    "$PYTHON" -c "import json;print(json.load(open('${RACINE}/configuration/cifi_parametres.json'))['identite']['$1'])"
}

NOM_SORTIE="$(lire_parametre nom_fichier_sortie)"
VERSION="$(lire_parametre version_affichee)"

ecrire_info "application : $(lire_parametre nom_affiche)"
ecrire_info "bundle      : $(lire_parametre nom_paquet_harmonyos)"
ecrire_info "version     : ${VERSION}"

if [ ! -f "${DOSSIER_HARMONY}/entry/src/main/resources/rawfile/cifi_parametres.json" ]; then
    ecrire_alerte "parametres non propages : lancement de appliquer_configuration"
    "$PYTHON" "${RACINE}/scripts/appliquer_configuration.py" >/dev/null
fi

if [ "$MODE" = "release" ]; then
    if grep -q '"signingConfigs": *\[ *\]' "${DOSSIER_HARMONY}/build-profile.json5"; then
        ecrire_alerte "aucun profil de signature : le .hap release ne sera pas publiable"
        ecrire_info   "Creez-le dans DevEco : File > Project Structure > Signing Configs"
    fi
fi

# ---------------------------------------------------------------- compilation

(
    cd "$DOSSIER_HARMONY" || exit 1

    if command -v ohpm >/dev/null 2>&1; then
        ecrire_info "installation des dependances ohpm"
        ohpm install --all >/dev/null 2>&1 || ecrire_alerte "ohpm install imparfait"
    else
        ecrire_alerte "ohpm absent du PATH : etape sautee"
    fi

    ecrire_info "compilation du .hap en mode ${MODE}"
    "$HVIGOR" --mode module -p product=default -p buildMode="$MODE" assembleHap || exit 1
) || { ecrire_echec "hvigor a echoue"; exit 1; }

# ---------------------------------------------------------------- collecte

ecrire_titre "Livrables"

mkdir -p "$DOSSIER_LIVRABLES"
COLLECTES=0

while IFS= read -r fichier; do
    [ -n "$fichier" ] || continue
    destination="${DOSSIER_LIVRABLES}/${NOM_SORTIE}_${VERSION}_${MODE}.hap"
    cp "$fichier" "$destination"
    taille="$(du -m "$destination" | cut -f1)"
    ecrire_succes "$(basename "$destination")  (${taille} Mo)"
    COLLECTES=$((COLLECTES + 1))
done < <(find "${DOSSIER_HARMONY}" -name "*.hap" -path "*outputs*" 2>/dev/null)

if [ "$COLLECTES" -eq 0 ]; then
    ecrire_echec "aucun .hap produit"
    ecrire_info  "Ouvrez le projet dans DevEco Studio pour lire le detail de l erreur"
    exit 1
fi

echo ""
echo -e "${CYAN}  Dossier : ${DOSSIER_LIVRABLES}${FIN}"
echo "  Installer sur un appareil branche : hdc install <fichier.hap>"
