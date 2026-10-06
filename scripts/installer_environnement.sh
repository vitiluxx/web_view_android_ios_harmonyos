#!/usr/bin/env bash
#
# CiFi Tech - Installation de l'environnement de compilation mobile
# Cible   : macOS (Android + iOS + HarmonyOS) / Linux (Android + HarmonyOS)
# Produit : .apk / .aab / .ipa / .hap
#
# Lancement :
#     chmod +x scripts/installer_environnement.sh
#     ./scripts/installer_environnement.sh
#
# Options :
#     --racine-outils /chemin   dossier d'accueil des SDK (defaut : $HOME/outils_mobile)
#     --sauter-ohos             ne pas cloner le fork Flutter HarmonyOS
#

set -u

RACINE_OUTILS="${HOME}/outils_mobile"
SAUTER_OHOS=0
JOURNAL="/tmp/cifi_installation.log"

while [ $# -gt 0 ]; do
    case "$1" in
        --racine-outils) RACINE_OUTILS="$2"; shift 2 ;;
        --sauter-ohos)   SAUTER_OHOS=1; shift ;;
        *) echo "option inconnue : $1"; exit 1 ;;
    esac
done

# ================================================================ journalisation

COULEUR_VERT="\033[0;32m"
COULEUR_JAUNE="\033[0;33m"
COULEUR_ROUGE="\033[0;31m"
COULEUR_CYAN="\033[0;36m"
COULEUR_FIN="\033[0m"

ecrire_ligne() { echo -e "$1"; echo "[$(date +%H:%M:%S)] $(echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g')" >> "$JOURNAL"; }
ecrire_titre() { ecrire_ligne ""; ecrire_ligne "${COULEUR_CYAN}==================================================================${COULEUR_FIN}"; ecrire_ligne "${COULEUR_CYAN}  $1${COULEUR_FIN}"; ecrire_ligne "${COULEUR_CYAN}==================================================================${COULEUR_FIN}"; }
ecrire_succes() { ecrire_ligne "${COULEUR_VERT}  [OK]     $1${COULEUR_FIN}"; }
ecrire_info()   { ecrire_ligne "  [INFO]   $1"; }
ecrire_alerte() { ecrire_ligne "${COULEUR_JAUNE}  [ALERTE] $1${COULEUR_FIN}"; }
ecrire_echec()  { ecrire_ligne "${COULEUR_ROUGE}  [ECHEC]  $1${COULEUR_FIN}"; }

# ================================================================ utilitaires

SYSTEME="$(uname -s)"
EST_MAC=0
if [ "$SYSTEME" = "Darwin" ]; then EST_MAC=1; fi

test_commande() { command -v "$1" >/dev/null 2>&1; }

fichier_profil() {
    if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "${SHELL:-/bin/bash}")" = "zsh" ]; then
        echo "${HOME}/.zshrc"
    else
        echo "${HOME}/.bashrc"
    fi
}

definir_variable() {
    local nom="$1"
    local valeur="$2"
    local profil
    profil="$(fichier_profil)"
    touch "$profil"
    # on retire l'ancienne definition pour rester idempotent
    if grep -q "^export ${nom}=" "$profil" 2>/dev/null; then
        sed -i.cifi_sauvegarde "/^export ${nom}=/d" "$profil"
        rm -f "${profil}.cifi_sauvegarde"
    fi
    echo "export ${nom}=\"${valeur}\"" >> "$profil"
    export "${nom}=${valeur}"
    ecrire_succes "variable ${nom} = ${valeur}"
}

ajouter_au_path() {
    local dossier="$1"
    local profil
    profil="$(fichier_profil)"
    if [ ! -d "$dossier" ]; then
        ecrire_alerte "dossier absent, non ajoute au PATH : ${dossier}"
        return
    fi
    touch "$profil"
    if grep -qF "PATH=\"\$PATH:${dossier}\"" "$profil" 2>/dev/null; then
        ecrire_info "deja dans le PATH : ${dossier}"
    else
        echo "export PATH=\"\$PATH:${dossier}\"" >> "$profil"
        ecrire_succes "ajoute au PATH : ${dossier}"
    fi
    export PATH="$PATH:${dossier}"
}

# ================================================================ etape 1 : prerequis

etape_prerequis() {
    ecrire_titre "ETAPE 1 / 6  -  Verification des prerequis"

    ecrire_info "systeme : ${SYSTEME} $(uname -m)"

    local libre_go
    libre_go="$(df -g "${HOME}" 2>/dev/null | awk 'NR==2 {print $4}' || df -BG "${HOME}" | awk 'NR==2 {gsub("G","",$4); print $4}')"
    ecrire_info "espace libre dans ${HOME} : ${libre_go} Go"
    if [ -n "$libre_go" ] && [ "$libre_go" -lt 30 ] 2>/dev/null; then
        ecrire_alerte "moins de 30 Go libres : l'installation complete risque d'echouer"
    fi

    mkdir -p "$RACINE_OUTILS"
    ecrire_succes "dossier des outils : ${RACINE_OUTILS}"

    if [ "$EST_MAC" -eq 1 ]; then
        if ! test_commande brew; then
            ecrire_info "installation de Homebrew"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            if [ -d /opt/homebrew/bin ]; then ajouter_au_path "/opt/homebrew/bin"; fi
        else
            ecrire_succes "homebrew present : $(brew --version | head -1)"
        fi
    fi

    if ! test_commande git; then
        if [ "$EST_MAC" -eq 1 ]; then brew install git; else sudo apt-get update && sudo apt-get install -y git; fi
    fi
    ecrire_succes "git : $(git --version)"

    if [ "$EST_MAC" -eq 0 ]; then
        ecrire_info "installation des bibliotheques Linux requises par Flutter"
        sudo apt-get install -y curl unzip xz-utils zip libglu1-mesa clang cmake ninja-build pkg-config libgtk-3-dev 2>/dev/null || \
            ecrire_alerte "paquets apt non installes (distribution non Debian ?)"
    fi
}

# ================================================================ etape 2 : JDK 17

etape_jdk() {
    ecrire_titre "ETAPE 2 / 6  -  JDK 17 (Temurin)"

    if test_commande java && java -version 2>&1 | grep -q '"17'; then
        ecrire_succes "JDK 17 deja present"
    else
        if [ "$EST_MAC" -eq 1 ]; then
            brew install --cask temurin@17 || ecrire_alerte "installation temurin@17 echouee"
        else
            sudo apt-get install -y openjdk-17-jdk || ecrire_alerte "installation openjdk-17 echouee"
        fi
    fi

    local chemin_jdk=""
    if [ "$EST_MAC" -eq 1 ]; then
        chemin_jdk="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
    else
        chemin_jdk="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")" 2>/dev/null || true)"
    fi

    if [ -n "$chemin_jdk" ] && [ -d "$chemin_jdk" ]; then
        definir_variable "JAVA_HOME" "$chemin_jdk"
        ajouter_au_path "${chemin_jdk}/bin"
    else
        ecrire_echec "JAVA_HOME introuvable. Installation manuelle : https://adoptium.net/temurin/releases/?version=17"
    fi
}

# ================================================================ etape 3 : Flutter

etape_flutter() {
    ecrire_titre "ETAPE 3 / 6  -  Flutter SDK (canal stable)"

    local dossier_flutter="${RACINE_OUTILS}/flutter"

    if [ -x "${dossier_flutter}/bin/flutter" ]; then
        ecrire_info "Flutter deja present, tentative de mise a jour"
        (cd "$dossier_flutter" && git pull --ff-only) || ecrire_alerte "mise a jour impossible, version locale conservee"
    else
        ecrire_info "clonage du depot Flutter (plusieurs minutes, ~3 Go)"
        git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$dossier_flutter" || {
            ecrire_echec "clonage de Flutter echoue"; return 1; }
    fi

    ajouter_au_path "${dossier_flutter}/bin"
    definir_variable "FLUTTER_HOME" "$dossier_flutter"
    definir_variable "PUB_CACHE" "${RACINE_OUTILS}/pub_cache"

    ecrire_info "premiere initialisation des outils Dart (patience)"
    "${dossier_flutter}/bin/flutter" --version
    "${dossier_flutter}/bin/flutter" config --no-analytics >/dev/null 2>&1 || true
    ecrire_succes "Flutter operationnel"
}

# ================================================================ etape 4 : Android SDK

# Accepte les licences du SDK Android, sans intervention.
# Equivalent des "y" de "flutter doctor --android-licenses".
#
# Deux passes : les empreintes connues d'abord (rapide, mais la liste
# vieillit quand Google ajoute une licence), puis sdkmanager --licenses
# alimente par "yes" pour rattraper ce qui manque.
accepter_licences_android() {
    local dossier_sdk="$1"
    local sdkmanager="$2"

    ecrire_info "acceptation des licences Android"

    local dossier_licences="${dossier_sdk}/licenses"
    mkdir -p "$dossier_licences"

    printf '\n%s\n%s\n%s\n' \
        "8933bad161af4178b1185d1a37fbf41ea5269c55" \
        "d56f5187479451eabf01fb78af6dfcb131a6481e" \
        "24333f8a63b6825ea9c5514f83c2829b004d1fee" \
        > "${dossier_licences}/android-sdk-license"

    printf '\n%s\n' "84831b9409646a918e30573bab4c9c91346d8abd" > "${dossier_licences}/android-sdk-preview-license"
    printf '\n%s\n' "859f317696f67ef3d7f30a50a5560e7834b43903" > "${dossier_licences}/android-sdk-arm-dbt-license"
    printf '\n%s\n' "ceff83576aac4f7f37cb98fe189e9fb3c49d3b81" > "${dossier_licences}/android-googlexr-license"
    printf '\n%s\n' "601085b94cd77f0b54ff86406957099ebe79c4d6" > "${dossier_licences}/android-googletv-license"
    printf '\n%s\n' "33b6a2b64607f11b759f320ef9dff4ae5c47d97a" > "${dossier_licences}/google-gdk-license"
    printf '\n%s\n' "d975f751698a77b662f1254ddbeed3901e976f5a" > "${dossier_licences}/intel-android-extra-license"
    printf '\n%s\n' "e9acab5b5fbb560a72cfaecce8946896ff6aab9d" > "${dossier_licences}/mips-android-sysimage-license"

    ecrire_succes "8 licence(s) connue(s) ecrite(s)"

    yes | "$sdkmanager" --sdk_root="$dossier_sdk" --licenses >/dev/null 2>&1 || true

    if "$sdkmanager" --sdk_root="$dossier_sdk" --licenses < /dev/null 2>&1 \
         | grep -q "All SDK package licenses accepted"; then
        ecrire_succes "toutes les licences Android sont acceptees"
    else
        ecrire_alerte "des licences Android restent a accepter"
        ecrire_info   "Lancez a la main : ${sdkmanager} --licenses"
    fi
}

etape_android() {
    ecrire_titre "ETAPE 4 / 6  -  Android SDK"

    local dossier_sdk="${RACINE_OUTILS}/android_sdk"
    local dossier_cmdline="${dossier_sdk}/cmdline-tools/latest"

    if [ ! -x "${dossier_cmdline}/bin/sdkmanager" ]; then
        local url_cmdline
        if [ "$EST_MAC" -eq 1 ]; then
            url_cmdline="https://dl.google.com/android/repository/commandlinetools-mac-13114758_latest.zip"
        else
            url_cmdline="https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip"
        fi

        local archive="/tmp/cifi_cmdline_tools.zip"
        ecrire_info "telechargement des command-line tools"
        curl -fL "$url_cmdline" -o "$archive" || {
            ecrire_echec "telechargement echoue"
            ecrire_info  "URL a jour : https://developer.android.com/studio#command-line-tools-only"
            ecrire_info  "Dezippez le contenu dans : ${dossier_cmdline}"
            return 1; }

        rm -rf /tmp/cifi_cmdline_extrait
        unzip -q "$archive" -d /tmp/cifi_cmdline_extrait
        mkdir -p "$dossier_cmdline"
        cp -R /tmp/cifi_cmdline_extrait/cmdline-tools/. "$dossier_cmdline/"
        rm -rf /tmp/cifi_cmdline_extrait "$archive"
        ecrire_succes "command-line tools installes : ${dossier_cmdline}"
    else
        ecrire_info "command-line tools deja presents"
    fi

    definir_variable "ANDROID_HOME" "$dossier_sdk"
    definir_variable "ANDROID_SDK_ROOT" "$dossier_sdk"
    ajouter_au_path "${dossier_cmdline}/bin"
    ajouter_au_path "${dossier_sdk}/platform-tools"

    local sdkmanager="${dossier_cmdline}/bin/sdkmanager"
    if [ ! -x "$sdkmanager" ]; then
        ecrire_echec "sdkmanager introuvable, etape Android interrompue"
        return 1
    fi

    accepter_licences_android "$dossier_sdk" "$sdkmanager"

    # Version de l'API Android visee. Flutter exige une API au moins egale
    # a celle qu'il annonce dans "flutter doctor" : si doctor reclame plus
    # haut, montez ces deux valeurs, rien d'autre.
    local version_api=36
    local version_build_tools="36.0.0"

    for paquet in "platform-tools" "platforms;android-${version_api}" \
                  "build-tools;${version_build_tools}"; do
        ecrire_info "installation du paquet Android : ${paquet}"
        "$sdkmanager" --sdk_root="$dossier_sdk" --install "$paquet" >/dev/null 2>&1 || true
    done

    # sdkmanager sort avec le code 0 meme quand il refuse d'installer :
    # on ne lui fait pas confiance, on verifie sur le disque.
    local manquants=""
    for couple in \
        "platform-tools:${dossier_sdk}/platform-tools/adb" \
        "platforms;android-${version_api}:${dossier_sdk}/platforms/android-${version_api}" \
        "build-tools;${version_build_tools}:${dossier_sdk}/build-tools/${version_build_tools}"
    do
        nom="${couple%%:*}"
        chemin="${couple#*:}"
        if [ -e "$chemin" ]; then
            ecrire_succes "paquet verifie : ${nom}"
        else
            manquants="${manquants} ${nom}"
        fi
    done

    if [ -n "$manquants" ]; then
        ecrire_echec "paquet(s) absent(s) du disque :${manquants}"
        ecrire_info  "Cause la plus frequente : licences non acceptees."
        ecrire_info  "Acceptez-les a la main : ${sdkmanager} --licenses"
    fi

    if [ -x "${RACINE_OUTILS}/flutter/bin/flutter" ]; then
        "${RACINE_OUTILS}/flutter/bin/flutter" config --android-sdk "$dossier_sdk" >/dev/null 2>&1 || true
    fi
}

# ================================================================ etape 5 : iOS (macOS uniquement)

etape_ios() {
    ecrire_titre "ETAPE 5 / 6  -  iOS (Xcode + CocoaPods)"

    if [ "$EST_MAC" -eq 0 ]; then
        ecrire_alerte "systeme non macOS : la compilation .ipa est IMPOSSIBLE ici"
        ecrire_info  "Solutions : un Mac physique, ou un service CI macOS (Codemagic, GitHub Actions macos-latest)"
        return 0
    fi

    if [ -d /Applications/Xcode.app ]; then
        ecrire_succes "Xcode detecte : /Applications/Xcode.app"
        sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer 2>/dev/null || true
        sudo xcodebuild -runFirstLaunch 2>/dev/null || true
        sudo xcodebuild -license accept 2>/dev/null || true
    else
        ecrire_alerte "Xcode absent : installation via le Mac App Store obligatoire (~12 Go)"
        ecrire_info  "https://apps.apple.com/app/xcode/id497799835"
        ecrire_info  "Puis relancez ce script"
    fi

    if test_commande pod; then
        ecrire_succes "cocoapods present : $(pod --version)"
    else
        ecrire_info "installation de CocoaPods"
        brew install cocoapods || sudo gem install cocoapods || ecrire_alerte "installation CocoaPods echouee"
    fi
}

# ================================================================ etape 6 : HarmonyOS

etape_harmonyos() {
    ecrire_titre "ETAPE 6 / 6  -  HarmonyOS NEXT (DevEco Studio + SDK)"

    local dossier_ohos="${RACINE_OUTILS}/harmonyos"
    mkdir -p "$dossier_ohos"

    local deveco_trouve=""
    for chemin in "/Applications/DevEco-Studio.app" "${HOME}/DevEco-Studio" "/opt/deveco-studio"; do
        if [ -e "$chemin" ]; then deveco_trouve="$chemin"; fi
    done

    if [ -n "$deveco_trouve" ]; then
        ecrire_succes "DevEco Studio detecte : ${deveco_trouve}"
        local sdk_ohos="${deveco_trouve}/Contents/sdk"
        if [ ! -d "$sdk_ohos" ]; then sdk_ohos="${deveco_trouve}/sdk"; fi
        if [ -d "$sdk_ohos" ]; then
            definir_variable "DEVECO_SDK_HOME" "$sdk_ohos"
            definir_variable "HOS_SDK_HOME" "$sdk_ohos"
        fi
        local tools_deveco="${deveco_trouve}/Contents/tools"
        if [ ! -d "$tools_deveco" ]; then tools_deveco="${deveco_trouve}/tools"; fi
        ajouter_au_path "${tools_deveco}/ohpm/bin"
        ajouter_au_path "${tools_deveco}/hvigor/bin"
        ajouter_au_path "${tools_deveco}/node/bin"
    else
        ecrire_alerte "DevEco Studio absent : son telechargement exige un compte Huawei, impossible a automatiser"
        ecrire_info  "1. Compte gratuit     : https://developer.huawei.com"
        ecrire_info  "2. Telechargez DevEco : https://developer.huawei.com/consumer/en/deveco-studio"
        ecrire_info  "3. Installez, PUIS relancez ce script"
    fi

    if [ "$SAUTER_OHOS" -eq 1 ]; then
        ecrire_info "fork Flutter HarmonyOS saute (option --sauter-ohos)"
        return 0
    fi

    local dossier_fork="${dossier_ohos}/flutter_flutter_ohos"
    if [ -x "${dossier_fork}/bin/flutter" ]; then
        ecrire_info "fork Flutter HarmonyOS deja present"
    else
        ecrire_info "clonage du fork Flutter OpenHarmony depuis Gitee"
        git clone --depth 1 https://gitee.com/openharmony-sig/flutter_flutter.git "$dossier_fork" || {
            ecrire_alerte "clonage du fork OHOS echoue (Gitee souvent lent depuis l'Afrique centrale)"
            ecrire_info  "Sans incidence : le .hap se compile via le module ArkTS natif cifi_harmonyos"
            return 0; }
    fi
    definir_variable "FLUTTER_OHOS_HOME" "$dossier_fork"
    ecrire_info "ATTENTION : ne mettez JAMAIS ce fork dans le PATH en meme temps que Flutter stable"
}

# ================================================================ bilan

etape_bilan() {
    ecrire_titre "BILAN"

    if [ -x "${RACINE_OUTILS}/flutter/bin/flutter" ]; then
        ecrire_info "execution de flutter doctor"
        "${RACINE_OUTILS}/flutter/bin/flutter" doctor -v || true
    fi

    ecrire_ligne ""
    ecrire_ligne "${COULEUR_CYAN}VARIABLES D'ENVIRONNEMENT POSEES${COULEUR_FIN}"
    for nom in JAVA_HOME FLUTTER_HOME PUB_CACHE ANDROID_HOME ANDROID_SDK_ROOT DEVECO_SDK_HOME FLUTTER_OHOS_HOME; do
        valeur="$(eval "echo \${${nom}:-(non definie)}")"
        ecrire_ligne "  ${nom} = ${valeur}"
    done

    ecrire_ligne ""
    ecrire_ligne "${COULEUR_CYAN}SUITE DES OPERATIONS${COULEUR_FIN}"
    ecrire_ligne "${COULEUR_JAUNE}  1. Rechargez votre shell : source $(fichier_profil)${COULEUR_FIN}"
    ecrire_ligne "  2. Generer le projet   : ./scripts/initialiser_projet.sh"
    ecrire_ligne "  3. Personnaliser       : configuration/cifi_parametres.json"
    ecrire_ligne "  4. Appliquer           : ./scripts/appliquer_configuration.sh"
    ecrire_ligne "  5. Compiler Android    : ./scripts/compiler_android.sh"
    ecrire_ligne "  6. Compiler iOS        : ./scripts/compiler_ios.sh"
    ecrire_ligne "  7. Compiler HarmonyOS  : ./scripts/compiler_harmonyos.sh"
    ecrire_ligne ""
    ecrire_ligne "  Journal : ${JOURNAL}"
}

# ================================================================ deroulement

echo "Installation CiFi Tech - $(date)" > "$JOURNAL"

ecrire_ligne ""
ecrire_ligne "${COULEUR_CYAN}  CiFi - Centrale d'Innovation et de Formation en Informatique${COULEUR_FIN}"
ecrire_ligne "${COULEUR_CYAN}  Environnement mobile Android / iOS / HarmonyOS NEXT${COULEUR_FIN}"

ECHECS=""
for etape in etape_prerequis etape_jdk etape_flutter etape_android etape_ios etape_harmonyos; do
    if ! "$etape"; then
        ecrire_echec "etape ${etape} interrompue"
        ECHECS="${ECHECS} ${etape}"
    fi
done

etape_bilan

if [ -n "$ECHECS" ]; then
    ecrire_ligne ""
    ecrire_alerte "etapes en echec :${ECHECS}"
    ecrire_info   "le script est idempotent : corrigez puis relancez-le"
    exit 1
fi

ecrire_ligne ""
ecrire_succes "installation terminee"
exit 0
