[CmdletBinding()]
param(
    [string]$AssetPath = "HuaShira/Content/Characters/Hero/ZuoShang/Weapon/ZuoShang_Sword",
    [string]$OutDir
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $root "output\smoke-test"
}

$jsonDir = Join-Path $OutDir "json"
$exportDir = Join-Path $OutDir "actorx"
$entrypoint = Join-Path $PSScriptRoot "pbz.ps1"

Write-Host "Indexing installed game packages..."
& $entrypoint list --limit 1
if ($LASTEXITCODE -ne 0) {
    throw "Package indexing failed."
}

Write-Host "Inspecting $AssetPath..."
& $entrypoint inspect --path $AssetPath --json-dir $jsonDir
if ($LASTEXITCODE -ne 0) {
    throw "Asset inspection failed."
}

Write-Host "Exporting ActorX..."
& $entrypoint export --path $AssetPath --out $exportDir --format actorx
if ($LASTEXITCODE -ne 0) {
    throw "ActorX export failed."
}

$jsonFiles = @(Get-ChildItem -LiteralPath $jsonDir -Filter "*.json" -File)
$pskFiles = @(Get-ChildItem -LiteralPath $exportDir -Filter "*.psk" -File -Recurse)
if ($jsonFiles.Count -eq 0) {
    throw "Inspection returned no JSON files."
}
if ($pskFiles.Count -eq 0 -or ($pskFiles | Where-Object Length -EQ 0)) {
    throw "ActorX export returned no non-empty PSK files."
}

Write-Host "[OK] $($jsonFiles.Count) JSON files"
$pskFiles | ForEach-Object { Write-Host "[OK] $($_.FullName) ($($_.Length) bytes)" }
Write-Host "Smoke test passed. Test exports: $OutDir"
