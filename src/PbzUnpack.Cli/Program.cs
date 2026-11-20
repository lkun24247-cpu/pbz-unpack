using System.Text.RegularExpressions;
using CUE4Parse.Compression;
using CUE4Parse.Encryption.Aes;
using CUE4Parse.FileProvider;
using CUE4Parse.MappingsProvider.Usmap;
using CUE4Parse.UE4.Assets.Exports.Animation;
using CUE4Parse.UE4.Assets.Exports.SkeletalMesh;
using CUE4Parse.UE4.Assets.Exports.StaticMesh;
using CUE4Parse.UE4.Objects.Core.Misc;
using CUE4Parse.UE4.Versions;
using CUE4Parse_Conversion;
using CUE4Parse_Conversion.Options;
using Newtonsoft.Json;

if (args.Length == 0 || args[0] is "help" or "--help" or "-h")
{
    PrintUsage();
    return 0;
}

var command = args[0].ToLowerInvariant();
if (command is not ("list" or "inspect" or "export"))
{
    Console.Error.WriteLine($"Unknown command: {command}");
    PrintUsage();
    return 2;
}

try
{
    var paks = ResolveRequiredPath("--paks", "PBZ_PAK_DIR");
    var mappings = ResolveRequiredPath("--usmap", "PBZ_USMAP");
    var aesKey = ResolveRequiredSetting("--aes-key", "PBZ_AES_KEY");

    if (!Directory.Exists(paks))
    {
        throw new DirectoryNotFoundException($"Pak directory not found: {paks}");
    }

    if (!File.Exists(mappings))
    {
        throw new FileNotFoundException("Mapping file not found.", mappings);
    }

    await ZlibHelper.InitializeAsync();
    await OodleHelper.InitializeAsync();

    using var provider = new DefaultFileProvider(
        paks,
        SearchOption.TopDirectoryOnly,
        new VersionContainer(EGame.GAME_UE5_7),
        StringComparer.OrdinalIgnoreCase
    );
    provider.MappingsContainer = new FileUsmapTypeMappingsProvider(mappings);
    provider.Initialize();
    provider.SubmitKey(new FGuid(), new FAesKey(aesKey));
    provider.PostMount();

    var allPaths = provider.Files.Values
        .Select(file => file.Path)
        .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
        .ToArray();

    Console.Error.WriteLine($"INDEXED {allPaths.Length} package paths");

    if (command == "list")
    {
        IEnumerable<string> selected = allPaths;
        var contains = GetOption("--contains");
        var regex = GetOption("--regex");

        if (!string.IsNullOrWhiteSpace(contains))
        {
            selected = selected.Where(
                path => path.Contains(contains, StringComparison.OrdinalIgnoreCase)
            );
        }

        if (!string.IsNullOrWhiteSpace(regex))
        {
            var expression = new Regex(
                regex,
                RegexOptions.IgnoreCase | RegexOptions.CultureInvariant,
                TimeSpan.FromSeconds(5)
            );
            selected = selected.Where(path => expression.IsMatch(path));
        }

        var matches = selected.ToArray();
        var limit = GetIntOption("--limit", 200);
        foreach (var path in matches.Take(limit))
        {
            Console.WriteLine(path);
        }

        Console.WriteLine($"COUNT {matches.Length}");
        if (matches.Length > limit)
        {
            Console.WriteLine($"TRUNCATED {matches.Length - limit}");
        }

        return 0;
    }

    var assetPath = ResolveRequiredSetting("--path", "PBZ_ASSET_PATH");
    var matchesForAsset = FindAsset(allPaths, assetPath);
    if (matchesForAsset.Length == 0)
    {
        Console.Error.WriteLine($"ASSET_NOT_FOUND {assetPath}");
        return 3;
    }

    if (matchesForAsset.Length > 1 && !HasFlag("--all"))
    {
        Console.Error.WriteLine($"ASSET_AMBIGUOUS {assetPath}");
        foreach (var path in matchesForAsset.Take(30))
        {
            Console.Error.WriteLine($"  {path}");
        }
        Console.Error.WriteLine("Pass a longer --path or add --all.");
        return 4;
    }

    if (command == "inspect")
    {
        var jsonDirectory = GetOption("--json-dir");
        if (!string.IsNullOrWhiteSpace(jsonDirectory))
        {
            jsonDirectory = ResolvePath(jsonDirectory);
        }
        foreach (var path in matchesForAsset)
        {
            Console.WriteLine($"PACKAGE {path}");
            var package = provider.LoadPackage(path);
            foreach (var export in package.GetExports())
            {
                Console.WriteLine($"EXPORT {export.ExportType} {export.Name}");
                if (!string.IsNullOrWhiteSpace(jsonDirectory))
                {
                    Directory.CreateDirectory(jsonDirectory);
                    var jsonName =
                        Path.GetFileNameWithoutExtension(path) + $".{export.Name}.json";
                    var jsonPath = Path.Combine(jsonDirectory, jsonName);
                    await File.WriteAllTextAsync(
                        jsonPath,
                        JsonConvert.SerializeObject(export, Formatting.Indented)
                    );
                    Console.WriteLine($"JSON {jsonPath}");
                }
            }
        }

        return 0;
    }

    var outputDirectory = ResolveRequiredPath("--out", "PBZ_EXPORT_DIR");
    var format = (GetOption("--format") ?? "auto").ToLowerInvariant();
    var exportMaterials = HasFlag("--materials");
    Directory.CreateDirectory(outputDirectory);
    var exportedAny = false;

    foreach (var path in matchesForAsset)
    {
        Console.WriteLine($"PACKAGE {path}");
        var package = provider.LoadPackage(path);
        foreach (var export in package.GetExports())
        {
            var isMesh = export is USkeletalMesh or UStaticMesh;
            var isAnimation = export is UAnimationAsset;
            if (!isMesh && !isAnimation)
            {
                Console.WriteLine($"SKIP {export.ExportType} {export.Name}");
                continue;
            }

            var meshFormat = format switch
            {
                "gltf" => EMeshFormat.Gltf2,
                "actorx" or "psk" or "psa" => EMeshFormat.ActorX,
                "auto" when isMesh && !isAnimation => EMeshFormat.Gltf2,
                "auto" => EMeshFormat.ActorX,
                _ => throw new ArgumentException($"Unsupported format: {format}"),
            };

            var session = new ExportSession();
            session.Add(export);
            var results = await session.RunAsync(
                outputDirectory,
                new ExportOptions(
                    meshFormat: meshFormat,
                    exportMaterials: exportMaterials && meshFormat == EMeshFormat.Gltf2,
                    textureFormat: ETextureFormat.Png
                )
            );
            foreach (var result in results)
            {
                exportedAny |= result.Success;
                Console.WriteLine(
                    $"EXPORTED {export.Name} success={result.Success} "
                    + $"files={string.Join(";", result.DiskFilePaths ?? [])} "
                    + $"error={result.Error?.Message}"
                );
            }
        }
    }

    return exportedAny ? 0 : 5;
}
catch (Exception exception)
{
    Console.Error.WriteLine($"{exception.GetType().Name}: {exception.Message}");
    return 1;
}

string? GetOption(string name)
{
    for (var index = 1; index < args.Length - 1; index++)
    {
        if (args[index].Equals(name, StringComparison.OrdinalIgnoreCase))
        {
            return args[index + 1];
        }
    }

    return null;
}

bool HasFlag(string name) =>
    args.Skip(1).Any(value => value.Equals(name, StringComparison.OrdinalIgnoreCase));

int GetIntOption(string name, int fallback)
{
    var value = GetOption(name);
    if (value is null)
    {
        return fallback;
    }

    if (!int.TryParse(value, out var parsed) || parsed <= 0)
    {
        throw new ArgumentException($"{name} must be a positive integer.");
    }

    return parsed;
}

string ResolveRequiredPath(string optionName, string environmentName)
{
    var value = ResolveRequiredSetting(optionName, environmentName);
    return ResolvePath(value);
}

string ResolvePath(string value)
{
    var callerDirectory = Environment.GetEnvironmentVariable("PBZ_CALLER_DIR");
    if (
        !Path.IsPathRooted(value)
        && !string.IsNullOrWhiteSpace(callerDirectory)
        && Directory.Exists(callerDirectory)
    )
    {
        return Path.GetFullPath(value, callerDirectory);
    }

    return Path.GetFullPath(value);
}

string ResolveRequiredSetting(string optionName, string environmentName)
{
    var option = GetOption(optionName);
    if (!string.IsNullOrWhiteSpace(option))
    {
        return option;
    }

    var environment = Environment.GetEnvironmentVariable(environmentName);
    if (!string.IsNullOrWhiteSpace(environment))
    {
        return environment;
    }

    throw new ArgumentException(
        $"Missing {optionName}. Set it explicitly or define {environmentName}."
    );
}

static string[] FindAsset(string[] allPaths, string query)
{
    var normalized = query.Replace('\\', '/').TrimStart('/');
    return allPaths.Where(
        path =>
            path.Equals(normalized, StringComparison.OrdinalIgnoreCase)
            || path.EndsWith("/" + normalized, StringComparison.OrdinalIgnoreCase)
            || path.EndsWith("/" + normalized + ".uasset", StringComparison.OrdinalIgnoreCase)
            || path.EndsWith("/" + normalized + ".umap", StringComparison.OrdinalIgnoreCase)
    ).ToArray();
}

static void PrintUsage()
{
    Console.WriteLine(
        """
        pbz-unpack-cli - Phantom Blade Zero UE5.7 asset inspection and export

        Common options:
          --paks PATH       Paks directory (env PBZ_PAK_DIR)
          --usmap PATH      .usmap mappings file (env PBZ_USMAP)
          --aes-key HEX     AES key (env PBZ_AES_KEY)

        list:
          pbz-unpack-cli list [--contains TEXT] [--regex PATTERN] [--limit N]

        inspect:
          pbz-unpack-cli inspect --path ASSET [--json-dir DIR] [--all]

        export:
          pbz-unpack-cli export --path ASSET --out DIR
                                [--format auto|gltf|actorx|psk|psa]
                                [--materials] [--all]

        ASSET may be a full package path or an unambiguous suffix.
        """.Trim()
    );
}
