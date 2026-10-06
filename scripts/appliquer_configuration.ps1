<#
    CiFi Tech - Application de la configuration

    A lancer CHAQUE FOIS que vous modifiez
        configuration\cifi_parametres.json
    ou que vous remplacez un logo dans
        marque\

        powershell -ExecutionPolicy Bypass -File scripts\appliquer_configuration.ps1

    Options :
        -SauterIcones    ne pas regenerer icones et splash (plus rapide)
#>

[CmdletBinding()]
param(
    [switch] $SauterIcones
)

$ErrorActionPreference = "Stop"

$racine = Split-Path -Parent $PSScriptRoot
$dossierFlutter = Join-Path $racine "cifi_application"

function Ecrire-Info   { param([string] $t) Write-Host ("  [INFO]   " + $t) -ForegroundColor Gray }
function Ecrire-Succes { param([string] $t) Write-Host ("  [OK]     " + $t) -ForegroundColor Green }
function Ecrire-Alerte { param([string] $t) Write-Host ("  [ALERTE] " + $t) -ForegroundColor Yellow }
function Ecrire-Echec  { param([string] $t) Write-Host ("  [ECHEC]  " + $t) -ForegroundColor Red }

if ($null -eq (Get-Command "python" -ErrorAction SilentlyContinue)) {
    Ecrire-Echec "python introuvable : il porte le moteur de configuration"
    Ecrire-Info  "Installez-le : winget install Python.Python.3.12"
    exit 1
}

# --- 1. propagation vers les trois plateformes
python (Join-Path $PSScriptRoot "appliquer_configuration.py")
$codeMoteur = $LASTEXITCODE
if ($codeMoteur -ne 0) {
    Ecrire-Echec "le moteur de configuration a echoue (code $codeMoteur)"
    exit $codeMoteur
}

# --- 2. dependances et ressources graphiques
if (-not (Test-Path (Join-Path $dossierFlutter "pubspec.yaml"))) {
    Ecrire-Alerte "projet Flutter absent : lancez d abord scripts\initialiser_projet.ps1"
    exit 0
}

if ($null -eq (Get-Command "flutter" -ErrorAction SilentlyContinue)) {
    Ecrire-Alerte "flutter absent du PATH : icones et splash non regeneres"
    exit 0
}

Push-Location $dossierFlutter
try {
    Write-Host ""
    Ecrire-Info "mise a jour des dependances"
    flutter pub get | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Ecrire-Alerte "flutter pub get a echoue"
    } else {
        Ecrire-Succes "dependances a jour"
    }

    if ($SauterIcones) {
        Ecrire-Info "icones et splash sautes (option -SauterIcones)"
    } else {
        Ecrire-Info "fabrication des icones"
        dart run flutter_launcher_icons | Out-Null
        if ($LASTEXITCODE -eq 0) { Ecrire-Succes "icones a jour" } else { Ecrire-Alerte "icones non generees" }

        Ecrire-Info "fabrication du splash screen"
        dart run flutter_native_splash:create | Out-Null
        if ($LASTEXITCODE -eq 0) { Ecrire-Succes "splash screen a jour" } else { Ecrire-Alerte "splash non genere" }
    }
} finally {
    Pop-Location
}

Write-Host ""
Ecrire-Succes "configuration appliquee aux trois plateformes"
Write-Host "  Compilez ensuite : powershell -File scripts\compiler_android.ps1" -ForegroundColor Cyan
