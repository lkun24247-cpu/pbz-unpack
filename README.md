# PBZ Unpack

面向《影之刃零》（Phantom Blade Zero）本地游戏文件的 UE5.7 资产检索、检查与导出工具，同时提供可直接安装的 Codex skill。

项目包含：

- 基于 CUE4Parse 的命令行工具源码；
- 对应游戏版本的 **AES 密钥**与 **完整 `.usmap` 映射文件**；
- Steam 多盘符游戏目录自动发现；
- 一键构建、环境检查和真实 Pak 索引测试；
- `list`、`inspect`、`export` 三种工作流，支持 glTF、GLB、PSK、PSA 与材质 JSON；
- 从源码复现的构建方式，不依赖个人电脑路径或临时工作目录。

> **版本范围**：内置配置对应 `5.7.4-301524`，详见 [`config/pbz.json`](config/pbz.json)。游戏更新后，AES、映射和引擎版本可能需要一起更新。

## 环境要求

- Windows 10/11 x64；
- PowerShell 5.1 或 PowerShell 7；
- 已安装的《影之刃零》，或该游戏的 `ProjectPBZ\Content\Paks` 目录；
- 首次构建时可访问 NuGet 和 Microsoft 官方 .NET 下载站点。

不需要预先安装 Blender、FModel、Visual Studio 或全局 .NET SDK。安装脚本会优先使用已有 .NET 10 SDK，缺少时下载到仓库内的 `.tools` 目录。最终 CLI 为自包含应用，日常运行不需要全局 .NET。

## 快速开始

```powershell
git clone https://github.com/lkun24247-cpu/pbz-unpack.git
cd pbz-unpack
.\scripts\install.ps1
.\scripts\check-environment.ps1 -Deep
```

如果 PowerShell 禁止运行本地脚本，可在当前进程临时放宽策略：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

`-Deep` 会实际挂载游戏 Pak、使用 AES 解密并读取资产索引，不只是检查文件是否存在。

还要验证 JSON 检查和 ActorX 导出时，可运行：

```powershell
.\scripts\smoke-test.ps1
```

默认样本会导出 `ZuoShang_Sword.psk` 到被 Git 忽略的 `output\smoke-test`，可用 `-AssetPath` 和 `-OutDir` 更换测试目标。

### 1. 搜索资产

```powershell
.\scripts\pbz.ps1 list --contains "/Characters/EliteBoss/Yuu/" --limit 100
```

正则搜索：

```powershell
.\scripts\pbz.ps1 list --regex "Yuu/.*(SkinParts|Material|Texture|Anim)/" --limit 500
```

### 2. 检查资产

```powershell
.\scripts\pbz.ps1 inspect `
  --path "Characters/EliteBoss/Yuu/SkinParts/Yuu_Body" `
  --json-dir ".\output\json"
```

`inspect` 会列出包内导出对象；指定 `--json-dir` 后，还会保存材质、网格等对象的 JSON，便于后续审计材质参数。

### 3. 导出资产

导出 glTF 网格、材质和纹理：

```powershell
.\scripts\pbz.ps1 export `
  --path "Characters/EliteBoss/Yuu/SkinParts/Yuu_Body" `
  --out ".\output\Yuu_Body" --format gltf --materials
```

导出 ActorX（PSK/PSA）：

```powershell
.\scripts\pbz.ps1 export `
  --path "Characters/EliteBoss/Yuu/SkinParts/Yuu_Body" `
  --out ".\output\Yuu_Body" --format actorx
```

`--format psk` 与 `--format psa` 是 `actorx` 的别名。网格默认使用 glTF，动画默认使用 ActorX；也可以显式使用 `--format auto`。

## 游戏路径与配置

工具会读取 Steam 注册表及 `libraryfolders.vdf`，自动检测常见 Steam 库目录。其他安装方式可设置：

```powershell
$env:PBZ_PAK_DIR = "X:\path\to\PBZ\ProjectPBZ\Content\Paks"
```

支持以下覆盖项：

| 环境变量 | 用途 |
| --- | --- |
| `PBZ_PAK_DIR` | 游戏 Pak 目录 |
| `PBZ_USMAP` | 自定义 `.usmap` 映射文件 |
| `PBZ_AES_KEY` | 自定义 AES 密钥 |
| `PBZ_CUE4_CLI` | 自定义已构建 CLI 路径 |
| `PBZ_ASSET_PATH` | CLI 默认资产路径 |
| `PBZ_EXPORT_DIR` | CLI 默认导出目录 |

命令行参数 `--paks`、`--usmap`、`--aes-key`、`--path`、`--out` 优先于同名环境变量。AES 密钥属于游戏版本配置，不是 GitHub 或个人账号凭据；请不要把个人访问令牌写入此项目。

## 安装为 Codex Skill

在 Codex 中，可直接把仓库指定为 skill 来源进行安装，或手动克隆到：

```text
%USERPROFILE%\.codex\skills\pbz-unpack
```

然后完成一次 `scripts\install.ps1` 构建。之后可这样提问：

```text
使用 $pbz-unpack 查找并导出 Yuu_Body，保留材质 JSON。
```

skill 入口为 [`SKILL.md`](SKILL.md)，不依赖你机器上已有的其他 PBZ skill。

## 仓库结构

```text
pbz-unpack/
├─ config/pbz.json                 # 游戏版本、AES 与映射校验值
├─ mappings/                      # 完整 UE 类型映射
├─ src/PbzUnpack.Cli/             # CLI 源码与 NuGet 依赖锁定版本
├─ scripts/                       # 安装、发现、检查和统一命令入口
├─ agents/openai.yaml             # Codex 调用元数据
├─ references/troubleshooting.md  # 故障排查
└─ SKILL.md                       # Codex skill 入口
```

`.build`、`.tools`、`output`、游戏导出物和缓存均已排除在 Git 跟踪之外。

## 更新游戏配置

1. 将新映射放入 `mappings`，或用 `PBZ_USMAP` 临时测试。
2. 在 `config/pbz.json` 更新 `gameBuild`、`aesKey`、`mappings` 与 `mappingSha256`。
3. 如果引擎小版本变化，更新 CLI 的 `VersionContainer` 并确认 CUE4Parse 支持。
4. 运行 `check-environment.ps1 -Deep`，再执行一次小规模 `inspect` 与 `export`。

## 常见问题

- **提示找不到游戏**：设置 `PBZ_PAK_DIR`，或先用 `find-pbz-game.ps1 -SteamRoots` 检查 Steam 库发现。
- **提示 ASSET_AMBIGUOUS**：从输出中选择更完整的 `--path`；确认需要导出全部匹配项时才加 `--all`。
- **解密或映射失败**：不要只更换 AES。确认密钥、映射和实际游戏版本相匹配。
- **原生压缩库错误**：使用 `scripts\install.ps1 -Force` 重新发布，并始终通过 `scripts\pbz.ps1` 运行。

更多排查见 [`references/troubleshooting.md`](references/troubleshooting.md)。

## 许可与边界

本仓库不包含游戏 Pak、模型、纹理或其他提取后的商业游戏资源，仅提供互操作所需的配置、类型映射与工具源码。请仅处理你合法持有的游戏副本，并遵守游戏条款及当地法律。

原创脚本与 CLI 源码采用 [MIT License](LICENSE)。CUE4Parse 及其依赖归各自作者所有，详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。游戏相关的 AES、映射数据及《影之刃零》名称不归本仓库作者所有，MIT 许可证不授予这些第三方内容的额外权利。
