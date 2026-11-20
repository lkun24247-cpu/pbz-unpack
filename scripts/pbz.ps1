[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$PbzArgs
)

$ErrorActionPreference = "Stop"
$tools = & (Join-Path $PSScriptRoot "Resolve-PbzTools.ps1")

if (-not (Test-Path -LiteralPath $tools.Cue4Cli -PathType Leaf)) {
    throw "The CLI is not built. Run .\scripts\install.ps1 first."
}

$env:PBZ_USMAP = $tools.Usmap
$env:PBZ_AES_KEY = $tools.AesKey

$isHelp = $PbzArgs.Count -eq 0 -or $PbzArgs[0] -in @("help", "--help", "-h")
$hasPakOption = $PbzArgs -contains "--paks"
if (-not $isHelp -and [string]::IsNullOrWhiteSpace($tools.PakDirectory) -and -not $hasPakOption) {
    throw "PBZ was not found. Set PBZ_PAK_DIR to ProjectPBZ\Content\Paks or pass --paks PATH."
}
if (-not [string]::IsNullOrWhiteSpace($tools.PakDirectory)) {
    $env:PBZ_PAK_DIR = $tools.PakDirectory
}
$env:PBZ_CALLER_DIR = (Get-Location).Path

Push-Location (Split-Path -Parent $tools.Cue4Cli)
try {
    & $tools.Cue4Cli @PbzArgs
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $exitCode
