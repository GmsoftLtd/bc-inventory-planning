<#
.SYNOPSIS
    Builds and signs Business Central .app packages with Azure Artifact Signing.

.DESCRIPTION
    Downloads the two tool packages it needs on first run (signtool from the
    Windows SDK build tools, and the Artifact Signing dlib), then signs via the
    gmsoftsigning account. No certificate file is involved - the key lives in
    Microsoft's HSMs and only a digest leaves this machine.

    Prerequisites, both one-off:
      1. NavSip.dll registered - run .\install-navsip.ps1 as administrator.
         Without it signtool cannot read the .app format at all.
      2. Azure sign-in - "az login", or set AZURE_TENANT_ID / AZURE_CLIENT_ID /
         AZURE_CLIENT_SECRET for a service principal.
      The signing identity needs the "Artifact Signing Certificate Profile
      Signer" role on the gmsoftsigning account.

.EXAMPLE
    .\sign.ps1 -Build
    Compiles InventoryPlanning and signs the resulting .app.

.EXAMPLE
    .\sign.ps1 -Path "C:\apps\GMSOFT Limited_Vendor Dispute_1.2.5.0.app"
    Signs an existing package.
#>
[CmdletBinding()]
param(
    [string[]] $Path,
    [switch]   $Build,
    [string]   $Project = "$PSScriptRoot\..\InventoryPlanning",
    [string]   $OutDir  = "$PSScriptRoot\out",
    [switch]   $SkipVerify
)

$ErrorActionPreference = 'Stop'

$SdkVersion   = '10.0.28000.2526'
$ClientVersion = '1.0.95'
$ToolsDir     = "$PSScriptRoot\.tools"
$TimestampUrl = 'http://timestamp.acs.microsoft.com'

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "!!  $msg" -ForegroundColor Yellow }

# --- tooling -------------------------------------------------------------

function Restore-Tool($id, $version) {
    $dest = Join-Path $ToolsDir "$id.$version"
    if (Test-Path $dest) { return $dest }
    New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null
    Write-Step "Downloading $id $version"
    $tmp = Join-Path $ToolsDir "$id.$version.zip"
    Invoke-WebRequest -UseBasicParsing -OutFile $tmp `
        -Uri "https://api.nuget.org/v3-flatcontainer/$id/$version/$id.$version.nupkg"
    Expand-Archive -Path $tmp -DestinationPath $dest -Force
    Remove-Item $tmp
    return $dest
}

function Get-SignTool {
    $pkg = Restore-Tool 'microsoft.windows.sdk.buildtools' $SdkVersion
    $exe = Get-ChildItem $pkg -Recurse -Filter signtool.exe |
           Where-Object { $_.FullName -match '\\x64\\' } | Select-Object -First 1
    if (-not $exe) { throw 'signtool.exe not found in the SDK build tools package' }
    return $exe.FullName
}

function Get-Dlib {
    $pkg = Restore-Tool 'microsoft.trusted.signing.client' $ClientVersion
    $dll = Get-ChildItem $pkg -Recurse -Filter 'Azure.CodeSigning.Dlib.dll' |
           Where-Object { $_.FullName -match '\\x64\\' } | Select-Object -First 1
    if (-not $dll) { throw 'Azure.CodeSigning.Dlib.dll not found in the signing client package' }
    return $dll.FullName
}

function Get-AlCompiler {
    $ext = Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Directory -Filter 'ms-dynamics-smb.al-*' |
           Sort-Object Name -Descending | Select-Object -First 1
    if (-not $ext) { throw 'AL Language extension not found - cannot build' }
    $alc = Join-Path $ext.FullName 'bin\win32\alc.exe'
    if (-not (Test-Path $alc)) { throw "alc.exe not found at $alc" }
    return $alc
}

# --- prerequisite check --------------------------------------------------

function Test-NavSip {
    $base = 'HKLM:\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CryptSIPDllGetSignedDataMsg'
    if (-not (Test-Path $base)) { return $false }
    foreach ($k in Get-ChildItem $base) {
        $dll = (Get-ItemProperty $k.PSPath -Name Dll -ErrorAction SilentlyContinue).Dll
        if ($dll -and $dll -match 'navsip') { return $true }
    }
    return $false
}

if (-not (Test-NavSip)) {
    Write-Warn 'NavSip.dll is not registered on this machine.'
    Write-Warn 'signtool cannot read the .app format without it, and signing will fail.'
    Write-Warn 'Run install-navsip.ps1 from an elevated PowerShell first.'
    throw 'Missing prerequisite: NavSip.dll'
}

# --- build ---------------------------------------------------------------

$targets = @()

if ($Build) {
    $alc = Get-AlCompiler
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $manifest = Get-Content (Join-Path $Project 'app.json') -Raw | ConvertFrom-Json
    $appFile  = Join-Path $OutDir ("{0}_{1}_{2}.app" -f $manifest.publisher, $manifest.name, $manifest.version)

    Write-Step "Building $($manifest.name) $($manifest.version)"
    & $alc "/project:$Project" "/packagecachepath:$Project\.alpackages" "/out:$appFile"
    if ($LASTEXITCODE -ne 0) { throw "Build failed with exit code $LASTEXITCODE" }
    if (-not (Test-Path $appFile)) { throw "Build reported success but $appFile is missing" }

    $targets += $appFile
}

if ($Path) { $targets += $Path }

if (-not $targets) { throw 'Nothing to sign. Pass -Build, or -Path <file.app>.' }

# --- sign ----------------------------------------------------------------

$signtool = Get-SignTool
$dlib     = Get-Dlib
$metadata = Join-Path $PSScriptRoot 'metadata.json'

Write-Step "signtool : $signtool"
Write-Step "dlib     : $dlib"
Write-Step "metadata : $metadata"

$failed = @()

foreach ($t in $targets) {
    if (-not (Test-Path $t)) { throw "File not found: $t" }
    Write-Step "Signing $(Split-Path $t -Leaf)"

    & $signtool sign /v /debug `
        /fd SHA256 `
        /tr $TimestampUrl /td SHA256 `
        /dlib $dlib /dmdf $metadata `
        $t

    if ($LASTEXITCODE -ne 0) {
        Write-Warn "signtool exited with $LASTEXITCODE for $t"
        $failed += $t
        continue
    }

    if (-not $SkipVerify) {
        Write-Step "Verifying $(Split-Path $t -Leaf)"
        & $signtool verify /pa /v $t
        if ($LASTEXITCODE -ne 0) { Write-Warn "Verification returned $LASTEXITCODE - check the output above" }
    }
}

if ($failed) {
    Write-Warn "Failed: $($failed.Count) of $($targets.Count)"
    $failed | ForEach-Object { Write-Warn "  $_" }
    exit 1
}

Write-Step "Signed $($targets.Count) file(s) successfully"
$targets | ForEach-Object { Write-Host "    $_" }
