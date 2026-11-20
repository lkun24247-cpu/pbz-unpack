$ErrorActionPreference = "Stop"

$skillRoot = Split-Path -Parent $PSScriptRoot
$profilePath = Join-Path $skillRoot "config\pbz.json"
$profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json

function Use-FirstValue {
    param(
        [string]$EnvironmentName,
        [string]$Fallback
    )

    $value = [Environment]::GetEnvironmentVariable($EnvironmentName)
    if (-not [string]::IsNullOrWhiteSpace($value)) {
        return $value
    }
    return $Fallback
}

$embeddedCli = Join-Path $skillRoot ".build\cli\PbzUnpack.Cli.exe"
$embeddedUsmap = Join-Path $skillRoot $profile.mappings
$cue4 = Use-FirstValue "PBZ_CUE4_CLI" $embeddedCli
$usmap = Use-FirstValue "PBZ_USMAP" $embeddedUsmap
$aesKey = Use-FirstValue "PBZ_AES_KEY" $profile.aesKey

$pakDirectory = [Environment]::GetEnvironmentVariable("PBZ_PAK_DIR")
if ([string]::IsNullOrWhiteSpace($pakDirectory)) {
    try {
        $gameRoot = & (Join-Path $PSScriptRoot "find-pbz-game.ps1")
        $pakDirectory = Join-Path $gameRoot "ProjectPBZ\Content\Paks"
    } catch {
        $pakDirectory = $null
    }
}

[PSCustomObject]@{
    SkillRoot = $skillRoot
    Profile = $profile
    Cue4Cli = $cue4
    Usmap = $usmap
    PakDirectory = $pakDirectory
    AesKey = $aesKey
}
