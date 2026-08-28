using BellSprint.Core;
using Xunit;

namespace BellSprint.Core.Tests;

public sealed class SchedulingTests
{
    [Fact]
    public void Generate_skips_lunch_and_dinner_breaks()
    {
        var config = new DayConfig
        {
            Day = Weekday.Monday,
            IsActive = true,
            StartHour = 8,
            EndHour = 20,
            ClassDuration = 45,
            BreakDuration = 10,
            LunchBreak = new BreakConfig { IsEnabled = true, StartHour = 12, Duration = 60 },
            DinnerBreak = new BreakConfig { IsEnabled = true, StartHour = 17, StartMinute = 30, Duration = 60 }
        };

        var courses = ScheduleGenerator.Generate(config);

        Assert.NotEmpty(courses);
        Assert.DoesNotContain(courses, c => c.StartMinuteOfDay < 13 * 60 && c.EndMinuteOfDay > 12 * 60);
        Assert.DoesNotContain(courses, c => c.StartMinuteOfDay < 18 * 60 + 30 && c.EndMinuteOfDay > 17 * 60 + 30);
    }

    [Fact]
    public void Events_include_pre_start_and_end_bells()
    {
        var config = new DayConfig
        {
            Day = Weekday.Monday,
            IsActive = true,
            PreBellMinutes = 2,
            Courses = [new CourseConfig { Id = 1, StartHour = 8, EndHour = 8, EndMinute = 45 }]
        };

        var events = BellScheduler.GenerateEvents(config);

        Assert.Equal(3, events.Count);
        Assert.Equal("07:58", events[0].TimeText);
        Assert.Equal(BellType.Pre, events[0].Type);
        Assert.Equal(BellType.Start, events[1].Type);
        Assert.Equal(BellType.End, events[2].Type);
    }

    [Fact]
    public void Shift_courses_moves_only_following_courses()
    {
        var config = new DayConfig
        {
            Courses =
            [
                new CourseConfig { Id = 1, StartHour = 8, EndHour = 8, EndMinute = 45 },
                new CourseConfig { Id = 2, StartHour = 8, StartMinute = 55, EndHour = 9, EndMinute = 40 }
            ]
        };

        config.ShiftCoursesAfter(1, 5);

        Assert.Equal("08:00", config.Courses[0].StartText);
        Assert.Equal("09:00", config.Courses[1].StartText);
        Assert.Equal("09:45", config.Courses[1].EndText);
    }

    [Fact]
    public void Conflicts_reports_overlapping_courses()
    {
        var config = new DayConfig
        {
            Courses =
            [
                new CourseConfig { Id = 1, StartHour = 8, EndHour = 9 },
                new CourseConfig { Id = 2, StartHour = 8, StartMinute = 30, EndHour = 9, EndMinute = 15 }
            ]
        };

        Assert.Single(config.Conflicts());
    }
}
