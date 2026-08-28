using BellSprint.Core;
using NAudio.CoreAudioApi;
using NAudio.Wave;
using System.IO;

namespace BellSprint.Windows.Services;

public sealed class AudioService : IDisposable
{
    private readonly AppSettings _settings;
    private readonly List<IDisposable> _players = [];

    public AudioService(AppSettings settings) => _settings = settings;

    public IReadOnlyList<string> GetOutputDevices()
    {
        try
        {
            using var enumerator = new MMDeviceEnumerator();
            return enumerator.EnumerateAudioEndPoints(DataFlow.Render, DeviceState.Active)
                .Select(d => d.FriendlyName).Distinct().Order().ToList();
        }
        catch { return []; }
    }

    public void Play(BellType type)
    {
        var path = type switch
        {
            BellType.Pre => _settings.PreBellPath,
            BellType.Start => _settings.StartBellPath,
            _ => _settings.EndBellPath
        };
        if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
        {
            var file = type switch { BellType.Pre => "pre_bell.wav", BellType.Start => "start_bell.wav", _ => "end_bell.wav" };
            path = Path.Combine(AppContext.BaseDirectory, "Assets", file);
        }
        if (!File.Exists(path)) return;

        try
        {
            var reader = new AudioFileReader(path) { Volume = Math.Clamp(_settings.Volume, 0, 1) };
            IWavePlayer output;
            var device = FindDevice(_settings.OutputDeviceName);
            output = device is null
                ? new WaveOutEvent()
                : new WasapiOut(device, AudioClientShareMode.Shared, false, 100);
            var session = new PlaybackSession(output, reader, RemoveSession);
            _players.Add(session);
            session.Start();
        }
        catch { System.Media.SystemSounds.Beep.Play(); }
    }

    private MMDevice? FindDevice(string name)
    {
        if (string.IsNullOrWhiteSpace(name)) return null;
        try
        {
            using var enumerator = new MMDeviceEnumerator();
            return enumerator.EnumerateAudioEndPoints(DataFlow.Render, DeviceState.Active)
                .FirstOrDefault(d => d.FriendlyName == name);
        }
        catch { return null; }
    }

    private void RemoveSession(IDisposable session)
    {
        _players.Remove(session);
        session.Dispose();
    }

    public void Dispose()
    {
        foreach (var player in _players.ToArray()) player.Dispose();
        _players.Clear();
    }

    private sealed class PlaybackSession : IDisposable
    {
        private readonly IWavePlayer _output;
        private readonly AudioFileReader _reader;
        private readonly Action<IDisposable> _finished;

        public PlaybackSession(IWavePlayer output, AudioFileReader reader, Action<IDisposable> finished)
        {
            _output = output;
            _reader = reader;
            _finished = finished;
            _output.PlaybackStopped += OnStopped;
        }

        public void Start() { _output.Init(_reader); _output.Play(); }
        private void OnStopped(object? sender, StoppedEventArgs e) => _finished(this);
        public void Dispose()
        {
            _output.PlaybackStopped -= OnStopped;
            _output.Dispose();
            _reader.Dispose();
        }
    }
}
