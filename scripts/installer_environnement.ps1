<#
    CiFi Tech - Installation de l'environnement de compilation mobile
    Cible   : Windows 10/11 (PowerShell 5.1 ou superieur)
    Produit : Android (.apk/.aab) + HarmonyOS NEXT (.hap)
    Note    : iOS (.ipa) exige obligatoirement un Mac -> docs/02_installation_mac_linux.md

    Lancement :
        powershell -ExecutionPolicy Bypass -File scripts\installer_environnement.ps1

    Options :
        -RacineOutils "C:\outils_mobile"   dossier d'accueil des SDK
        -SauterOhos                        ne pas cloner le fork Flutter HarmonyOS
        -SauterAndroidStudio               ne pas installer Android Studio
#>

[CmdletBinding()]
param(
    [string] $RacineOutils = "C:\outils_mobile",
    [switch] $SauterOhos,
    [switch] $SauterAndroidStudio
)

$ErrorActionPreference = "Stop"

# ================================================================ journalisation

$script:cheminJournal = Join-Path (Obtenir-DossierTemporaire) "cifi_installation.log"

function Ecrire-Ligne {
    param([string] $texte, [string] $couleur = "Gray")
    Write-Host $texte -ForegroundColor $couleur
    Add-Content -Path $script:cheminJournal -Value ("[" + (Get-Date -Format "HH:mm:ss") + "] " + $texte) -Encoding utf8
}

function Ecrire-Titre {
    param([string] $texte)
    Ecrire-Ligne ""
    Ecrire-Ligne ("=" * 66) "DarkCyan"
    Ecrire-Ligne ("  " + $texte) "Cyan"
    Ecrire-Ligne ("=" * 66) "DarkCyan"
}

function Ecrire-Succes { param([string] $t) Ecrire-Ligne ("  [OK]     " + $t) "Green" }
function Ecrire-Info   { param([string] $t) Ecrire-Ligne ("  [INFO]   " + $t) "Gray" }
function Ecrire-Alerte { param([string] $t) Ecrire-Ligne ("  [ALERTE] " + $t) "Yellow" }
function Ecrire-Echec  { param([string] $t) Ecrire-Ligne ("  [ECHEC]  " + $t) "Red" }

# ================================================================ utilitaires

function Test-Administrateur {
    $identite = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identite)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Commande {
    param([string] $nom)
    return ($null -ne (Get-Command $nom -ErrorAction SilentlyContinue))
}

<#
    Execute une commande externe (git, npm, sdkmanager, winget...).

    PowerShell 5.1 transforme chaque ligne envoyee sur la sortie d'erreur
    par un programme externe en erreur PowerShell. Avec
    $ErrorActionPreference = "Stop", un simple avertissement npm
    interrompt donc tout le script. On neutralise ce comportement le
    temps de l'appel, et on juge le resultat sur le seul code de sortie.
#>
function Invoquer-Externe {
    param(
        [Parameter(Mandatory = $true)] [scriptblock] $commande,
        [string] $libelle = "commande externe",
        [switch] $Silencieux
    )
    $anciennePreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        if ($Silencieux) {
            & $commande 2>&1 | Out-Null
        } else {
            & $commande 2>&1 | ForEach-Object { Write-Host ("    " + $_) }
        }
        $code = $LASTEXITCODE
        if ($null -eq $code) { $code = 0 }
        if ($code -ne 0) {
            Ecrire-Alerte ($libelle + " : code de sortie " + $code)
        }
        return $code
    } catch {
        Ecrire-Alerte ($libelle + " : " + $_.Exception.Message)
        return 1
    } finally {
        $ErrorActionPreference = $anciennePreference
    }
}

<#
    Dossier temporaire, en chemin LONG.

    $env:TEMP peut valoir un nom court 8.3 (par exemple
    C:\Users\MKUSER~1\AppData\Local\Temp quand le profil contient une
    espace). PowerShell prend alors le ~ pour le raccourci du dossier
    personnel et echoue avec "Un objet n'existe pas a l'emplacement
    specifie". On resout donc le chemin long une seule fois.
#>
function Obtenir-DossierTemporaire {
    try {
        return (Get-Item -LiteralPath $env:TEMP -ErrorAction Stop).FullName
    } catch {
        return $env:TEMP
    }
}

$script:dossierTemporaire = Obtenir-DossierTemporaire

<#
    Supprime un fichier ou un dossier sans jamais interrompre le script.
    -LiteralPath evite toute interpretation du ~ et des jokers.
#>
function Supprimer-Silencieux {
    param([string] $chemin)
    if ([string]::IsNullOrEmpty($chemin)) {
        return
    }
    if (-not (Test-Path -LiteralPath $chemin)) {
        return
    }
    try {
        Remove-Item -LiteralPath $chemin -Recurse -Force -ErrorAction Stop
    } catch {
        Ecrire-Info ("menage impossible, sans consequence : " + $chemin)
    }
}

function Definir-VariableUtilisateur {
    param([string] $nom, [string] $valeur)
    [Environment]::SetEnvironmentVariable($nom, $valeur, "User")
    Set-Item -Path ("env:" + $nom) -Value $valeur
    Ecrire-Succes ("variable " + $nom + " = " + $valeur)
}

function Ajouter-AuPath {
    param([string] $dossier)
    if (-not (Test-Path $dossier)) {
        Ecrire-Alerte ("dossier absent, non ajoute au PATH : " + $dossier)
        return
    }
    $pathUtilisateur = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($null -eq $pathUtilisateur) { $pathUtilisateur = "" }
    $dejaPresent = $false
    foreach ($morceau in $pathUtilisateur.Split(";")) {
        if ($morceau -ne "" -and $morceau.TrimEnd("\") -ieq $dossier.TrimEnd("\")) { $dejaPresent = $true }
    }
    if ($dejaPresent) {
        Ecrire-Info ("deja dans le PATH : " + $dossier)
    } else {
        $nouveau = ($pathUtilisateur.TrimEnd(";") + ";" + $dossier).TrimStart(";")
        [Environment]::SetEnvironmentVariable("Path", $nouveau, "User")
        Ecrire-Succes ("ajoute au PATH : " + $dossier)
    }
    if (-not ($env:Path -like ("*" + $dossier + "*"))) {
        $env:Path = $env:Path.TrimEnd(";") + ";" + $dossier
    }
}

function Telecharger-Fichier {
    param([string] $url, [string] $destination)
    if (Test-Path $destination) {
        Ecrire-Info ("archive deja presente : " + $destination)
        return
    }
    Ecrire-Info ("telechargement : " + $url)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ancienneProgression = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"
    try {
        Invoke-WebRequest -Uri $url -OutFile $destination -UseBasicParsing
    } finally {
        $ProgressPreference = $ancienneProgression
    }
    Ecrire-Succes ("telecharge : " + (Split-Path $destination -Leaf))
}

function Installer-ViaWinget {
    param([string] $identifiant, [string] $libelle)
    if (-not (Test-Commande "winget")) {
        Ecrire-Echec "winget introuvable. Installez 'App Installer' depuis le Microsoft Store."
        return $false
    }
    # Meme precaution que pour les autres appels externes : winget ecrit
    # sur la sortie d'erreur quand le paquet est absent, ce qui suffirait
    # a interrompre le script.
    $anciennePreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $deja = (winget list --id $identifiant --exact 2>&1 | Out-String)
    } catch {
        $deja = ""
    } finally {
        $ErrorActionPreference = $anciennePreference
    }

    if ($deja -match [regex]::Escape($identifiant)) {
        Ecrire-Info ($libelle + " deja installe")
        return $true
    }
    Ecrire-Info ("installation de " + $libelle + " via winget")
    $code = Invoquer-Externe -libelle $libelle -commande {
        winget install --id $identifiant --exact --silent --accept-package-agreements --accept-source-agreements
    }
    if ($code -eq 0) {
        Ecrire-Succes ($libelle + " installe")
        return $true
    }
    return $false
}

# ================================================================ etape 1 : prerequis

function Etape-Prerequis {
    Ecrire-Titre "ETAPE 1 / 6  -  Verification des prerequis"

    Ecrire-Info ("version PowerShell : " + $PSVersionTable.PSVersion.ToString())

    if (Test-Administrateur) {
        Ecrire-Succes "session administrateur"
    } else {
        Ecrire-Alerte "session NON administrateur : Android Studio et DevEco devront etre installes a la main"
    }

    $lettreDisque = $RacineOutils.Substring(0, 1)
    $disque = Get-PSDrive -Name $lettreDisque -PSProvider FileSystem
    $libreGo = [math]::Round($disque.Free / 1GB, 1)
    Ecrire-Info ("espace libre sur " + $lettreDisque + ": = " + $libreGo + " Go")
    if ($libreGo -lt 30) {
        Ecrire-Alerte "moins de 30 Go libres : l'installation complete risque d'echouer"
    }

    if (-not (Test-Path $RacineOutils)) {
        New-Item -ItemType Directory -Path $RacineOutils -Force | Out-Null
    }
    Ecrire-Succes ("dossier des outils : " + $RacineOutils)

    if (Test-Commande "git") {
        Ecrire-Succes ("git present : " + ((git --version) -join ""))
    } else {
        Installer-ViaWinget "Git.Git" "Git" | Out-Null
    }
}

# ================================================================ etape 2 : JDK 17

function Etape-Jdk {
    Ecrire-Titre "ETAPE 2 / 6  -  JDK 17 (Temurin)"

    $racineJdk = "C:\Program Files\Eclipse Adoptium"
    $jdkTrouve = $null
    if (Test-Path $racineJdk) {
        $jdkTrouve = Get-ChildItem $racineJdk -Directory -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -like "jdk-17*" } |
                     Select-Object -First 1
    }

    if ($null -eq $jdkTrouve) {
        Installer-ViaWinget "EclipseAdoptium.Temurin.17.JDK" "JDK 17 Temurin" | Out-Null
        if (Test-Path $racineJdk) {
            $jdkTrouve = Get-ChildItem $racineJdk -Directory -ErrorAction SilentlyContinue |
                         Where-Object { $_.Name -like "jdk-17*" } |
                         Select-Object -First 1
        }
    }

    if ($null -eq $jdkTrouve) {
        Ecrire-Echec "JDK 17 introuvable. Installation manuelle : https://adoptium.net/temurin/releases/?version=17"
        return
    }

    Definir-VariableUtilisateur "JAVA_HOME" $jdkTrouve.FullName
    Ajouter-AuPath (Join-Path $jdkTrouve.FullName "bin")
}

# ================================================================ etape 3 : Flutter

function Etape-Flutter {
    Ecrire-Titre "ETAPE 3 / 6  -  Flutter SDK (canal stable)"

    $dossierFlutter = Join-Path $RacineOutils "flutter"
    $flutterBat = Join-Path $dossierFlutter "bin\flutter.bat"

    if (Test-Path $flutterBat) {
        Ecrire-Info "Flutter deja present, tentative de mise a jour"
        Push-Location $dossierFlutter
        try { git pull --ff-only } catch { Ecrire-Alerte "mise a jour impossible, version locale conservee" }
        Pop-Location
    } else {
        Ecrire-Info "clonage du depot Flutter (plusieurs minutes, ~3 Go)"
        $code = Invoquer-Externe -libelle "clonage de Flutter" -commande {
            git clone --depth 1 --branch stable https://github.com/flutter/flutter.git $dossierFlutter
        }
        if ($code -ne 0) {
            Ecrire-Echec "clonage de Flutter echoue"
            return
        }
    }

    Ajouter-AuPath (Join-Path $dossierFlutter "bin")
    Definir-VariableUtilisateur "FLUTTER_HOME" $dossierFlutter
    Definir-VariableUtilisateur "PUB_CACHE" (Join-Path $RacineOutils "pub_cache")

    Ecrire-Info "premiere initialisation des outils Dart (patience, environ 600 Mo)"
    Invoquer-Externe -libelle "flutter --version" -commande { & $flutterBat --version } | Out-Null
    Invoquer-Externe -libelle "flutter config" -Silencieux -commande {
        & $flutterBat config --no-analytics
    } | Out-Null
    Ecrire-Succes "Flutter operationnel"
}

# ================================================================ etape 4 : Android SDK

<#
    Accepte les licences du SDK Android, sans intervention.

    C'est l'equivalent exact des "y" que vous taperiez dans
        flutter doctor --android-licenses

    Deux passes, parce qu'aucune des deux ne suffit seule :

      1. Ecriture directe des empreintes connues dans
         <SDK>\licenses\. Methode utilisee par toutes les chaines
         d'integration continue. Rapide, mais la liste vieillit :
         Google ajoute des licences (android-googlexr-license en est
         une recente).

      2. Appel de sdkmanager --licenses en lui donnant un fichier de
         "y" par redirection cmd. Cette passe rattrape toute licence
         que la premiere ignorait. On passe par cmd car un pipe
         PowerShell n'atteint pas l'entree standard de sdkmanager
         quand le terminal n'est pas interactif.
#>
function Accepter-LicencesAndroid {
    param([string] $dossierSdk, [string] $sdkmanager)

    Ecrire-Info "acceptation des licences Android"

    # --- passe 1 : empreintes connues
    $dossierLicences = Join-Path $dossierSdk "licenses"
    New-Item -ItemType Directory -Path $dossierLicences -Force | Out-Null

    $empreintes = @{
        "android-sdk-license" = @(
            "8933bad161af4178b1185d1a37fbf41ea5269c55",
            "d56f5187479451eabf01fb78af6dfcb131a6481e",
            "24333f8a63b6825ea9c5514f83c2829b004d1fee"
        )
        "android-sdk-preview-license"   = @("84831b9409646a918e30573bab4c9c91346d8abd")
        "android-sdk-arm-dbt-license"   = @("859f317696f67ef3d7f30a50a5560e7834b43903")
        "android-googlexr-license"      = @("ceff83576aac4f7f37cb98fe189e9fb3c49d3b81")
        "android-googletv-license"      = @("601085b94cd77f0b54ff86406957099ebe79c4d6")
        "google-gdk-license"            = @("33b6a2b64607f11b759f320ef9dff4ae5c47d97a")
        "intel-android-extra-license"   = @("d975f751698a77b662f1254ddbeed3901e976f5a")
        "mips-android-sysimage-license" = @("e9acab5b5fbb560a72cfaecce8946896ff6aab9d")
    }

    foreach ($nom in $empreintes.Keys) {
        $chemin = Join-Path $dossierLicences $nom
        $contenu = "`n" + [string]::Join("`n", $empreintes[$nom]) + "`n"
        [IO.File]::WriteAllText($chemin, $contenu)
    }
    Ecrire-Succes ($empreintes.Count.ToString() + " licence(s) connue(s) ecrite(s)")

    # --- passe 2 : rattrapage des licences non repertoriees
    $fichierAccords = Join-Path $script:dossierTemporaire "cifi_accords_android.txt"
    [IO.File]::WriteAllText($fichierAccords, ("y`r`n" * 120))

    Invoquer-Externe -libelle "sdkmanager --licenses" -Silencieux -commande {
        cmd /c "`"$sdkmanager`" --sdk_root=`"$dossierSdk`" --licenses < `"$fichierAccords`""
    } | Out-Null

    Supprimer-Silencieux $fichierAccords

    # --- verification
    $restantes = ""
    $anciennePreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $restantes = (cmd /c "`"$sdkmanager`" --sdk_root=`"$dossierSdk`" --licenses < NUL" 2>&1 | Out-String)
    } catch {
        $restantes = ""
    } finally {
        $ErrorActionPreference = $anciennePreference
    }

    if ($restantes -match "All SDK package licenses accepted") {
        Ecrire-Succes "toutes les licences Android sont acceptees"
    } else {
        Ecrire-Alerte "des licences Android restent a accepter"
        Ecrire-Info   ("Lancez a la main : " + $sdkmanager + " --licenses")
    }
}

function Etape-AndroidSdk {
    Ecrire-Titre "ETAPE 4 / 6  -  Android SDK"

    $dossierSdk = Join-Path $RacineOutils "android_sdk"
    $dossierCmdline = Join-Path $dossierSdk "cmdline-tools\latest"
    $sdkmanager = Join-Path $dossierCmdline "bin\sdkmanager.bat"

    if (-not (Test-Path $sdkmanager)) {
        $urlCmdline = "https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip"
        $archive = Join-Path $script:dossierTemporaire "cifi_cmdline_tools.zip"
        try {
            Telecharger-Fichier $urlCmdline $archive
        } catch {
            Ecrire-Echec "telechargement des command-line tools echoue"
            Ecrire-Info  "URL a jour : https://developer.android.com/studio#command-line-tools-only"
            Ecrire-Info  ("Dezippez le contenu dans : " + $dossierCmdline)
            return
        }

        $temporaire = Join-Path $script:dossierTemporaire "cifi_cmdline_extrait"
        Supprimer-Silencieux $temporaire

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($archive, $temporaire)

        New-Item -ItemType Directory -Path $dossierCmdline -Force | Out-Null
        Copy-Item (Join-Path $temporaire "cmdline-tools\*") $dossierCmdline -Recurse -Force

        # Un menage impossible ne doit jamais faire echouer l'installation.
        Supprimer-Silencieux $temporaire
        Supprimer-Silencieux $archive
        Ecrire-Succes ("command-line tools installes : " + $dossierCmdline)
    } else {
        Ecrire-Info "command-line tools deja presents"
    }

    Definir-VariableUtilisateur "ANDROID_HOME" $dossierSdk
    Definir-VariableUtilisateur "ANDROID_SDK_ROOT" $dossierSdk
    Ajouter-AuPath (Join-Path $dossierCmdline "bin")
    Ajouter-AuPath (Join-Path $dossierSdk "platform-tools")

    if (-not (Test-Path $sdkmanager)) {
        Ecrire-Echec "sdkmanager introuvable, etape Android interrompue"
        return
    }

    Accepter-LicencesAndroid $dossierSdk $sdkmanager

    # Version de l'API Android visee. Flutter exige une API au moins egale
    # a celle qu'il annonce dans "flutter doctor" : si doctor reclame plus
    # haut, montez ces deux nombres, rien d'autre.
    $versionApi = 36
    $versionBuildTools = "36.0.0"

    $paquets = @(
        "platform-tools",
        ("platforms;android-" + $versionApi),
        ("build-tools;" + $versionBuildTools)
    )

    foreach ($paquet in $paquets) {
        Ecrire-Info ("installation du paquet Android : " + $paquet)
        Invoquer-Externe -libelle ("paquet " + $paquet) -Silencieux -commande {
            & $sdkmanager --sdk_root=$dossierSdk --install $paquet
        } | Out-Null
    }

    # sdkmanager sort avec le code 0 meme quand il refuse d'installer :
    # on ne lui fait pas confiance, on verifie sur le disque.
    $controles = @{
        "platform-tools" = (Join-Path $dossierSdk "platform-tools\adb.exe")
        ("platforms;android-" + $versionApi) =
            (Join-Path $dossierSdk ("platforms\android-" + $versionApi))
        ("build-tools;" + $versionBuildTools) =
            (Join-Path $dossierSdk ("build-tools\" + $versionBuildTools))
    }

    $manquants = @()
    foreach ($paquet in $controles.Keys) {
        if (Test-Path $controles[$paquet]) {
            Ecrire-Succes ("paquet verifie : " + $paquet)
        } else {
            $manquants += $paquet
        }
    }

    if ($manquants.Count -gt 0) {
        Ecrire-Echec ("paquet(s) absent(s) du disque : " + ($manquants -join ", "))
        Ecrire-Info  "Cause la plus frequente : licences non acceptees."
        Ecrire-Info  ("Acceptez-les a la main : " + $sdkmanager + " --licenses")
    }

    if ($SauterAndroidStudio) {
        Ecrire-Info "Android Studio saute (option -SauterAndroidStudio)"
    } else {
        Installer-ViaWinget "Google.AndroidStudio" "Android Studio" | Out-Null
    }

    $flutterBat = Join-Path $RacineOutils "flutter\bin\flutter.bat"
    if (Test-Path $flutterBat) {
        Invoquer-Externe -libelle "flutter config --android-sdk" -Silencieux -commande {
            & $flutterBat config --android-sdk $dossierSdk
        } | Out-Null
        Ecrire-Info "chemin du SDK Android transmis a Flutter"
    }
}

# ================================================================ etape 5 : HarmonyOS

function Etape-HarmonyOs {
    Ecrire-Titre "ETAPE 5 / 6  -  HarmonyOS NEXT (DevEco Studio + SDK)"

    $dossierOhos = Join-Path $RacineOutils "harmonyos"
    New-Item -ItemType Directory -Path $dossierOhos -Force | Out-Null

    # --- 5a. DevEco Studio : telechargement protege par compte Huawei, non automatisable
    $cheminsDeveco = @(
        "C:\Program Files\Huawei\DevEco Studio",
        (Join-Path $env:LOCALAPPDATA "Huawei\DevEco Studio")
    )
    $devecoTrouve = $null
    foreach ($chemin in $cheminsDeveco) {
        if (Test-Path $chemin) { $devecoTrouve = $chemin }
    }

    if ($null -ne $devecoTrouve) {
        Ecrire-Succes ("DevEco Studio detecte : " + $devecoTrouve)
        $sdkOhos = Join-Path $devecoTrouve "sdk"
        if (Test-Path $sdkOhos) {
            Definir-VariableUtilisateur "DEVECO_SDK_HOME" $sdkOhos
            Definir-VariableUtilisateur "HOS_SDK_HOME" $sdkOhos
        }
        $toolsDeveco = Join-Path $devecoTrouve "tools"
        Ajouter-AuPath (Join-Path $toolsDeveco "ohpm\bin")
        Ajouter-AuPath (Join-Path $toolsDeveco "hvigor\bin")
        Ajouter-AuPath (Join-Path $toolsDeveco "node")
    } else {
        Ecrire-Alerte "DevEco Studio absent : son telechargement exige un compte Huawei, impossible a automatiser"
        Ecrire-Info  "1. Compte gratuit        : https://developer.huawei.com"
        Ecrire-Info  "2. Telechargez DevEco    : https://developer.huawei.com/consumer/en/deveco-studio"
        Ecrire-Info  "3. Installez, PUIS relancez ce script : il detectera le SDK et posera les variables"
    }

    # --- 5b. fork Flutter pour OpenHarmony (optionnel)
    if ($SauterOhos) {
        Ecrire-Info "fork Flutter HarmonyOS saute (option -SauterOhos)"
        return
    }

    $dossierFork = Join-Path $dossierOhos "flutter_flutter_ohos"
    if (Test-Path (Join-Path $dossierFork "bin\flutter.bat")) {
        Ecrire-Info "fork Flutter HarmonyOS deja present"
    } else {
        Ecrire-Info "clonage du fork Flutter OpenHarmony depuis Gitee"
        $code = Invoquer-Externe -libelle "clonage du fork OHOS" -commande {
            git clone --depth 1 https://gitee.com/openharmony-sig/flutter_flutter.git $dossierFork
        }
        if ($code -ne 0) {
            Ecrire-Alerte "clonage du fork OHOS echoue (Gitee souvent lent depuis l'Afrique centrale)"
            Ecrire-Info  "Sans incidence : le .hap se compile via le module ArkTS natif cifi_harmonyos"
            return
        }
    }
    Definir-VariableUtilisateur "FLUTTER_OHOS_HOME" $dossierFork
    Ecrire-Info "ATTENTION : ne mettez JAMAIS ce fork dans le PATH en meme temps que Flutter stable"
}

# ================================================================ etape 6 : outils complementaires

function Etape-OutilsComplementaires {
    Ecrire-Titre "ETAPE 6 / 6  -  Outils complementaires"

    if (Test-Commande "node") {
        Ecrire-Succes ("node present : " + ((node -v) -join ""))
    } else {
        Installer-ViaWinget "OpenJS.NodeJS.LTS" "Node.js LTS" | Out-Null
    }

    if (Test-Commande "firebase") {
        Ecrire-Succes "firebase-tools present"
    } else {
        Ecrire-Info "installation de firebase-tools (notifications push)"
        # npm ecrit ses avertissements sur la sortie d'erreur. Sans
        # Invoquer-Externe, un simple "npm warn deprecated" arrete le script.
        $code = Invoquer-Externe -libelle "firebase-tools" -Silencieux -commande {
            npm install -g firebase-tools
        }
        if ($code -eq 0) {
            Ecrire-Succes "firebase-tools installe"
        } else {
            Ecrire-Alerte "firebase-tools : echec. Relancez plus tard : npm install -g firebase-tools"
        }
    }

    $dartBat = Join-Path $RacineOutils "flutter\bin\dart.bat"
    if (Test-Path $dartBat) {
        Ecrire-Info "installation de flutterfire_cli"
        Invoquer-Externe -libelle "flutterfire_cli" -Silencieux -commande {
            & $dartBat pub global activate flutterfire_cli
        } | Out-Null
        Ajouter-AuPath (Join-Path $RacineOutils "pub_cache\bin")
    }
}

# ================================================================ bilan

function Etape-Bilan {
    Ecrire-Titre "BILAN"

    $flutterBat = Join-Path $RacineOutils "flutter\bin\flutter.bat"
    if (Test-Path $flutterBat) {
        Ecrire-Info "execution de flutter doctor"
        Invoquer-Externe -libelle "flutter doctor" -commande { & $flutterBat doctor } | Out-Null
    }

    Ecrire-Ligne ""
    Ecrire-Ligne "VARIABLES D'ENVIRONNEMENT POSEES" "Cyan"
    $noms = @("JAVA_HOME", "FLUTTER_HOME", "PUB_CACHE", "ANDROID_HOME", "ANDROID_SDK_ROOT", "DEVECO_SDK_HOME", "FLUTTER_OHOS_HOME")
    foreach ($nom in $noms) {
        $valeur = [Environment]::GetEnvironmentVariable($nom, "User")
        if ([string]::IsNullOrEmpty($valeur)) { $valeur = "(non definie)" }
        Ecrire-Ligne ("  " + $nom.PadRight(20) + " = " + $valeur)
    }

    Ecrire-Ligne ""
    Ecrire-Ligne "SUITE DES OPERATIONS" "Cyan"
    Ecrire-Ligne "  1. FERMEZ puis ROUVREZ le terminal (les variables ne sont lues qu'au demarrage)" "Yellow"
    Ecrire-Ligne "  2. Generer le projet   : powershell -File scripts\initialiser_projet.ps1"
    Ecrire-Ligne "  3. Personnaliser       : configuration\cifi_parametres.json"
    Ecrire-Ligne "  4. Appliquer           : powershell -File scripts\appliquer_configuration.ps1"
    Ecrire-Ligne "  5. Compiler Android    : powershell -File scripts\compiler_android.ps1"
    Ecrire-Ligne "  6. Compiler HarmonyOS  : powershell -File scripts\compiler_harmonyos.ps1"
    Ecrire-Ligne ""
    Ecrire-Ligne ("  Journal : " + $script:cheminJournal) "DarkGray"
    Ecrire-Ligne "  iOS (.ipa) : un Mac est obligatoire -> docs\02_installation_mac_linux.md" "Yellow"
}

# ================================================================ deroulement

Set-Content -Path $script:cheminJournal -Value ("Installation CiFi Tech - " + (Get-Date)) -Encoding utf8

Ecrire-Ligne ""
Ecrire-Ligne "  CiFi - Centrale d'Innovation et de Formation en Informatique" "Cyan"
Ecrire-Ligne "  Environnement mobile Android / iOS / HarmonyOS NEXT" "DarkCyan"

$etapes = @(
    @{ nom = "prerequis"; action = { Etape-Prerequis } },
    @{ nom = "jdk";       action = { Etape-Jdk } },
    @{ nom = "flutter";   action = { Etape-Flutter } },
    @{ nom = "android";   action = { Etape-AndroidSdk } },
    @{ nom = "harmonyos"; action = { Etape-HarmonyOs } },
    @{ nom = "outils";    action = { Etape-OutilsComplementaires } }
)

$echecs = @()
foreach ($etape in $etapes) {
    try {
        & $etape.action
    } catch {
        Ecrire-Echec ("etape '" + $etape.nom + "' interrompue : " + $_.Exception.Message)
        $echecs += $etape.nom
    }
}

Etape-Bilan

if ($echecs.Count -gt 0) {
    Ecrire-Ligne ""
    Ecrire-Alerte ("etapes en echec : " + ($echecs -join ", "))
    Ecrire-Info   "le script est idempotent : corrigez puis relancez-le"
    exit 1
}

Ecrire-Ligne ""
Ecrire-Succes "installation terminee"
exit 0
