[CmdletBinding()]
param(
    [string[]]$SteamRoots = @()
)

$ErrorActionPreference = "Stop"
$candidates = [System.Collections.Generic.List[string]]::new()

function Add-SteamRoot {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }
    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if (Test-Path -LiteralPath $expanded) {
        $resolved = (Resolve-Path -LiteralPath $expanded).Path
        if (-not $candidates.Contains($resolved)) {
            $candidates.Add($resolved)
        }
    }
}

foreach ($root in $SteamRoots) {
    Add-SteamRoot $root
}

$steamPath = $null
try {
    $steamPath = (Get-ItemProperty -LiteralPath "HKCU:\Software\Valve\Steam" -ErrorAction Stop).SteamPath
} catch {
    $steamPath = $null
}
if ($steamPath) {
    Add-SteamRoot $steamPath
}
Add-SteamRoot "${env:ProgramFiles(x86)}\Steam"
Add-SteamRoot "$env:ProgramFiles\Steam"

$libraryFiles = foreach ($root in @($candidates)) {
    Join-Path $root "steamapps\libraryfolders.vdf"
}
foreach ($libraryFile in $libraryFiles) {
    if (-not (Test-Path -LiteralPath $libraryFile -PathType Leaf)) {
        continue
    }
    $text = Get-Content -LiteralPath $libraryFile -Raw
    foreach ($match in [regex]::Matches($text, '"path"\s+"(?<path>[^"]+)"')) {
        Add-SteamRoot ($match.Groups["path"].Value -replace "\\\\", "\")
    }
}

foreach ($root in @("C:\SteamLibrary", "D:\SteamLibrary", "E:\SteamLibrary", "C:\Steam", "D:\Steam", "E:\Steam")) {
    Add-SteamRoot $root
}

$found = foreach ($root in $candidates) {
    $gameRoot = Join-Path $root "steamapps\common\PBZ"
    $exe = Join-Path $gameRoot "platform\steam\PBZ.exe"
    if (Test-Path -LiteralPath $exe -PathType Leaf) {
        $gameRoot
    }
}

$found = @($found | Sort-Object -Unique)
if ($found.Count -eq 0) {
    throw "PBZ was not found in the discovered Steam libraries. Set PBZ_PAK_DIR or pass -SteamRoots 'X:\SteamLibrary'."
}
if ($found.Count -gt 1) {
    Write-Warning "Multiple PBZ installations were found; using the first one."
    $found | ForEach-Object { Write-Host $_ }
}

$found[0]
