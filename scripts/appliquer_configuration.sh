#!/usr/bin/env bash
#
# CiFi Tech - Application de la configuration (Mac / Linux)
#
# A lancer CHAQUE FOIS que vous modifiez
#     configuration/cifi_parametres.json
# ou que vous remplacez un logo dans
#     marque/
#
#     ./scripts/appliquer_configuration.sh
#
# Options :
#     --sauter-icones    ne pas regenerer icones et splash
#

set -u

SAUTER_ICONES=0
while [ $# -gt 0 ]; do
    case "$1" in
        --sauter-icones) SAUTER_ICONES=1; shift ;;
        *) echo "option inconnue : $1"; exit 1 ;;
    esac
done

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOSSIER_FLUTTER="${RACINE}/cifi_application"

VERT="\033[0;32m"; JAUNE="\033[0;33m"; ROUGE="\033[0;31m"; CYAN="\033[0;36m"; FIN="\033[0m"
ecrire_succes() { echo -e "${VERT}  [OK]     $1${FIN}"; }
ecrire_info()   { echo "  [INFO]   $1"; }
ecrire_alerte() { echo -e "${JAUNE}  [ALERTE] $1${FIN}"; }
ecrire_echec()  { echo -e "${ROUGE}  [ECHEC]  $1${FIN}"; }

PYTHON="python3"
if ! command -v python3 >/dev/null 2>&1; then
    if command -v python >/dev/null 2>&1; then PYTHON="python"; else
        ecrire_echec "python3 introuvable : il porte le moteur de configuration"
        exit 1
    fi
fi

# --- 1. propagation vers les trois plateformes
"$PYTHON" "${RACINE}/scripts/appliquer_configuration.py" || {
    ecrire_echec "le moteur de configuration a echoue"
    exit 1
}

# --- 2. dependances et ressources graphiques
if [ ! -f "${DOSSIER_FLUTTER}/pubspec.yaml" ]; then
    ecrire_alerte "projet Flutter absent : lancez d abord ./scripts/initialiser_projet.sh"
    exit 0
fi

if ! command -v flutter >/dev/null 2>&1; then
    ecrire_alerte "flutter absent du PATH : icones et splash non regeneres"
    exit 0
fi

(
    cd "$DOSSIER_FLUTTER" || exit 1

    echo ""
    ecrire_info "mise a jour des dependances"
    if flutter pub get >/dev/null 2>&1; then
        ecrire_succes "dependances a jour"
    else
        ecrire_alerte "flutter pub get a echoue"
    fi

    if [ "$SAUTER_ICONES" -eq 1 ]; then
        ecrire_info "icones et splash sautes (option --sauter-icones)"
    else
        ecrire_info "fabrication des icones"
        if dart run flutter_launcher_icons >/dev/null 2>&1; then
            ecrire_succes "icones a jour"
        else
            ecrire_alerte "icones non generees"
        fi

        ecrire_info "fabrication du splash screen"
        if dart run flutter_native_splash:create >/dev/null 2>&1; then
            ecrire_succes "splash screen a jour"
        else
            ecrire_alerte "splash non genere"
        fi
    fi
)

echo ""
ecrire_succes "configuration appliquee aux trois plateformes"
echo -e "${CYAN}  Compilez ensuite : ./scripts/compiler_android.sh${FIN}"
