<#
    CiFi Tech - Installation du NDK Android depuis une archive telechargee

    A utiliser quand "sdkmanager --install ndk;..." echoue, par exemple
    quand la connexion coupe ou qu'un antivirus interrompt le transfert.

    MODE D'EMPLOI
    -------------
    1. Telechargez l'archive du NDK depuis :
           https://developer.android.com/ndk/downloads
       Choisissez la version r28c pour Windows.
       Lien direct habituel :
           https://dl.google.com/android/repository/android-ndk-r28c-windows.zip

    2. Laissez le fichier dans votre dossier Telechargements,
       ou notez son chemin exact.

    3. Lancez :
           powershell -ExecutionPolicy Bypass -File scripts\installer_ndk_manuel.ps1

       Le script cherche l'archive tout seul dans votre dossier
       Telechargements. Si elle est ailleurs :
           powershell -File scripts\installer_ndk_manuel.ps1 -Archive "D:\ndk.zip"

    Le script verifie que l'installation est complete : il refuse de se
    declarer satisfait tant que source.properties n'est pas en place.
#>

[CmdletBinding()]
param(
    [string] $Archive = "",
    [string] $RacineSdk = "",
    [string] $VersionNdk = "28.2.13676358"
)

$ErrorActionPreference = "Stop"

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

function Obtenir-DossierTemporaire {
    try {
        return (Get-Item -LiteralPath $env:TEMP -ErrorAction Stop).FullName
    } catch {
        return $env:TEMP
    }
}

function Supprimer-Silencieux {
    param([string] $chemin)
    if ([string]::IsNullOrEmpty($chemin)) { return }
    if (-not (Test-Path -LiteralPath $chemin)) { return }
    try {
        Remove-Item -LiteralPath $chemin -Recurse -Force -ErrorAction Stop
    } catch {
        Ecrire-Info ("menage impossible, sans consequence : " + $chemin)
    }
}

Ecrire-Titre "Installation manuelle du NDK Android"

# ---------------------------------------------------------------- 1. ou va le NDK

if ([string]::IsNullOrEmpty($RacineSdk)) {
    $RacineSdk = [Environment]::GetEnvironmentVariable("ANDROID_HOME", "User")
}
if ([string]::IsNullOrEmpty($RacineSdk)) {
    $RacineSdk = "C:\outils_mobile\android_sdk"
}

$destination = Join-Path $RacineSdk ("ndk\" + $VersionNdk)
$temoin = Join-Path $destination "source.properties"

Ecrire-Info ("SDK Android  : " + $RacineSdk)
Ecrire-Info ("destination  : " + $destination)

if (Test-Path -LiteralPath $temoin) {
    Ecrire-Succes "le NDK est deja installe et complet, rien a faire"
    exit 0
}

# ---------------------------------------------------------------- 2. trouver l'archive

if ([string]::IsNullOrEmpty($Archive)) {
    $dossiersRecherche = @(
        (Join-Path $env:USERPROFILE "Downloads"),
        (Join-Path $env:USERPROFILE "Telechargements"),
        (Join-Path $env:USERPROFILE "Desktop"),
        (Obtenir-DossierTemporaire)
    )

    foreach ($dossier in $dossiersRecherche) {
        if (-not (Test-Path -LiteralPath $dossier)) { continue }
        $trouve = Get-ChildItem -LiteralPath $dossier -Filter "android-ndk-*.zip" `
                                -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending |
                  Select-Object -First 1
        if ($null -ne $trouve) {
            $Archive = $trouve.FullName
            Ecrire-Succes ("archive trouvee : " + $Archive)
            break
        }
    }
}

if ([string]::IsNullOrEmpty($Archive) -or -not (Test-Path -LiteralPath $Archive)) {
    Ecrire-Echec "archive du NDK introuvable"
    Write-Host ""
    Ecrire-Info "1. Telechargez-la ici : https://developer.android.com/ndk/downloads"
    Ecrire-Info "   Version r28c, Windows 64 bits."
    Ecrire-Info "   Lien direct : https://dl.google.com/android/repository/android-ndk-r28c-windows.zip"
    Ecrire-Info "2. Laissez le fichier dans Telechargements, puis relancez ce script."
    Ecrire-Info "   Ou indiquez son chemin :"
    Ecrire-Info "     powershell -File scripts\installer_ndk_manuel.ps1 -Archive ""D:\ndk.zip"""
    exit 1
}

$tailleGo = [math]::Round((Get-Item -LiteralPath $Archive).Length / 1GB, 2)
Ecrire-Info ("taille de l archive : " + $tailleGo + " Go")
if ($tailleGo -lt 0.5) {
    Ecrire-Alerte "archive anormalement petite : telechargement probablement incomplet"
    Ecrire-Info   "Retelechargez-la avant de continuer."
    exit 1
}

# ---------------------------------------------------------------- 3. extraction

$temporaire = Join-Path (Obtenir-DossierTemporaire) "cifi_ndk_extrait"
Supprimer-Silencieux $temporaire

Ecrire-Info "extraction en cours (plusieurs minutes, ~3 Go)"
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($Archive, $temporaire)
} catch {
    Ecrire-Echec ("extraction impossible : " + $_.Exception.Message)
    Ecrire-Info  "L archive est peut-etre corrompue. Retelechargez-la."
    Supprimer-Silencieux $temporaire
    exit 1
}
Ecrire-Succes "archive extraite"

# ---------------------------------------------------------------- 4. mise en place

# L'archive contient un dossier unique, du genre android-ndk-r28c.
# C'est son CONTENU qui doit atterrir dans ndk\<version>\, pas le dossier
# lui-meme : Gradle cherche source.properties directement a la racine.
$racineExtraite = $temporaire
$contenu = Get-ChildItem -LiteralPath $temporaire
if ($contenu.Count -eq 1 -and $contenu[0].PSIsContainer) {
    $racineExtraite = $contenu[0].FullName
    Ecrire-Info ("dossier interne : " + $contenu[0].Name)
}

if (-not (Test-Path -LiteralPath (Join-Path $racineExtraite "source.properties"))) {
    Ecrire-Echec "source.properties absent de l archive : ce n est pas un NDK valide"
    Supprimer-Silencieux $temporaire
    exit 1
}

Supprimer-Silencieux $destination
New-Item -ItemType Directory -Path $destination -Force | Out-Null

Ecrire-Info "copie vers le SDK Android"
Copy-Item (Join-Path $racineExtraite "*") $destination -Recurse -Force

Supprimer-Silencieux $temporaire

# ---------------------------------------------------------------- 5. verification

Ecrire-Titre "Verification"

if (-not (Test-Path -LiteralPath $temoin)) {
    Ecrire-Echec "source.properties absent apres copie : installation incomplete"
    exit 1
}

$versionLue = (Select-String -Path $temoin -Pattern "Pkg.Revision" |
               Select-Object -First 1).Line
Ecrire-Succes ("NDK installe : " + $destination)
Ecrire-Succes ("version : " + $versionLue)

$poidsGo = [math]::Round(((Get-ChildItem -LiteralPath $destination -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum / 1GB), 2)
Ecrire-Info ("poids sur le disque : " + $poidsGo + " Go")
Ecrire-Info ("disque C: libre : " + [math]::Round((Get-PSDrive -Name C).Free/1GB,1) + " Go")

Write-Host ""
Write-Host "  Vous pouvez maintenant compiler :" -ForegroundColor Cyan
Write-Host "    powershell -File scripts\compiler_android.ps1"
exit 0
