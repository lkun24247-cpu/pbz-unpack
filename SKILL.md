---
name: pbz-unpack
description: Inspect and export assets from a locally installed Phantom Blade Zero UE5.7 game with bundled AES and usmap profile data. Use for PBZ Pak or IoStore discovery, package inspection, and glTF or ActorX extraction; not for Blender character assembly or mod installation.
---

# PBZ Unpack

Find, inspect, and export Phantom Blade Zero assets without requiring FModel or
temporary tool directories. The repository supplies the CLI source, build
scripts, game profile, AES key, and UE5.7 mappings. The user must supply a local
copy of the game.

## Setup And Verification

Run from the skill root:

```powershell
.\scripts\install.ps1
.\scripts\check-environment.ps1 -Deep
```

The installer uses an existing .NET 10 SDK or downloads a repository-local SDK.
The published CLI is self-contained; later commands do not require a global
.NET installation. Steam libraries are detected automatically. Set
`PBZ_PAK_DIR` for a non-Steam layout.

For an end-to-end inspect-and-export check, run `scripts/smoke-test.ps1`.
Its default sample exports a small weapon PSK into `output/smoke-test`.

## Asset Workflow

List candidate package paths before exporting:

```powershell
.\scripts\pbz.ps1 list --contains "/Characters/EliteBoss/Yuu/" --limit 100
```

Inspect the selected asset and retain its material JSON for provenance:

```powershell
.\scripts\pbz.ps1 inspect `
  --path "Characters/EliteBoss/Yuu/SkinParts/Yuu_Body" `
  --json-dir ".\output\json"
```

Export glTF with materials, or ActorX for PSK/PSA:

```powershell
.\scripts\pbz.ps1 export `
  --path "Characters/EliteBoss/Yuu/SkinParts/Yuu_Body" `
  --out ".\output\Yuu_Body" --format gltf --materials
```

Use ActorX when the native skeleton or animation matters:

```powershell
.\scripts\pbz.ps1 export `
  --path "Characters/EliteBoss/Yuu/SkinParts/Yuu_Body" `
  --out ".\output\Yuu_Body" --format actorx
```

Keep exports outside the repository unless they are intentional test fixtures.
Do not commit extracted game assets. Preserve source package paths in task
notes or generated manifests.

## Profiles And Overrides

`config/pbz.json` supplies the shipped AES key and mapping filename. Override
them for a newer game build with `PBZ_AES_KEY` and `PBZ_USMAP`, or pass
`--aes-key` and `--usmap` directly to the CLI. Do not change the global profile
merely to test another game build.

If package indexing fails after a game update, first verify the exact engine
version, mapping file, and AES key together. A valid AES key cannot compensate
for stale mappings, and correct mappings cannot decrypt with a stale key.

Read [references/troubleshooting.md](references/troubleshooting.md) when path
discovery, native compression, export, or game-version checks fail.
