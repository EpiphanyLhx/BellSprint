using System.Text.Json;
using System.Text.Json.Serialization;
using System.IO;
using BellSprint.Core;

namespace BellSprint.Windows.Services;

public sealed class SettingsStore
{
    public string AppDirectory { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "BellSprint");
    public string SoundsDirectory => Path.Combine(AppDirectory, "Sounds");
    private string SettingsPath => Path.Combine(AppDirectory, "settings.json");

    private readonly JsonSerializerOptions _options = new()
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() }
    };

    public AppSettings Load()
    {
        try
        {
            if (File.Exists(SettingsPath))
            {
                var settings = JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(SettingsPath), _options);
                if (settings is not null && settings.DayConfigs.Count == 7) return settings;
            }
        }
        catch { }
        return AppSettings.CreateDefault();
    }

    public void Save(AppSettings settings)
    {
        Directory.CreateDirectory(AppDirectory);
        File.WriteAllText(SettingsPath, JsonSerializer.Serialize(settings, _options));
    }

    public string ImportSound(string sourcePath, BellType type)
    {
        Directory.CreateDirectory(SoundsDirectory);
        var extension = Path.GetExtension(sourcePath);
        var destination = Path.Combine(SoundsDirectory, $"{type.ToString().ToLowerInvariant()}{extension}");
        File.Copy(sourcePath, destination, true);
        return destination;
    }
}
