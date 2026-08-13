<#
.SYNOPSIS
    Installs and registers NavSip.dll so signtool can read Business Central
    .app packages. Run once, from an elevated PowerShell.

.DESCRIPTION
    NavSip.dll is the Subject Interface Package for the .app format. It ships
    with Business Central Server rather than the Windows SDK, so signtool has no
    idea what an .app file is until this is registered - it fails with
    "The form specified for the subject is not one supported or known by the
    specified trust provider".

    This downloads the Business Central artifacts (server components only, no
    Docker required), copies NavSip.dll into System32 and SysWOW64, and
    registers it with regsvr32.

    The artifact download is a few hundred MB and is cached, so this is slow the
    first time and instant afterwards.
#>
[CmdletBinding()]
param(
    [string] $Type    = 'sandbox',
    [string] $Country = 'w1',
    [string] $Version = '28'
)

$ErrorActionPreference = 'Stop'

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

# --- must be elevated ----------------------------------------------------

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    throw 'This script must run from an elevated PowerShell (Run as administrator).'
}

# --- already done? -------------------------------------------------------

$base = 'HKLM:\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CryptSIPDllGetSignedDataMsg'
$already = $false
if (Test-Path $base) {
    foreach ($k in Get-ChildItem $base) {
        $dll = (Get-ItemProperty $k.PSPath -Name Dll -ErrorAction SilentlyContinue).Dll
        if ($dll -and $dll -match 'navsip') { $already = $true }
    }
}
if ($already) {
    Write-Step 'NavSip is already registered. Nothing to do.'
    return
}

# --- get the dll ---------------------------------------------------------

if (-not (Get-Module -ListAvailable -Name BcContainerHelper)) {
    Write-Step 'Installing BcContainerHelper (used only to locate and download the artifacts)'
    Install-Module BcContainerHelper -Force -AllowClobber -Scope AllUsers
}
Import-Module BcContainerHelper -DisableNameChecking

Write-Step "Resolving Business Central $Type artifacts ($Country, version $Version)"
$artifactUrl = Get-BCArtifactUrl -type $Type -country $Country -version $Version -select Latest
if (-not $artifactUrl) { throw "No artifacts found for type=$Type country=$Country version=$Version" }
Write-Step $artifactUrl

Write-Step 'Downloading artifacts - this is the slow part, and it is cached'
$paths = Download-Artifacts -artifactUrl $artifactUrl -includePlatform

$navSip = $null
foreach ($p in $paths) {
    $found = Get-ChildItem $p -Recurse -Filter 'NavSip.dll' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $navSip = $found.FullName; break }
}
if (-not $navSip) { throw 'NavSip.dll was not found in the downloaded artifacts' }
Write-Step "Found $navSip"

# --- install and register ------------------------------------------------

foreach ($dir in @("$env:SystemRoot\System32", "$env:SystemRoot\SysWOW64")) {
    if (Test-Path $dir) {
        Copy-Item $navSip -Destination $dir -Force
        Write-Step "Copied to $dir"
    }
}

Write-Step 'Registering with regsvr32'
Start-Process regsvr32.exe -ArgumentList '/s', "$env:SystemRoot\System32\NavSip.dll" -Wait -NoNewWindow
if (Test-Path "$env:SystemRoot\SysWOW64\NavSip.dll") {
    Start-Process "$env:SystemRoot\SysWOW64\regsvr32.exe" -ArgumentList '/s', "$env:SystemRoot\SysWOW64\NavSip.dll" -Wait -NoNewWindow
}

# --- confirm -------------------------------------------------------------

$ok = $false
foreach ($k in Get-ChildItem $base) {
    $dll = (Get-ItemProperty $k.PSPath -Name Dll -ErrorAction SilentlyContinue).Dll
    if ($dll -and $dll -match 'navsip') { $ok = $true }
}

if ($ok) {
    Write-Step 'NavSip registered. You can now run sign.ps1.'
} else {
    throw 'Registration did not take effect - check the regsvr32 output and try manually.'
}
