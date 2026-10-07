#!/usr/bin/env bash
#
# CiFi Tech - Generation du projet mobile (Mac / Linux)
#
# A lancer UNE SEULE FOIS, apres installer_environnement.sh et apres avoir
# recharge le shell.
#
#     chmod +x scripts/initialiser_projet.sh
#     ./scripts/initialiser_projet.sh
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
OVERLAY_ANDROID="${RACINE}/plateforme_android"
OVERLAY_IOS="${RACINE}/plateforme_ios"

VERT="\033[0;32m"; JAUNE="\033[0;33m"; ROUGE="\033[0;31m"; CYAN="\033[0;36m"; FIN="\033[0m"

ecrire_titre()  { echo -e "\n${CYAN}==================================================================${FIN}"; echo -e "${CYAN}  $1${FIN}"; echo -e "${CYAN}==================================================================${FIN}"; }
ecrire_succes() { echo -e "${VERT}  [OK]     $1${FIN}"; }
ecrire_info()   { echo "  [INFO]   $1"; }
ecrire_alerte() { echo -e "${JAUNE}  [ALERTE] $1${FIN}"; }
ecrire_echec()  { echo -e "${ROUGE}  [ECHEC]  $1${FIN}"; }

test_commande() { command -v "$1" >/dev/null 2>&1; }

PYTHON="python3"
if ! test_commande python3; then
    if test_commande python; then PYTHON="python"; fi
fi

# ---------------------------------------------------------------- 1. prerequis

ecrire_titre "ETAPE 1 / 5  -  Verification des outils"

if ! test_commande flutter; then
    ecrire_echec "flutter introuvable dans le PATH"
    ecrire_info  "Lancez d abord : ./scripts/installer_environnement.sh"
    ecrire_info  "PUIS rechargez le shell : source ~/.zshrc (ou ~/.bashrc)"
    exit 1
fi
ecrire_succes "flutter : $(flutter --version | head -1)"

if ! test_commande "$PYTHON"; then
    ecrire_echec "python3 introuvable : il porte le moteur de configuration"
    exit 1
fi
ecrire_succes "python : $($PYTHON --version 2>&1)"

PLATEFORMES="android"
if [ "$(uname -s)" = "Darwin" ]; then
    PLATEFORMES="android,ios"
    ecrire_info "macOS detecte : les dossiers ios/ seront generes"
else
    ecrire_alerte "systeme non macOS : seul android/ sera genere"
fi

# ---------------------------------------------------------------- 2. flutter create

ecrire_titre "ETAPE 2 / 5  -  Generation des dossiers natifs"

SAUVEGARDE="$(mktemp -d)"
if [ -f "${DOSSIER_FLUTTER}/pubspec.yaml" ]; then
    cp "${DOSSIER_FLUTTER}/pubspec.yaml" "${SAUVEGARDE}/pubspec.yaml"
    ecrire_info "pubspec.yaml mis a l abri"
fi

(
    cd "$DOSSIER_FLUTTER" || exit 1
    ecrire_info "generation des dossiers natifs"
    flutter create --org td.cifi.tech --project-name cifi_navigateur \
                   --platforms="$PLATEFORMES" --no-pub .
) || { ecrire_echec "flutter create a echoue"; exit 1; }

if [ -f "${SAUVEGARDE}/pubspec.yaml" ]; then
    cp "${SAUVEGARDE}/pubspec.yaml" "${DOSSIER_FLUTTER}/pubspec.yaml"
    ecrire_succes "pubspec.yaml restaure"
fi
ecrire_succes "dossiers natifs generes"

# ---------------------------------------------------------------- 3. overlays

ecrire_titre "ETAPE 3 / 5  -  Application des fichiers de plateforme"

copier_overlay() {
    local source="$1"
    local destination="$2"
    local libelle="$3"
    if [ ! -d "$source" ]; then
        ecrire_alerte "overlay absent : ${source}"
        return
    fi
    mkdir -p "$destination"
    cp -R "${source}/." "${destination}/"
    ecrire_succes "${libelle} -> ${destination}"
}

copier_overlay "${OVERLAY_ANDROID}/app" "${DOSSIER_FLUTTER}/android/app" "fichiers Android"

if [ "$(uname -s)" = "Darwin" ]; then
    copier_overlay "${OVERLAY_IOS}/Runner" "${DOSSIER_FLUTTER}/ios/Runner" "fichiers iOS"
    mkdir -p "${DOSSIER_FLUTTER}/ios/CifiWidget"
    cp -R "${OVERLAY_IOS}/CifiWidget/." "${DOSSIER_FLUTTER}/ios/CifiWidget/" 2>/dev/null || true
    ecrire_info "modele de widget iOS depose dans ios/CifiWidget (a ajouter dans Xcode)"
fi

# gradle.properties vit a la racine du dossier android, pas dans app :
# il est donc recopie a part. Il porte notre reglage memoire.
if [ -f "${OVERLAY_ANDROID}/gradle.properties" ]; then
    cp "${OVERLAY_ANDROID}/gradle.properties" "${DOSSIER_FLUTTER}/android/gradle.properties"
    ecrire_succes "gradle.properties -> reglage memoire applique"
fi

mkdir -p "${DOSSIER_FLUTTER}/android/cles"
if [ -f "${OVERLAY_ANDROID}/cle.proprietes.modele" ]; then
    cp "${OVERLAY_ANDROID}/cle.proprietes.modele" "${DOSSIER_FLUTTER}/android/cles/"
    ecrire_info "modele de signature depose dans android/cles"
fi

SETTINGS_GRADLE="${DOSSIER_FLUTTER}/android/settings.gradle.kts"
if [ -f "$SETTINGS_GRADLE" ] && ! grep -q "com.google.gms.google-services" "$SETTINGS_GRADLE"; then
    "$PYTHON" - "$SETTINGS_GRADLE" <<'FIN_PYTHON'
import io, re, sys
chemin = sys.argv[1]
texte = io.open(chemin, encoding='utf-8').read()
ligne = '    id("com.google.gms.google-services") version "4.4.2" apply false'
texte, nombre = re.subn(r'(id\("com\.android\.application"\)[^\n]*)',
                        r'\g<1>\n' + ligne, texte, count=1)
if nombre:
    io.open(chemin, 'w', encoding='utf-8', newline='\n').write(texte)
    print('greffon google-services declare')
FIN_PYTHON
    ecrire_succes "settings.gradle.kts mis a jour"
fi

# ---------------------------------------------------------------- 4. dependances

ecrire_titre "ETAPE 4 / 5  -  Dependances Dart"

(
    cd "$DOSSIER_FLUTTER" || exit 1
    if ! flutter pub get; then
        ecrire_alerte "resolution impossible avec les versions demandees"
        ecrire_info   "nouvelle tentative en montant les versions majeures"
        flutter pub upgrade --major-versions || exit 1
    fi
) || { ecrire_echec "impossible de resoudre les dependances"; exit 1; }
ecrire_succes "dependances installees"

if [ "$(uname -s)" = "Darwin" ] && test_commande pod; then
    ecrire_info "installation des pods iOS"
    (cd "${DOSSIER_FLUTTER}/ios" && pod install --repo-update) || \
        ecrire_alerte "pod install a echoue : relancez-le a la main"
fi

# ---------------------------------------------------------------- 5. configuration

ecrire_titre "ETAPE 5 / 5  -  Configuration, icones et splash"

"$PYTHON" "${RACINE}/scripts/appliquer_configuration.py" || \
    ecrire_alerte "le moteur de configuration a signale un probleme"

if [ "$SAUTER_ICONES" -eq 1 ]; then
    ecrire_info "icones et splash sautes (option --sauter-icones)"
else
    (
        cd "$DOSSIER_FLUTTER" || exit 1
        ecrire_info "fabrication des icones"
        dart run flutter_launcher_icons || ecrire_alerte "icones non generees"
        ecrire_info "fabrication du splash screen"
        dart run flutter_native_splash:create || ecrire_alerte "splash non genere"
    )
fi

rm -rf "$SAUVEGARDE"

# ---------------------------------------------------------------- bilan

ecrire_titre "PROJET PRET"

echo "  Code source Flutter   : ${DOSSIER_FLUTTER}/lib"
echo "  Code source HarmonyOS : ${RACINE}/cifi_harmonyos/entry/src/main/ets"
echo "  Configuration unique  : ${RACINE}/configuration/cifi_parametres.json"
echo ""
echo -e "${CYAN}  Tester tout de suite :${FIN}"
echo "    cd cifi_application && flutter run"
echo ""
echo -e "${CYAN}  Compiler :${FIN}"
echo "    ./scripts/compiler_android.sh"
echo "    ./scripts/compiler_ios.sh"
echo "    ./scripts/compiler_harmonyos.sh"
echo ""
echo -e "${JAUNE}  Documentation : ${RACINE}/docs/00_lire_en_premier.md${FIN}"
