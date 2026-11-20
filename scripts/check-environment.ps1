[CmdletBinding()]
param(
    [switch]$Deep
)

$ErrorActionPreference = "Stop"
$tools = & (Join-Path $PSScriptRoot "Resolve-PbzTools.ps1")
$failed = $false

function Test-RequiredPath {
    param(
        [string]$Name,
        [string]$Path,
        [switch]$Directory
    )

    $type = if ($Directory) { "Container" } else { "Leaf" }
    if (-not [string]::IsNullOrWhiteSpace($Path) -and (Test-Path -LiteralPath $Path -PathType $type)) {
        Write-Host "[OK] ${Name}: $Path"
        return $true
    }

    Write-Warning "[MISSING] ${Name}: $Path"
    return $false
}

$cliReady = Test-RequiredPath "CLI" $tools.Cue4Cli
$mapReady = Test-RequiredPath "Mappings" $tools.Usmap
$pakReady = Test-RequiredPath "PBZ Paks" $tools.PakDirectory -Directory
$failed = -not ($cliReady -and $mapReady -and $pakReady)

if ($tools.AesKey -notmatch '^0x[0-9A-Fa-f]{64}$') {
    Write-Warning "[INVALID] AES key must contain 0x followed by 64 hexadecimal characters."
    $failed = $true
} else {
    Write-Host "[OK] AES key format (value not printed)"
}

$actualMapHash = $null
if ($mapReady) {
    $actualMapHash = (Get-FileHash -LiteralPath $tools.Usmap -Algorithm SHA256).Hash
    if ($actualMapHash -ne $tools.Profile.mappingSha256) {
        Write-Warning "[CHANGED] Mapping SHA256 differs from config/pbz.json."
    } else {
        Write-Host "[OK] Mapping SHA256"
    }
}

if ($cliReady) {
    $helpOutput = & $tools.Cue4Cli --help
    $helpExitCode = $LASTEXITCODE
    $helpOutput | Select-Object -First 1
    if ($helpExitCode -ne 0) {
        $failed = $true
    }
}

if ($Deep -and -not $failed) {
    Write-Host "Checking encrypted PBZ package index..."
    & (Join-Path $PSScriptRoot "pbz.ps1") list --limit 1
    if ($LASTEXITCODE -ne 0) {
        $failed = $true
    }
}

if ($failed) {
    Write-Error "PBZ unpack environment check failed."
    exit 1
}

Write-Host "PBZ unpack environment is ready."
