<#
    CiFi Tech - Generation du projet mobile

    A lancer UNE SEULE FOIS, apres installer_environnement.ps1 et apres
    avoir ferme puis rouvert le terminal.

        powershell -ExecutionPolicy Bypass -File scripts\initialiser_projet.ps1

    Ce que fait le script :
      1. genere les dossiers natifs android/ et ios/ avec "flutter create"
      2. recouvre ces dossiers avec les fichiers de plateforme_android et
         plateforme_ios (manifeste, permissions, widget, signature)
      3. telecharge les dependances Dart
      4. applique configuration\cifi_parametres.json
      5. fabrique les icones et le splash screen

    Le script est idempotent : vous pouvez le relancer sans rien casser.
    Il ne touche jamais a cifi_application\lib ni a cifi_application\assets.
#>

[CmdletBinding()]
param(
    [switch] $SauterIcones
)

$ErrorActionPreference = "Stop"

$racine = Split-Path -Parent $PSScriptRoot
$dossierFlutter = Join-Path $racine "cifi_application"
$dossierOverlayAndroid = Join-Path $racine "plateforme_android"
$dossierOverlayIos = Join-Path $racine "plateforme_ios"

function Ecrire-Titre {
    param([string] $texte)
    Write-Host ""
    Write-Host ("=" * 66) -ForegroundColor DarkCyan
    Write-Host ("  " + $texte) -ForegroundColor Cyan
    Write-Host ("=" * 66) -ForegroundColor DarkCyan
}

function Ecrire-Succes { param([string] $t) Write-Host ("  [OK]     " + $t) -ForegroundColor Green }
function Ecrire-Info   { param([string] $t) Write-Host ("  [INFO]   " + $t) -ForegroundColor Gray }
function Ecrire-Alerte { param([string] $t) Write-Host ("  [ALERTE] " + $t) -ForegroundColor Yellow }
function Ecrire-Echec  { param([string] $t) Write-Host ("  [ECHEC]  " + $t) -ForegroundColor Red }

function Test-Commande {
    param([string] $nom)
    return ($null -ne (Get-Command $nom -ErrorAction SilentlyContinue))
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


# ---------------------------------------------------------------- 1. prerequis

Ecrire-Titre "ETAPE 1 / 5  -  Verification des outils"

if (-not (Test-Commande "flutter")) {
    Ecrire-Echec "flutter introuvable dans le PATH"
    Ecrire-Info  "Lancez d abord : powershell -File scripts\installer_environnement.ps1"
    Ecrire-Info  "PUIS fermez et rouvrez le terminal"
    exit 1
}
Ecrire-Succes ("flutter : " + ((flutter --version 2>&1 | Select-Object -First 1) -join ""))

if (-not (Test-Commande "python")) {
    Ecrire-Echec "python introuvable : il porte le moteur de configuration"
    Ecrire-Info  "Installez-le : winget install Python.Python.3.12"
    exit 1
}
Ecrire-Succes ("python : " + ((python --version 2>&1) -join ""))

# ---------------------------------------------------------------- 2. flutter create

Ecrire-Titre "ETAPE 2 / 5  -  Generation des dossiers natifs"

$sauvegarde = Join-Path $script:dossierTemporaire ("cifi_sauvegarde_" + (Get-Date -Format "yyyyMMddHHmmss"))
New-Item -ItemType Directory -Path $sauvegarde -Force | Out-Null

# On met pubspec.yaml a l'abri : "flutter create" peut le reecrire.
$pubspec = Join-Path $dossierFlutter "pubspec.yaml"
if (Test-Path $pubspec) {
    Copy-Item $pubspec (Join-Path $sauvegarde "pubspec.yaml") -Force
    Ecrire-Info "pubspec.yaml mis a l abri"
}

Push-Location $dossierFlutter
try {
    Ecrire-Info "generation des dossiers android/ et ios/"
    flutter create --org td.cifi.tech --project-name cifi_navigateur `
                   --platforms=android,ios --no-pub .
    if ($LASTEXITCODE -ne 0) {
        throw "flutter create a echoue (code $LASTEXITCODE)"
    }
} finally {
    Pop-Location
}

# On rend son pubspec au projet : celui du depot fait foi.
if (Test-Path (Join-Path $sauvegarde "pubspec.yaml")) {
    Copy-Item (Join-Path $sauvegarde "pubspec.yaml") $pubspec -Force
    Ecrire-Succes "pubspec.yaml restaure"
}

Ecrire-Succes "dossiers natifs generes"

# ---------------------------------------------------------------- 3. overlays

Ecrire-Titre "ETAPE 3 / 5  -  Application des fichiers de plateforme"

function Copier-Overlay {
    param([string] $source, [string] $destination, [string] $libelle)
    if (-not (Test-Path $source)) {
        Ecrire-Alerte ("overlay absent : " + $source)
        return
    }
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Copy-Item (Join-Path $source "*") $destination -Recurse -Force
    Ecrire-Succes ($libelle + " -> " + $destination)
}

Copier-Overlay `
    (Join-Path $dossierOverlayAndroid "app") `
    (Join-Path $dossierFlutter "android\app") `
    "fichiers Android"

Copier-Overlay `
    (Join-Path $dossierOverlayIos "Runner") `
    (Join-Path $dossierFlutter "ios\Runner") `
    "fichiers iOS"

# Le modele de signature va a cote du projet Android, jamais dans git.
$modeleSignature = Join-Path $dossierOverlayAndroid "cle.proprietes.modele"
$dossierCles = Join-Path $dossierFlutter "android\cles"
if (Test-Path $modeleSignature) {
    New-Item -ItemType Directory -Path $dossierCles -Force | Out-Null
    Copy-Item $modeleSignature (Join-Path $dossierCles "cle.proprietes.modele") -Force
    Ecrire-Info ("modele de signature depose dans " + $dossierCles)
}

# Le greffon google-services doit etre declare au niveau du projet.
$settingsGradle = Join-Path $dossierFlutter "android\settings.gradle.kts"
if (Test-Path $settingsGradle) {
    $contenu = Get-Content $settingsGradle -Raw
    if ($contenu -notmatch "com\.google\.gms\.google-services") {
        $contenu = $contenu -replace `
            '(id\("com\.android\.application"\)[^\r\n]*)', `
            ('$1' + [Environment]::NewLine + '    id("com.google.gms.google-services") version "4.4.2" apply false')
        Set-Content -Path $settingsGradle -Value $contenu -Encoding utf8
        Ecrire-Succes "greffon google-services declare dans settings.gradle.kts"
    } else {
        Ecrire-Info "greffon google-services deja declare"
    }
}

# Le MainActivity genere par flutter create reste tel quel : il suffit.
$dossierKotlin = Join-Path $dossierFlutter "android\app\src\main\kotlin\td\cifi\tech\cifi_navigateur"
if (Test-Path (Join-Path $dossierKotlin "MainActivity.kt")) {
    Ecrire-Succes "MainActivity.kt en place"
} else {
    Ecrire-Alerte ("MainActivity.kt introuvable dans " + $dossierKotlin)
}

# ---------------------------------------------------------------- 4. dependances

Ecrire-Titre "ETAPE 4 / 5  -  Dependances Dart"

Push-Location $dossierFlutter
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) {
        Ecrire-Alerte "resolution impossible avec les versions demandees"
        Ecrire-Info   "nouvelle tentative en montant les versions majeures"
        flutter pub upgrade --major-versions
        if ($LASTEXITCODE -ne 0) {
            throw "impossible de resoudre les dependances"
        }
    }
    Ecrire-Succes "dependances installees"
} finally {
    Pop-Location
}

# ---------------------------------------------------------------- 5. configuration

Ecrire-Titre "ETAPE 5 / 5  -  Configuration, icones et splash"

python (Join-Path $PSScriptRoot "appliquer_configuration.py")
if ($LASTEXITCODE -ne 0) {
    Ecrire-Alerte "le moteur de configuration a signale un probleme"
}

if ($SauterIcones) {
    Ecrire-Info "icones et splash sautes (option -SauterIcones)"
} else {
    Push-Location $dossierFlutter
    try {
        Ecrire-Info "fabrication des icones"
        dart run flutter_launcher_icons
        if ($LASTEXITCODE -ne 0) { Ecrire-Alerte "icones non generees" }

        Ecrire-Info "fabrication du splash screen"
        dart run flutter_native_splash:create
        if ($LASTEXITCODE -ne 0) { Ecrire-Alerte "splash screen non genere" }
    } finally {
        Pop-Location
    }
}

Supprimer-Silencieux $sauvegarde

# ---------------------------------------------------------------- bilan

Ecrire-Titre "PROJET PRET"

Write-Host "  Code source Flutter   : $dossierFlutter\lib"
Write-Host "  Code source HarmonyOS : $racine\cifi_harmonyos\entry\src\main\ets"
Write-Host "  Configuration unique  : $racine\configuration\cifi_parametres.json"
Write-Host ""
Write-Host "  Tester tout de suite (telephone Android branche en USB) :" -ForegroundColor Cyan
Write-Host "    cd cifi_application"
Write-Host "    flutter run"
Write-Host ""
Write-Host "  Compiler :" -ForegroundColor Cyan
Write-Host "    powershell -File scripts\compiler_android.ps1"
Write-Host "    powershell -File scripts\compiler_harmonyos.ps1"
Write-Host ""
Write-Host "  Documentation : $racine\docs\00_lire_en_premier.md" -ForegroundColor Yellow
