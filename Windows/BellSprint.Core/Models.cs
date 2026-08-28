using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text.Json.Serialization;

namespace BellSprint.Core;

public abstract class ObservableModel : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;

    protected bool SetField<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return false;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        return true;
    }

    protected void Notify([CallerMemberName] string? propertyName = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
}

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum Weekday
{
    Monday,
    Tuesday,
    Wednesday,
    Thursday,
    Friday,
    Saturday,
    Sunday
}

public static class WeekdayExtensions
{
    public static string DisplayName(this Weekday day) => day switch
    {
        Weekday.Monday => "周一",
        Weekday.Tuesday => "周二",
        Weekday.Wednesday => "周三",
        Weekday.Thursday => "周四",
        Weekday.Friday => "周五",
        Weekday.Saturday => "周六",
        _ => "周日"
    };

    public static Weekday FromSystem(DayOfWeek day) => day switch
    {
        DayOfWeek.Monday => Weekday.Monday,
        DayOfWeek.Tuesday => Weekday.Tuesday,
        DayOfWeek.Wednesday => Weekday.Wednesday,
        DayOfWeek.Thursday => Weekday.Thursday,
        DayOfWeek.Friday => Weekday.Friday,
        DayOfWeek.Saturday => Weekday.Saturday,
        _ => Weekday.Sunday
    };
}

public sealed class BreakConfig : ObservableModel
{
    private bool _isEnabled;
    private int _startHour = 12;
    private int _startMinute;
    private int _duration = 60;

    public bool IsEnabled { get => _isEnabled; set => SetField(ref _isEnabled, value); }
    public int StartHour { get => _startHour; set => SetField(ref _startHour, Math.Clamp(value, 0, 23)); }
    public int StartMinute { get => _startMinute; set => SetField(ref _startMinute, Math.Clamp(value, 0, 59)); }
    public int Duration { get => _duration; set => SetField(ref _duration, Math.Clamp(value, 10, 180)); }

    [JsonIgnore] public int StartMinuteOfDay => StartHour * 60 + StartMinute;
    [JsonIgnore] public int EndMinuteOfDay => StartMinuteOfDay + Duration;
    [JsonIgnore] public string StartText
    {
        get => TimeText.Format(StartMinuteOfDay);
        set { if (TimeText.TryParse(value, out var minutes)) { StartHour = minutes / 60; StartMinute = minutes % 60; Notify(); } }
    }
    [JsonIgnore] public string EndText
    {
        get => TimeText.Format(EndMinuteOfDay);
        set { if (TimeText.TryParse(value, out var minutes) && minutes > StartMinuteOfDay) { Duration = minutes - StartMinuteOfDay; Notify(); } }
    }

    public BreakConfig Clone() => new()
    {
        IsEnabled = IsEnabled,
        StartHour = StartHour,
        StartMinute = StartMinute,
        Duration = Duration
    };
}

public sealed class CourseConfig : ObservableModel
{
    private int _id;
    private string _name = "";
    private int _startHour = 8;
    private int _startMinute;
    private int _endHour = 8;
    private int _endMinute = 45;
    private int _breakDuration = 10;
    private string _preBellText = "";

    public int Id { get => _id; set => SetField(ref _id, value); }
    public string Name { get => _name; set => SetField(ref _name, value ?? ""); }
    public int StartHour { get => _startHour; set => SetField(ref _startHour, Math.Clamp(value, 0, 23)); }
    public int StartMinute { get => _startMinute; set => SetField(ref _startMinute, Math.Clamp(value, 0, 59)); }
    public int EndHour { get => _endHour; set => SetField(ref _endHour, Math.Clamp(value, 0, 23)); }
    public int EndMinute { get => _endMinute; set => SetField(ref _endMinute, Math.Clamp(value, 0, 59)); }
    public int BreakDuration { get => _breakDuration; set => SetField(ref _breakDuration, Math.Clamp(value, 0, 60)); }

    [JsonIgnore] public int StartMinuteOfDay => StartHour * 60 + StartMinute;
    [JsonIgnore] public int EndMinuteOfDay => EndHour * 60 + EndMinute;
    [JsonIgnore] public int Duration
    {
        get => Math.Max(0, EndMinuteOfDay - StartMinuteOfDay);
        set
        {
            var end = StartMinuteOfDay + Math.Clamp(value, 10, 720);
            EndHour = Math.Min(23, end / 60);
            EndMinute = end % 60;
            Notify();
        }
    }
    [JsonIgnore] public string StartText
    {
        get => TimeText.Format(StartMinuteOfDay);
        set { if (TimeText.TryParse(value, out var minutes)) { StartHour = minutes / 60; StartMinute = minutes % 60; Notify(); } }
    }
    [JsonIgnore] public string EndText
    {
        get => TimeText.Format(EndMinuteOfDay);
        set { if (TimeText.TryParse(value, out var minutes)) { EndHour = minutes / 60; EndMinute = minutes % 60; Notify(); Notify(nameof(Duration)); } }
    }
    [JsonIgnore] public string PreBellText { get => _preBellText; set => SetField(ref _preBellText, value); }

    public CourseConfig Clone() => new()
    {
        Id = Id,
        Name = Name,
        StartHour = StartHour,
        StartMinute = StartMinute,
        EndHour = EndHour,
        EndMinute = EndMinute,
        BreakDuration = BreakDuration
    };
}

public sealed class DayConfig : ObservableModel
{
    private Weekday _day;
    private bool _isActive;
    private bool _showCoursesInTray = true;
    private int _startHour = 8;
    private int _startMinute;
    private int _endHour = 21;
    private int _endMinute;
    private int _classDuration = 45;
    private int _breakDuration = 10;
    private int _preBellMinutes = 2;
    private List<CourseConfig> _courses = [];
    private BreakConfig _lunchBreak = new() { IsEnabled = true, StartHour = 12, Duration = 60 };
    private BreakConfig _dinnerBreak = new() { IsEnabled = true, StartHour = 17, StartMinute = 30, Duration = 60 };

    public Weekday Day { get => _day; set { if (SetField(ref _day, value)) Notify(nameof(DisplayName)); } }
    public bool IsActive { get => _isActive; set => SetField(ref _isActive, value); }
    public bool ShowCoursesInTray { get => _showCoursesInTray; set => SetField(ref _showCoursesInTray, value); }
    public int StartHour { get => _startHour; set => SetField(ref _startHour, Math.Clamp(value, 0, 23)); }
    public int StartMinute { get => _startMinute; set => SetField(ref _startMinute, Math.Clamp(value, 0, 59)); }
    public int EndHour { get => _endHour; set => SetField(ref _endHour, Math.Clamp(value, 0, 23)); }
    public int EndMinute { get => _endMinute; set => SetField(ref _endMinute, Math.Clamp(value, 0, 59)); }
    public int ClassDuration { get => _classDuration; set => SetField(ref _classDuration, Math.Clamp(value, 5, 120)); }
    public int BreakDuration { get => _breakDuration; set => SetField(ref _breakDuration, Math.Clamp(value, 0, 60)); }
    public int PreBellMinutes { get => _preBellMinutes; set => SetField(ref _preBellMinutes, Math.Clamp(value, 0, 10)); }
    public List<CourseConfig> Courses { get => _courses; set => SetField(ref _courses, value ?? []); }
    public BreakConfig LunchBreak { get => _lunchBreak; set => SetField(ref _lunchBreak, value ?? new()); }
    public BreakConfig DinnerBreak { get => _dinnerBreak; set => SetField(ref _dinnerBreak, value ?? new()); }

    [JsonIgnore] public string DisplayName => Day.DisplayName();
    [JsonIgnore] public string StartText
    {
        get => TimeText.Format(StartHour * 60 + StartMinute);
        set { if (TimeText.TryParse(value, out var minutes)) { StartHour = minutes / 60; StartMinute = minutes % 60; Notify(); } }
    }
    [JsonIgnore] public string EndText
    {
        get => TimeText.Format(EndHour * 60 + EndMinute);
        set { if (TimeText.TryParse(value, out var minutes)) { EndHour = minutes / 60; EndMinute = minutes % 60; Notify(); } }
    }

    public IReadOnlyList<string> Conflicts()
    {
        var sorted = Courses.OrderBy(c => c.StartMinuteOfDay).ToList();
        var result = new List<string>();
        for (var i = 0; i < sorted.Count; i++)
        for (var j = i + 1; j < sorted.Count; j++)
        {
            if (sorted[j].StartMinuteOfDay >= sorted[i].EndMinuteOfDay) break;
            result.Add($"第{sorted[i].Id}节和第{sorted[j].Id}节时间重叠");
        }
        return result;
    }

    public void ShiftCoursesAfter(int courseId, int deltaMinutes)
    {
        var index = Courses.FindIndex(c => c.Id == courseId);
        if (index < 0 || deltaMinutes == 0) return;
        for (var i = index + 1; i < Courses.Count; i++)
        {
            var start = Courses[i].StartMinuteOfDay + deltaMinutes;
            var end = Courses[i].EndMinuteOfDay + deltaMinutes;
            Courses[i].StartHour = Math.Clamp(start / 60, 0, 23);
            Courses[i].StartMinute = Math.Max(0, start % 60);
            Courses[i].EndHour = Math.Clamp(end / 60, 0, 23);
            Courses[i].EndMinute = Math.Max(0, end % 60);
        }
    }

    public DayConfig Clone() => new()
    {
        Day = Day,
        IsActive = IsActive,
        ShowCoursesInTray = ShowCoursesInTray,
        StartHour = StartHour,
        StartMinute = StartMinute,
        EndHour = EndHour,
        EndMinute = EndMinute,
        ClassDuration = ClassDuration,
        BreakDuration = BreakDuration,
        PreBellMinutes = PreBellMinutes,
        Courses = Courses.Select(c => c.Clone()).ToList(),
        LunchBreak = LunchBreak.Clone(),
        DinnerBreak = DinnerBreak.Clone()
    };
}

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum BellType { Pre, Start, End }

public sealed record BellEvent(string Id, int Hour, int Minute, BellType Type, int ClassNumber)
{
    public int MinuteOfDay => Hour * 60 + Minute;
    public string TimeText => $"{Hour:00}:{Minute:00}";
    public string DisplayType => Type switch { BellType.Pre => "预备铃", BellType.Start => "上课铃", _ => "下课铃" };
}

public sealed class AppSettings
{
    public List<DayConfig> DayConfigs { get; set; } = [];
    public bool IsEnabled { get; set; } = true;
    public bool LaunchAtLogin { get; set; }
    public float Volume { get; set; } = 1;
    public string OutputDeviceName { get; set; } = "";
    public string PreBellPath { get; set; } = "";
    public string StartBellPath { get; set; } = "";
    public string EndBellPath { get; set; } = "";

    public static AppSettings CreateDefault()
    {
        var settings = new AppSettings();
        foreach (var day in Enum.GetValues<Weekday>())
        {
            var config = new DayConfig { Day = day, IsActive = day is >= Weekday.Monday and <= Weekday.Friday };
            config.Courses = ScheduleGenerator.Generate(config);
            settings.DayConfigs.Add(config);
        }
        return settings;
    }
}

public static class TimeText
{
    public static string Format(int minuteOfDay) => $"{Math.Clamp(minuteOfDay / 60, 0, 23):00}:{Math.Abs(minuteOfDay % 60):00}";

    public static bool TryParse(string? text, out int minuteOfDay)
    {
        minuteOfDay = 0;
        if (string.IsNullOrWhiteSpace(text)) return false;
        var parts = text.Split(':');
        if (parts.Length != 2 || !int.TryParse(parts[0], out var hour) || !int.TryParse(parts[1], out var minute)) return false;
        if (hour is < 0 or > 23 || minute is < 0 or > 59) return false;
        minuteOfDay = hour * 60 + minute;
        return true;
    }
}
