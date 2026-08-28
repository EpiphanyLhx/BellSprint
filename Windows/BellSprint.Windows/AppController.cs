using System.Drawing;
using System.Windows;
using System.Windows.Threading;
using BellSprint.Core;
using BellSprint.Windows.Services;
using Forms = System.Windows.Forms;

namespace BellSprint.Windows;

public sealed class AppController : IDisposable
{
    private readonly SettingsStore _store = new();
    private readonly DispatcherTimer _timer = new() { Interval = TimeSpan.FromSeconds(2) };
    private readonly HashSet<string> _rungEvents = [];
    private readonly Forms.NotifyIcon _trayIcon;
    private readonly Forms.ContextMenuStrip _trayMenu = new();
    private MainWindow? _window;
    private DateOnly _lastDate = DateOnly.FromDateTime(DateTime.Now);
    private int _lastMinute = -1;

    public AppSettings Settings { get; }
    public AudioService Audio { get; }
    public SettingsStore Store => _store;

    public AppController()
    {
        Settings = _store.Load();
        Settings.LaunchAtLogin = StartupService.IsEnabled();
        Audio = new AudioService(Settings);
        _trayIcon = new Forms.NotifyIcon
        {
            Text = "BellSprint 上下课铃声",
            Icon = Icon.ExtractAssociatedIcon(Environment.ProcessPath ?? "") ?? SystemIcons.Application,
            Visible = true,
            ContextMenuStrip = _trayMenu
        };
        _trayIcon.DoubleClick += (_, _) => ShowSettings();
        _trayMenu.Opening += (_, _) => RebuildTrayMenu();
        _timer.Tick += (_, _) => Tick();
    }

    public void Start()
    {
        RebuildTrayMenu();
        _timer.Start();
    }

    public void Save()
    {
        StartupService.SetEnabled(Settings.LaunchAtLogin);
        _store.Save(Settings);
        RebuildTrayMenu();
    }

    public void ShowSettings()
    {
        if (_window is null)
        {
            _window = new MainWindow(this);
            _window.Closed += (_, _) => _window = null;
        }
        _window.Show();
        if (_window.WindowState == WindowState.Minimized) _window.WindowState = WindowState.Normal;
        _window.Activate();
    }

    public void Exit()
    {
        Save();
        _trayIcon.Visible = false;
        _window?.CloseForExit();
        System.Windows.Application.Current.Shutdown();
    }

    private void Tick()
    {
        var now = DateTime.Now;
        if (_lastDate != DateOnly.FromDateTime(now))
        {
            _lastDate = DateOnly.FromDateTime(now);
            _rungEvents.Clear();
        }

        var minute = now.Hour * 60 + now.Minute;
        if (_lastMinute != minute)
        {
            _lastMinute = minute;
            RebuildTrayMenu();
        }
        if (!Settings.IsEnabled) return;

        var due = BellScheduler.EventsForToday(Settings.DayConfigs, now)
            .FirstOrDefault(e => e.Hour == now.Hour && e.Minute == now.Minute && !_rungEvents.Contains(e.Id));
        if (due is null) return;
        _rungEvents.Add(due.Id);
        Audio.Play(due.Type);
    }

    private void RebuildTrayMenu()
    {
        _trayMenu.Items.Clear();
        var now = DateTime.Now;
        var next = BellScheduler.NextEvent(Settings.DayConfigs, now);
        var current = BellScheduler.CurrentCourse(Settings.DayConfigs, now);
        var today = BellScheduler.TodayConfig(Settings.DayConfigs, now);

        var status = new Forms.ToolStripMenuItem(Settings.IsEnabled ? "● 铃声已启用" : "○ 铃声已暂停") { Enabled = false };
        _trayMenu.Items.Add(status);
        _trayMenu.Items.Add(new Forms.ToolStripMenuItem(
            next is null ? "下一个：今日无课 / 已结束" : $"下一个：{next.TimeText} {next.DisplayType}") { Enabled = false });
        if (current is not null)
            _trayMenu.Items.Add(new Forms.ToolStripMenuItem($"当前：第{current.Id}节 {DisplayCourseName(current)}") { Enabled = false });

        if (today?.ShowCoursesInTray == true && today.Courses.Count > 0)
        {
            _trayMenu.Items.Add(new Forms.ToolStripSeparator());
            foreach (var course in today.Courses)
            {
                var marker = current?.Id == course.Id ? "▶" : " ";
                _trayMenu.Items.Add(new Forms.ToolStripMenuItem(
                    $"{marker} {course.StartText}-{course.EndText}  {DisplayCourseName(course)}") { Enabled = false });
            }
        }

        _trayMenu.Items.Add(new Forms.ToolStripSeparator());
        var toggle = new Forms.ToolStripMenuItem(Settings.IsEnabled ? "暂停铃声" : "恢复铃声");
        toggle.Click += (_, _) => { Settings.IsEnabled = !Settings.IsEnabled; if (Settings.IsEnabled) _rungEvents.Clear(); Save(); };
        _trayMenu.Items.Add(toggle);
        var test = new Forms.ToolStripMenuItem("测试上课铃");
        test.Click += (_, _) => Audio.Play(BellType.Start);
        _trayMenu.Items.Add(test);
        var open = new Forms.ToolStripMenuItem("打开设置");
        open.Click += (_, _) => ShowSettings();
        _trayMenu.Items.Add(open);
        var startup = new Forms.ToolStripMenuItem("开机自启动") { Checked = Settings.LaunchAtLogin, CheckOnClick = true };
        startup.CheckedChanged += (_, _) => { Settings.LaunchAtLogin = startup.Checked; Save(); };
        _trayMenu.Items.Add(startup);
        _trayMenu.Items.Add(new Forms.ToolStripSeparator());
        var exit = new Forms.ToolStripMenuItem("退出");
        exit.Click += (_, _) => Exit();
        _trayMenu.Items.Add(exit);
    }

    private static string DisplayCourseName(CourseConfig course) =>
        string.IsNullOrWhiteSpace(course.Name) ? "未设置" : course.Name;

    public void Dispose()
    {
        _timer.Stop();
        Audio.Dispose();
        _trayIcon.Dispose();
        _trayMenu.Dispose();
    }
}
