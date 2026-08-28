using System.Windows;
using System.Windows.Controls;
using BellSprint.Core;
using System.IO;

namespace BellSprint.Windows;

public partial class SoundSettingsWindow : Window
{
    private readonly AppController _controller;
    private bool _loading = true;

    public SoundSettingsWindow(AppController controller)
    {
        InitializeComponent();
        _controller = controller;
        VolumeSlider.Value = controller.Settings.Volume * 100;
        LoadPaths();
        RefreshDevices();
        _loading = false;
        UpdateVolumeText();
    }

    private void VolumeSlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        UpdateVolumeText();
        if (_loading) return;
        _controller.Settings.Volume = (float)(VolumeSlider.Value / 100);
        _controller.Save();
    }

    private void UpdateVolumeText()
    {
        if (VolumeText is not null) VolumeText.Text = $"{VolumeSlider.Value:0}%";
    }

    private void RefreshDevices_Click(object sender, RoutedEventArgs e) => RefreshDevices();

    private void RefreshDevices()
    {
        _loading = true;
        var devices = new List<string> { "系统默认设备" };
        devices.AddRange(_controller.Audio.GetOutputDevices());
        DevicesBox.ItemsSource = devices;
        DevicesBox.SelectedItem = string.IsNullOrWhiteSpace(_controller.Settings.OutputDeviceName)
            ? devices[0]
            : devices.FirstOrDefault(d => d == _controller.Settings.OutputDeviceName) ?? devices[0];
        _loading = false;
    }

    private void DevicesBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_loading || DevicesBox.SelectedItem is not string selected) return;
        _controller.Settings.OutputDeviceName = selected == "系统默认设备" ? "" : selected;
        _controller.Save();
    }

    private void SelectPre_Click(object sender, RoutedEventArgs e) => SelectSound(BellType.Pre);
    private void SelectStart_Click(object sender, RoutedEventArgs e) => SelectSound(BellType.Start);
    private void SelectEnd_Click(object sender, RoutedEventArgs e) => SelectSound(BellType.End);
    private void ClearPre_Click(object sender, RoutedEventArgs e) => ClearSound(BellType.Pre);
    private void ClearStart_Click(object sender, RoutedEventArgs e) => ClearSound(BellType.Start);
    private void ClearEnd_Click(object sender, RoutedEventArgs e) => ClearSound(BellType.End);

    private void SelectSound(BellType type)
    {
        var dialog = new Microsoft.Win32.OpenFileDialog
        {
            Filter = "音频文件|*.wav;*.mp3;*.m4a;*.aiff;*.aif|所有文件|*.*",
            Multiselect = false
        };
        if (dialog.ShowDialog(this) != true) return;
        var path = _controller.Store.ImportSound(dialog.FileName, type);
        SetPath(type, path);
        LoadPaths();
        _controller.Save();
    }

    private void ClearSound(BellType type)
    {
        SetPath(type, "");
        LoadPaths();
        _controller.Save();
    }

    private void SetPath(BellType type, string path)
    {
        if (type == BellType.Pre) _controller.Settings.PreBellPath = path;
        else if (type == BellType.Start) _controller.Settings.StartBellPath = path;
        else _controller.Settings.EndBellPath = path;
    }

    private void LoadPaths()
    {
        PrePathBox.Text = DisplayPath(_controller.Settings.PreBellPath);
        StartPathBox.Text = DisplayPath(_controller.Settings.StartBellPath);
        EndPathBox.Text = DisplayPath(_controller.Settings.EndBellPath);
    }

    private static string DisplayPath(string path) => string.IsNullOrWhiteSpace(path) ? "默认铃声" : Path.GetFileName(path);
    private void TestPre_Click(object sender, RoutedEventArgs e) => _controller.Audio.Play(BellType.Pre);
    private void TestStart_Click(object sender, RoutedEventArgs e) => _controller.Audio.Play(BellType.Start);
    private void TestEnd_Click(object sender, RoutedEventArgs e) => _controller.Audio.Play(BellType.End);
    private void Close_Click(object sender, RoutedEventArgs e) { _controller.Save(); Close(); }
}
