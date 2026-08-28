using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;
using BellSprint.Core;

namespace BellSprint.Windows;

public partial class MainWindow : Window
{
    private readonly AppController _controller;
    private DayConfig? _selectedDay;
    private ObservableCollection<CourseConfig> _courses = [];
    private Dictionary<int, (int End, int Break)> _snapshots = [];
    private bool _loading;
    private bool _allowClose;

    public MainWindow(AppController controller)
    {
        InitializeComponent();
        _controller = controller;
        LaunchAtLoginCheck.IsChecked = controller.Settings.LaunchAtLogin;
        DaysList.ItemsSource = controller.Settings.DayConfigs.OrderBy(c => c.Day);
        DaysList.SelectedIndex = 0;
    }

    protected override void OnClosing(CancelEventArgs e)
    {
        if (_allowClose) return;
        e.Cancel = true;
        Hide();
        _controller.Save();
    }

    public void CloseForExit()
    {
        _allowClose = true;
        Close();
    }

    private void DaysList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (DaysList.SelectedItem is not DayConfig config) return;
        CommitGrid();
        _selectedDay = config;
        DayTitle.Text = config.DisplayName;
        DataContext = config;
        ReloadCourses();
    }

    private void ReloadCourses()
    {
        if (_selectedDay is null) return;
        _loading = true;
        UpdatePreBellTexts();
        _courses = new ObservableCollection<CourseConfig>(_selectedDay.Courses);
        CoursesGrid.ItemsSource = _courses;
        GlobalDurationBox.Text = (_courses.FirstOrDefault()?.Duration ?? _selectedDay.ClassDuration).ToString();
        RefreshSnapshots();
        RefreshConflicts();
        _loading = false;
    }

    private void CommitGrid()
    {
        CoursesGrid.CommitEdit(DataGridEditingUnit.Cell, true);
        CoursesGrid.CommitEdit(DataGridEditingUnit.Row, true);
        if (_selectedDay is not null) _selectedDay.Courses = _courses.ToList();
    }

    private void SettingsControl_Changed(object sender, RoutedEventArgs e)
    {
        if (_loading) return;
        _controller.Settings.LaunchAtLogin = LaunchAtLoginCheck.IsChecked == true;
        Save();
    }

    private void ScheduleSetting_Changed(object sender, RoutedEventArgs e)
    {
        if (_loading) return;
        GenerateCourses();
    }

    private void ScheduleSetting_LostFocus(object sender, RoutedEventArgs e) => GenerateCourses();
    private void SaveOnly_LostFocus(object sender, RoutedEventArgs e) { UpdatePreBellTexts(); ReloadCourses(); Save(); }

    private void Generate_Click(object sender, RoutedEventArgs e) => GenerateCourses();

    private void GenerateCourses()
    {
        if (_selectedDay is null || _loading) return;
        CommitGrid();
        _selectedDay.Courses = ScheduleGenerator.Generate(_selectedDay);
        ReloadCourses();
        Save();
    }

    private void AddCourse_Click(object sender, RoutedEventArgs e)
    {
        if (_selectedDay is null) return;
        CommitGrid();
        var last = _selectedDay.Courses.LastOrDefault();
        var start = last is null
            ? _selectedDay.StartHour * 60 + _selectedDay.StartMinute
            : last.EndMinuteOfDay + last.BreakDuration;
        var duration = int.TryParse(GlobalDurationBox.Text, out var parsed) ? Math.Clamp(parsed, 10, 120) : _selectedDay.ClassDuration;
        var end = start + duration;
        _selectedDay.Courses.Add(new CourseConfig
        {
            Id = (_selectedDay.Courses.MaxBy(c => c.Id)?.Id ?? 0) + 1,
            StartHour = start / 60,
            StartMinute = start % 60,
            EndHour = Math.Min(23, end / 60),
            EndMinute = end % 60,
            BreakDuration = _selectedDay.BreakDuration
        });
        ReloadCourses();
        Save();
    }

    private void DeleteCourse_Click(object sender, RoutedEventArgs e)
    {
        if (_selectedDay is null || CoursesGrid.SelectedItem is not CourseConfig selected) return;
        _selectedDay.Courses.RemoveAll(c => c.Id == selected.Id);
        ReloadCourses();
        Save();
    }

    private void ApplyGlobalDuration_Click(object sender, RoutedEventArgs e)
    {
        if (_selectedDay is null || !int.TryParse(GlobalDurationBox.Text, out var duration)) return;
        duration = Math.Clamp(duration, 10, 120);
        CommitGrid();
        foreach (var course in _selectedDay.Courses.OrderBy(c => c.Id).ToList())
        {
            var oldEnd = course.EndMinuteOfDay;
            course.Duration = duration;
            _selectedDay.ShiftCoursesAfter(course.Id, course.EndMinuteOfDay - oldEnd);
        }
        ReloadCourses();
        Save();
    }

    private void CoursesGrid_CellEditEnding(object sender, DataGridCellEditEndingEventArgs e)
    {
        if (_loading || _selectedDay is null || e.Row.Item is not CourseConfig course) return;
        Dispatcher.BeginInvoke(() =>
        {
            CommitGrid();
            if (!_snapshots.TryGetValue(course.Id, out var old)) old = (course.EndMinuteOfDay, course.BreakDuration);
            var delta = (course.EndMinuteOfDay - old.End) + (course.BreakDuration - old.Break);
            if (delta != 0) _selectedDay.ShiftCoursesAfter(course.Id, delta);
            UpdatePreBellTexts();
            ReloadCourses();
            Save();
        }, DispatcherPriority.Background);
    }

    private void UpdatePreBellTexts()
    {
        if (_selectedDay is null) return;
        foreach (var course in _selectedDay.Courses)
        {
            var minute = course.StartMinuteOfDay - _selectedDay.PreBellMinutes;
            course.PreBellText = _selectedDay.PreBellMinutes > 0 && minute >= 0 ? TimeText.Format(minute) : "—";
        }
    }

    private void RefreshSnapshots()
    {
        _snapshots = _courses.ToDictionary(c => c.Id, c => (c.EndMinuteOfDay, c.BreakDuration));
    }

    private void RefreshConflicts()
    {
        if (_selectedDay is null) return;
        ConflictText.Text = string.Join("；", _selectedDay.Conflicts());
    }

    private void Sync_Click(object sender, RoutedEventArgs e)
    {
        if (_selectedDay is null) return;
        CommitGrid();
        var dialog = new SyncWindow(_selectedDay, _controller.Settings.DayConfigs) { Owner = this };
        if (dialog.ShowDialog() == true) Save();
    }

    private void SoundSettings_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new SoundSettingsWindow(_controller) { Owner = this };
        dialog.ShowDialog();
        Save();
    }

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        CommitGrid();
        Save();
    }

    private void Save()
    {
        CommitGrid();
        _controller.Save();
        RefreshConflicts();
    }
}
