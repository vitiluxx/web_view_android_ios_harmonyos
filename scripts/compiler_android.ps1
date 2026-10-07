<#
    CiFi Tech - Compilation Android

        powershell -ExecutionPolicy Bypass -File scripts\compiler_android.ps1

    Options :
        -Type apk        APK unique, installable a la main (defaut)
        -Type aab        bundle Play Store
        -Type tout       les deux
        -Debogage        version de test, non signee pour la production
        -SansDecoupage   un seul APK au lieu d un par architecture

    Resultat depose dans :
        livrables\android\
#>

[CmdletBinding()]
param(
    [ValidateSet("apk", "aab", "tout")]
    [string] $Type = "apk",
    [switch] $Debogage,
    [switch] $SansDecoupage
)

$ErrorActionPreference = "Stop"

$racine = Split-Path -Parent $PSScriptRoot
$dossierFlutter = Join-Path $racine "cifi_application"
$dossierLivrables = Join-Path $racine "livrables\android"

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

# ---------------------------------------------------------------- controles

Ecrire-Titre "Compilation Android"

if (-not (Test-Path (Join-Path $dossierFlutter "android"))) {
    Ecrire-Echec "projet Android absent"
    Ecrire-Info  "Lancez d abord : powershell -File scripts\initialiser_projet.ps1"
    exit 1
}

$parametres = Get-Content (Join-Path $racine "configuration\cifi_parametres.json") -Raw | ConvertFrom-Json
$nomSortie = $parametres.identite.nom_fichier_sortie
$version = $parametres.identite.version_affichee

Ecrire-Info ("application : " + $parametres.identite.nom_affiche)
Ecrire-Info ("site cible  : " + $parametres.site_cible.url_accueil)
Ecrire-Info ("version     : " + $version)

$fichierSignature = Join-Path $dossierFlutter "android\cles\cle.proprietes"
if (-not $Debogage) {
    if (Test-Path $fichierSignature) {
        Ecrire-Succes "cle de signature trouvee : version publiable"
    } else {
        Ecrire-Alerte "AUCUNE cle de signature : l APK sera signe avec la cle de debogage"
        Ecrire-Alerte "Il ne sera PAS acceptable par le Play Store."
        Ecrire-Info   ("Modele a remplir : " + (Join-Path $dossierFlutter "android\cles\cle.proprietes.modele"))
    }
}

# ---------------------------------------------------------------- compilation

New-Item -ItemType Directory -Path $dossierLivrables -Force | Out-Null

$mode = if ($Debogage) { "--debug" } else { "--release" }
# Le decoupage ne concerne que les APK. Le bundle AAB est decoupe par
# le Play Store lui-meme, il ne prend jamais cette option.
$decoupage = if ($SansDecoupage) { "" } else { "--split-per-abi" }

Push-Location $dossierFlutter
try {
    Ecrire-Info "nettoyage"
    flutter clean | Out-Null
    flutter pub get | Out-Null

    if ($Type -eq "apk" -or $Type -eq "tout") {
        Ecrire-Info ("compilation APK " + $mode)
        if ($decoupage -ne "") {
            flutter build apk $mode $decoupage
        } else {
            flutter build apk $mode
        }

        if ($LASTEXITCODE -ne 0) { throw "compilation APK echouee" }
    }

    if ($Type -eq "aab" -or $Type -eq "tout") {
        Ecrire-Info ("compilation AAB " + $mode)
        flutter build appbundle $mode
        if ($LASTEXITCODE -ne 0) { throw "compilation AAB echouee" }
    }
} finally {
    Pop-Location
}

# ---------------------------------------------------------------- collecte

Ecrire-Titre "Livrables"

$sourceApk = Join-Path $dossierFlutter "build\app\outputs\flutter-apk"
$sourceAab = Join-Path $dossierFlutter "build\app\outputs\bundle"

$collectes = 0

if (Test-Path $sourceApk) {
    Get-ChildItem $sourceApk -Filter "*.apk" | ForEach-Object {
        # app-arm64-v8a-release.apk  ->  arm64-v8a
        # app-release.apk            ->  universel
        $suffixe = $_.BaseName -replace "^app-?", "" -replace "-?release$", "" -replace "-?debug$", ""
        if ($suffixe -eq "" -or $suffixe -eq "app") { $suffixe = "universel" }
        $nomFinal = ($nomSortie + "_" + $version + "_" + $suffixe + ".apk")
        Copy-Item $_.FullName (Join-Path $dossierLivrables $nomFinal) -Force
        $tailleMo = [math]::Round($_.Length / 1MB, 1)
        Ecrire-Succes ($nomFinal + "  (" + $tailleMo + " Mo)")
        $collectes++
    }
}

if (Test-Path $sourceAab) {
    Get-ChildItem $sourceAab -Filter "*.aab" -Recurse | ForEach-Object {
        $nomFinal = ($nomSortie + "_" + $version + ".aab")
        Copy-Item $_.FullName (Join-Path $dossierLivrables $nomFinal) -Force
        $tailleMo = [math]::Round($_.Length / 1MB, 1)
        Ecrire-Succes ($nomFinal + "  (" + $tailleMo + " Mo)")
        $collectes++
    }
}

if ($collectes -eq 0) {
    Ecrire-Echec "aucun livrable produit"
    exit 1
}

Write-Host ""
Write-Host ("  Dossier : " + $dossierLivrables) -ForegroundColor Cyan
Write-Host "  Installer sur un telephone branche : adb install -r <fichier.apk>" -ForegroundColor Gray
