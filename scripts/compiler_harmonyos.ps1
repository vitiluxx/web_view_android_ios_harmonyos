<#
    CiFi Tech - Compilation HarmonyOS NEXT (.hap)

        powershell -ExecutionPolicy Bypass -File scripts\compiler_harmonyos.ps1

    Options :
        -Mode debug      .hap de test (defaut)
        -Mode release    .hap de publication, exige un profil de signature

    Prerequis :
        DevEco Studio installe. Son telechargement exige un compte Huawei :
        https://developer.huawei.com/consumer/en/deveco-studio
        Relancez ensuite scripts\installer_environnement.ps1 : il posera
        DEVECO_SDK_HOME et ajoutera hvigor au PATH.

    Resultat depose dans :
        livrables\harmonyos\
#>

[CmdletBinding()]
param(
    [ValidateSet("debug", "release")]
    [string] $Mode = "debug"
)

$ErrorActionPreference = "Stop"

$racine = Split-Path -Parent $PSScriptRoot
$dossierHarmony = Join-Path $racine "cifi_harmonyos"
$dossierLivrables = Join-Path $racine "livrables\harmonyos"

function Ecrire-Titre {
    param([string] $texte)
    Write-Host ""
    Write-Host ("=" * 66) -ForegroundColor DarkCyan
    Write-Host ("  " + $texte) -ForegroundColor Cyan
    Write-Host ("=" * 66) -ForegroundColor DarkCyan
}
function Ecrire-Info   { param([string] $t) Write-Host ("  [INFO]   " + $t) -ForegroundColor Gray }
function Ecrire-Succes { param([string] $t) Write-Host ("  [OK]     " + $t) -ForegroundColor Green }
function Ecrire-Alerte { param([string] $t) Write-Host ("  [ALERTE] " + $t) -ForegroundColor Yellow }
function Ecrire-Echec  { param([string] $t) Write-Host ("  [ECHEC]  " + $t) -ForegroundColor Red }

Ecrire-Titre "Compilation HarmonyOS NEXT"

# ---------------------------------------------------------------- outils

function Trouver-Hvigor {
    $commande = Get-Command "hvigorw" -ErrorAction SilentlyContinue
    if ($null -ne $commande) { return $commande.Source }

    $candidats = @(
        "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat",
        (Join-Path $env:LOCALAPPDATA "Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat")
    )
    foreach ($chemin in $candidats) {
        if (Test-Path $chemin) { return $chemin }
    }
    return $null
}

$hvigor = Trouver-Hvigor
if ($null -eq $hvigor) {
    Ecrire-Echec "hvigorw introuvable : DevEco Studio n est pas installe"
    Ecrire-Info  "1. Compte gratuit : https://developer.huawei.com"
    Ecrire-Info  "2. DevEco Studio  : https://developer.huawei.com/consumer/en/deveco-studio"
    Ecrire-Info  "3. Relancez       : powershell -File scripts\installer_environnement.ps1"
    Write-Host ""
    Ecrire-Info  "Solution de repli, sans ligne de commande :"
    Ecrire-Info  ("  ouvrez " + $dossierHarmony + " dans DevEco Studio,")
    Ecrire-Info  "  puis menu Build > Build Hap(s)/APP(s) > Build Hap(s)"
    exit 1
}
Ecrire-Succes ("hvigor : " + $hvigor)

if ([string]::IsNullOrEmpty($env:DEVECO_SDK_HOME)) {
    Ecrire-Alerte "DEVECO_SDK_HOME non definie : la compilation peut echouer"
    Ecrire-Info   "Relancez scripts\installer_environnement.ps1 pour la poser"
}

# ---------------------------------------------------------------- controles

$parametres = Get-Content (Join-Path $racine "configuration\cifi_parametres.json") -Raw | ConvertFrom-Json
$nomSortie = $parametres.identite.nom_fichier_sortie
$version = $parametres.identite.version_affichee

Ecrire-Info ("application : " + $parametres.identite.nom_affiche)
Ecrire-Info ("bundle      : " + $parametres.identite.nom_paquet_harmonyos)
Ecrire-Info ("version     : " + $version)

$rawfile = Join-Path $dossierHarmony "entry\src\main\resources\rawfile\cifi_parametres.json"
if (-not (Test-Path $rawfile)) {
    Ecrire-Alerte "parametres non propages : lancement de appliquer_configuration"
    python (Join-Path $PSScriptRoot "appliquer_configuration.py") | Out-Null
}

if ($Mode -eq "release") {
    $profil = Get-Content (Join-Path $dossierHarmony "build-profile.json5") -Raw
    if ($profil -match '"signingConfigs":\s*\[\s*\]') {
        Ecrire-Alerte "aucun profil de signature : le .hap release ne sera pas publiable"
        Ecrire-Info   "Creez-le dans DevEco : File > Project Structure > Signing Configs"
    }
}

# ---------------------------------------------------------------- compilation

Push-Location $dossierHarmony
try {
    Ecrire-Info "installation des dependances ohpm"
    $ohpm = Get-Command "ohpm" -ErrorAction SilentlyContinue
    if ($null -ne $ohpm) {
        ohpm install --all 2>$null | Out-Null
    } else {
        Ecrire-Alerte "ohpm absent du PATH : etape sautee"
    }

    Ecrire-Info ("compilation du .hap en mode " + $Mode)
    & $hvigor --mode module -p product=default -p buildMode=$Mode assembleHap
    if ($LASTEXITCODE -ne 0) {
        throw "hvigor a echoue (code $LASTEXITCODE)"
    }
} finally {
    Pop-Location
}

# ---------------------------------------------------------------- collecte

Ecrire-Titre "Livrables"

New-Item -ItemType Directory -Path $dossierLivrables -Force | Out-Null

$sources = @(
    (Join-Path $dossierHarmony "entry\build\default\outputs\default"),
    (Join-Path $dossierHarmony "build\default\outputs\default")
)

$collectes = 0
foreach ($source in $sources) {
    if (-not (Test-Path $source)) { continue }
    Get-ChildItem $source -Filter "*.hap" -Recurse | ForEach-Object {
        $nomFinal = ($nomSortie + "_" + $version + "_" + $Mode + ".hap")
        Copy-Item $_.FullName (Join-Path $dossierLivrables $nomFinal) -Force
        $tailleMo = [math]::Round($_.Length / 1MB, 1)
        Ecrire-Succes ($nomFinal + "  (" + $tailleMo + " Mo)")
        $collectes++
    }
}

if ($collectes -eq 0) {
    Ecrire-Echec "aucun .hap produit"
    Ecrire-Info  "Ouvrez le projet dans DevEco Studio pour lire le detail de l erreur"
    exit 1
}

Write-Host ""
Write-Host ("  Dossier : " + $dossierLivrables) -ForegroundColor Cyan
Write-Host "  Installer sur un appareil branche : hdc install <fichier.hap>" -ForegroundColor Gray
