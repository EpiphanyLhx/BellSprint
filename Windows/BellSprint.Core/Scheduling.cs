namespace BellSprint.Core;

public static class ScheduleGenerator
{
    public static List<CourseConfig> Generate(DayConfig config)
    {
        var start = config.StartHour * 60 + config.StartMinute;
        var end = config.EndHour * 60 + config.EndMinute;
        var breaks = new[] { config.LunchBreak, config.DinnerBreak }
            .Where(b => b.IsEnabled)
            .Select(b => (Start: b.StartMinuteOfDay, End: b.EndMinuteOfDay))
            .OrderBy(b => b.Start)
            .ToList();
        var courses = new List<CourseConfig>();
        var current = start;
        var id = 1;

        while (current + config.ClassDuration <= end)
        {
            var moved = true;
            while (moved)
            {
                moved = false;
                foreach (var pause in breaks)
                {
                    if ((current >= pause.Start && current < pause.End) ||
                        (current < pause.Start && current + config.ClassDuration > pause.Start))
                    {
                        current = pause.End;
                        moved = true;
                        break;
                    }
                }
            }

            var courseEnd = current + config.ClassDuration;
            if (courseEnd > end) break;
            courses.Add(new CourseConfig
            {
                Id = id++,
                StartHour = current / 60,
                StartMinute = current % 60,
                EndHour = courseEnd / 60,
                EndMinute = courseEnd % 60,
                BreakDuration = config.BreakDuration
            });
            current = courseEnd + config.BreakDuration;
        }
        return courses;
    }
}

public static class BellScheduler
{
    public static IReadOnlyList<BellEvent> GenerateEvents(DayConfig config)
    {
        if (!config.IsActive) return [];
        var events = new List<BellEvent>();
        foreach (var course in config.Courses)
        {
            if (config.PreBellMinutes > 0)
            {
                var pre = course.StartMinuteOfDay - config.PreBellMinutes;
                if (pre >= 0)
                    events.Add(new BellEvent($"{config.Day}-{course.Id}-pre", pre / 60, pre % 60, BellType.Pre, course.Id));
            }
            events.Add(new BellEvent($"{config.Day}-{course.Id}-start", course.StartHour, course.StartMinute, BellType.Start, course.Id));
            events.Add(new BellEvent($"{config.Day}-{course.Id}-end", course.EndHour, course.EndMinute, BellType.End, course.Id));
        }
        return events.OrderBy(e => e.MinuteOfDay).ToList();
    }

    public static DayConfig? TodayConfig(IEnumerable<DayConfig> configs, DateTime now) =>
        configs.FirstOrDefault(c => c.Day == WeekdayExtensions.FromSystem(now.DayOfWeek) && c.IsActive);

    public static IReadOnlyList<BellEvent> EventsForToday(IEnumerable<DayConfig> configs, DateTime now) =>
        TodayConfig(configs, now) is { } config ? GenerateEvents(config) : [];

    public static BellEvent? NextEvent(IEnumerable<DayConfig> configs, DateTime now)
    {
        var minute = now.Hour * 60 + now.Minute;
        return EventsForToday(configs, now).FirstOrDefault(e => e.MinuteOfDay >= minute);
    }

    public static CourseConfig? CurrentCourse(IEnumerable<DayConfig> configs, DateTime now)
    {
        var minute = now.Hour * 60 + now.Minute;
        return TodayConfig(configs, now)?.Courses.FirstOrDefault(c => minute >= c.StartMinuteOfDay && minute < c.EndMinuteOfDay);
    }
}
