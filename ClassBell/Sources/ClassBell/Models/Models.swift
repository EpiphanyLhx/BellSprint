import Foundation

struct BreakConfig: Codable, Equatable {
    var isEnabled = false
    var startHour = 12
    var startMinute = 0
    var duration = 60
    
    // 计算结束时间
    var endHour: Int {
        let totalMinutes = startHour * 60 + startMinute + duration
        return totalMinutes / 60
    }
    var endMinute: Int {
        let totalMinutes = startHour * 60 + startMinute + duration
        return totalMinutes % 60
    }
    var startMinuteOfDay: Int { startHour * 60 + startMinute }
    var endMinuteOfDay: Int { endHour * 60 + endMinute }
    var startString: String { String(format: "%02d:%02d", startHour, startMinute) }
    var endString: String { String(format: "%02d:%02d", endHour, endMinute) }
}

struct CourseConfig: Codable, Identifiable, Equatable {
    var id: Int          // 课程编号 1,2,3...
    var name: String     // 科目名称
    var showInMenuBar = true
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    
    var startMinuteOfDay: Int { startHour * 60 + startMinute }
    var endMinuteOfDay: Int { endHour * 60 + endMinute }
    var startString: String { String(format: "%02d:%02d", startHour, startMinute) }
    var endString: String { String(format: "%02d:%02d", endHour, endMinute) }
    
    static func defaultCourse(id: Int, startHour: Int = 8, startMinute: Int = 0, duration: Int = 45) -> CourseConfig {
        let endMin = startMinute + duration
        return CourseConfig(id: id, name: "",
                            startHour: startHour, startMinute: startMinute,
                            endHour: startHour + endMin / 60, endMinute: endMin % 60)
    }
}

// 时间冲突检测结果
struct ConflictResult: Equatable {
    let course1: Int
    let course2: Int
    var message: String { "第\(course1)节和第\(course2)节时间重叠" }
}

enum Weekday: String, CaseIterable, Codable, Identifiable, Comparable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .monday: return "周一"; case .tuesday: return "周二"; case .wednesday: return "周三"
        case .thursday: return "周四"; case .friday: return "周五"; case .saturday: return "周六"; case .sunday: return "周日"
        }
    }
    var order: Int {
        switch self {
        case .monday: return 1; case .tuesday: return 2; case .wednesday: return 3
        case .thursday: return 4; case .friday: return 5; case .saturday: return 6; case .sunday: return 7
        }
    }
    static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.order < rhs.order }
    static func fromCalendar(_ i: Int) -> Weekday {
        switch i {
        case 1: return .sunday; case 2: return .monday; case 3: return .tuesday
        case 4: return .wednesday; case 5: return .thursday; case 6: return .friday
        case 7: return .saturday; default: return .monday
        }
    }
}

struct DayConfig: Codable, Identifiable, Equatable {
    var id: String { day.rawValue }
    var day: Weekday
    var isActive = false
    // 保留整体时间范围（用于"一键生成"）
    var startHour = 8; var startMinute = 0
    var endHour = 21; var endMinute = 0
    var classDuration = 45; var breakDuration = 10; var preBellMinutes = 2
    // 新增：手动课程列表
    var courses: [CourseConfig] = []
    var lunchBreak = BreakConfig(isEnabled: true, startHour: 12, startMinute: 0, duration: 60)
    var dinnerBreak = BreakConfig(isEnabled: true, startHour: 17, startMinute: 30, duration: 60)
    
    // 向后兼容旧数据：courseNames 转成 courses
    var courseNames: [Int: String] = [:] { didSet {} }
    func className(for num: Int) -> String { courses.first(where: { $0.id == num })?.name ?? "" }
    
    // 冲突检测
    func conflicts() -> [ConflictResult] {
        var result: [ConflictResult] = []
        let sorted = courses.sorted { $0.startMinuteOfDay < $1.startMinuteOfDay }
        for i in 0..<sorted.count {
            for j in (i+1)..<sorted.count {
                if sorted[j].startMinuteOfDay < sorted[i].endMinuteOfDay {
                    result.append(ConflictResult(course1: sorted[i].id, course2: sorted[j].id))
                } else {
                    break
                }
            }
        }
        return result
    }
    
    mutating func shiftCourses(after courseId: Int, by deltaMinutes: Int) {
        guard let idx = courses.firstIndex(where: { $0.id == courseId }) else { return }
        for i in (idx + 1)..<courses.count {
            let ns = courses[i].startMinuteOfDay + deltaMinutes
            let ne = courses[i].endMinuteOfDay + deltaMinutes
            courses[i].startHour = ns / 60
            courses[i].startMinute = ns % 60
            courses[i].endHour = ne / 60
            courses[i].endMinute = ne % 60
        }
    }

    // 从旧的自动排课生成默认 courses（考虑午餐和晚餐休息时间）
    static func defaultCourses(from config: DayConfig) -> [CourseConfig] {
        let start = config.startHour * 60 + config.startMinute
        let end = config.endHour * 60 + config.endMinute
        var courses: [CourseConfig] = []
        var current = start
        var num = 1
        
        // 收集休息时间段
        var breaks: [(start: Int, end: Int)] = []
        if config.lunchBreak.isEnabled {
            breaks.append((start: config.lunchBreak.startMinuteOfDay, end: config.lunchBreak.endMinuteOfDay))
        }
        if config.dinnerBreak.isEnabled {
            breaks.append((start: config.dinnerBreak.startMinuteOfDay, end: config.dinnerBreak.endMinuteOfDay))
        }
        // 按开始时间排序
        breaks.sort { $0.start < $1.start }
        
        while current + config.classDuration <= end {
            // 检查是否需要跳过休息时间
            var needSkip = true
            while needSkip {
                needSkip = false
                for brk in breaks {
                    // 如果课程开始时间在休息时间内，跳过到休息结束
                    if current >= brk.start && current < brk.end {
                        current = brk.end
                        needSkip = true
                        break
                    }
                    // 如果课程时间段与休息时间重叠，跳过到休息结束
                    if current < brk.start && current + config.classDuration > brk.start {
                        current = brk.end
                        needSkip = true
                        break
                    }
                }
            }
            
            let e = current + config.classDuration
            if e > end { break }
            courses.append(CourseConfig(id: num, name: "",
                                        startHour: current / 60, startMinute: current % 60,
                                        endHour: e / 60, endMinute: e % 60))
            current = e + config.breakDuration
            num += 1
        }
        return courses
    }
}

struct BellEvent: Identifiable, Equatable {
    let id: String
    let hour: Int
    let minute: Int
    let type: BellType
    let classNumber: Int
    var timeString: String { String(format: "%02d:%02d", hour, minute) }
    func matches(hour h: Int, minute m: Int) -> Bool {
        hour == h && minute == m
    }
}

enum BellType: String, Codable {
    case pre = "预备铃"
    case start = "上课铃"
    case end = "下课铃"
    var symbol: String {
        switch self {
        case .pre: return "bell.badge"
        case .start: return "bell.fill"
        case .end: return "bell.slash.fill"
        }
    }
}
