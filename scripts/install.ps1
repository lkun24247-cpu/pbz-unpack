[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$env:DOTNET_CLI_TELEMETRY_OPTOUT = "1"
$env:DOTNET_NOLOGO = "1"
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root "src\PbzUnpack.Cli\PbzUnpack.Cli.csproj"
$output = Join-Path $root ".build\cli"
$localDotnetRoot = Join-Path $root ".tools\dotnet"
$localDotnet = Join-Path $localDotnetRoot "dotnet.exe"

$dotnet = $null
$globalDotnet = Get-Command dotnet -ErrorAction SilentlyContinue
if ($globalDotnet) {
    $sdks = & $globalDotnet.Source --list-sdks
    if ($sdks -match '^10\.') {
        $dotnet = $globalDotnet.Source
    }
}

if (-not $dotnet -and (Test-Path -LiteralPath $localDotnet -PathType Leaf)) {
    $sdks = & $localDotnet --list-sdks
    if ($sdks -match '^10\.') {
        $dotnet = $localDotnet
    }
}

if (-not $dotnet) {
    Write-Host "No .NET 10 SDK found. Installing a repository-local SDK..."
    $toolsDir = Split-Path -Parent $localDotnetRoot
    New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
    $installer = Join-Path $toolsDir "dotnet-install.ps1"
    Invoke-WebRequest -Uri "https://dot.net/v1/dotnet-install.ps1" -OutFile $installer
    & $installer -Channel "10.0" -InstallDir $localDotnetRoot -NoPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $localDotnet -PathType Leaf)) {
        throw "The repository-local .NET SDK installation failed."
    }
    $dotnet = $localDotnet
}

if ($Force -and (Test-Path -LiteralPath $output)) {
    $resolvedOutput = (Resolve-Path -LiteralPath $output).Path
    $resolvedBuildRoot = (Resolve-Path -LiteralPath (Join-Path $root ".build")).Path
    if (-not $resolvedOutput.StartsWith($resolvedBuildRoot + [IO.Path]::DirectorySeparatorChar)) {
        throw "Refusing to clean unexpected output path: $resolvedOutput"
    }
    Remove-Item -LiteralPath $resolvedOutput -Recurse -Force
}

Write-Host "Publishing self-contained Windows x64 CLI..."
& $dotnet publish $project `
    --configuration Release `
    --runtime win-x64 `
    --self-contained true `
    --output $output `
    -p:DebugType=None `
    -p:DebugSymbols=false
if ($LASTEXITCODE -ne 0) {
    throw "CLI publish failed with exit code $LASTEXITCODE."
}

$exe = Join-Path $output "PbzUnpack.Cli.exe"
$helpOutput = & $exe --help
$helpExitCode = $LASTEXITCODE
$helpOutput | Select-Object -First 1
if ($helpExitCode -ne 0) {
    throw "The published CLI failed its help smoke test."
}

Write-Host "Installed: $exe"
Write-Host "Next: .\scripts\check-environment.ps1 -Deep"
