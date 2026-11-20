# Troubleshooting

## PBZ was not found

Set `PBZ_PAK_DIR` to the directory containing the game's `.pak`, `.utoc`, and
`.ucas` files:

```powershell
$env:PBZ_PAK_DIR = "X:\path\to\PBZ\ProjectPBZ\Content\Paks"
```

For a Steam library that was not detected automatically, inspect discovery:

```powershell
.\scripts\find-pbz-game.ps1 -SteamRoots "X:\SteamLibrary"
```

## Missing CLI or SDK

Run `.\scripts\install.ps1`. It downloads the official .NET installer only when
no suitable SDK exists. The downloaded SDK and build output stay under the
repository's ignored `.tools` and `.build` directories.

## Mapping, AES, or engine mismatch

The included profile targets the game build recorded in `config/pbz.json`. After
a game update, update the AES key and matching `.usmap` together, then update
its expected SHA256. Confirm that CUE4Parse still supports the exact Unreal
Engine version before changing unrelated code.

## Native compression errors

CUE4Parse needs its native Oodle and zlib dependencies. Run commands through
`scripts/pbz.ps1`, which starts the process from the published CLI directory.
Run `scripts/install.ps1 -Force` if a previous publish is incomplete.

## Ambiguous assets and empty exports

An `ASSET_AMBIGUOUS` result prints candidate paths. Pass a longer package path,
or use `--all` only when exporting every match is intended. `inspect` is the
quickest way to verify the exports inside a package before attempting a mesh or
animation export.
