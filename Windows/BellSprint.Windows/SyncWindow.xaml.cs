using System.Windows;
using System.Windows.Controls;
using BellSprint.Core;

namespace BellSprint.Windows;

public partial class SyncWindow : Window
{
    private readonly DayConfig _source;
    private readonly List<DayConfig> _configs;
    private readonly List<TargetDay> _targets;

    public SyncWindow(DayConfig source, List<DayConfig> configs)
    {
        InitializeComponent();
        _source = source;
        _configs = configs;
        TitleText.Text = $"将「{source.DisplayName}」同步到：";
        _targets = configs.Where(c => c.Day != source.Day)
            .Select(c => new TargetDay { Day = c.Day, Name = $"{c.DisplayName}  ({(c.IsActive ? $"{c.Courses.Count}节" : "未启用")})" })
            .ToList();
        TargetsList.ItemsSource = _targets;
    }

    private void Sync_Click(object sender, RoutedEventArgs e)
    {
        var selected = _targets.Where(t => t.Selected).ToList();
        if (selected.Count == 0) { System.Windows.MessageBox.Show("请至少选择一天。"); return; }
        var mode = ((ComboBoxItem)ModeBox.SelectedItem).Tag?.ToString();
        foreach (var target in selected)
        {
            var index = _configs.FindIndex(c => c.Day == target.Day);
            if (index < 0) continue;
            var current = _configs[index];
            if (mode == "All")
            {
                var copy = _source.Clone();
                current.IsActive = copy.IsActive;
                current.ShowCoursesInTray = copy.ShowCoursesInTray;
                current.StartHour = copy.StartHour; current.StartMinute = copy.StartMinute;
                current.EndHour = copy.EndHour; current.EndMinute = copy.EndMinute;
                current.ClassDuration = copy.ClassDuration; current.BreakDuration = copy.BreakDuration;
                current.PreBellMinutes = copy.PreBellMinutes;
                current.Courses = copy.Courses;
                current.LunchBreak = copy.LunchBreak; current.DinnerBreak = copy.DinnerBreak;
            }
            else if (mode == "Time")
            {
                current.IsActive = _source.IsActive;
                current.ShowCoursesInTray = _source.ShowCoursesInTray;
                current.StartHour = _source.StartHour; current.StartMinute = _source.StartMinute;
                current.EndHour = _source.EndHour; current.EndMinute = _source.EndMinute;
                current.ClassDuration = _source.ClassDuration; current.BreakDuration = _source.BreakDuration;
                current.PreBellMinutes = _source.PreBellMinutes;
                current.LunchBreak = _source.LunchBreak.Clone(); current.DinnerBreak = _source.DinnerBreak.Clone();
                current.Courses = ScheduleGenerator.Generate(current);
            }
            else
            {
                current.Courses = _source.Courses.Select(c => c.Clone()).ToList();
            }
        }
        DialogResult = true;
    }

    private sealed class TargetDay
    {
        public Weekday Day { get; init; }
        public string Name { get; init; } = "";
        public bool Selected { get; set; }
    }
}
