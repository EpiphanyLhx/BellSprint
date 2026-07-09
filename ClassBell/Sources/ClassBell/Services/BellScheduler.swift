import Foundation

struct BellScheduler {
    // 从 courses 列表生成 BellEvent（用于调度播放）
    static func generateEvents(from config: DayConfig) -> [BellEvent] {
        guard config.isActive else { return [] }
        var events: [BellEvent] = []
        let pre = config.preBellMinutes
        for c in config.courses {
            // 预备铃
            if pre > 0 {
                let pm = c.startMinuteOfDay - pre
                if pm >= 0 {
                    events.append(BellEvent(id: "\(config.day.rawValue)-\(c.id)-pre",
                                            hour: pm / 60, minute: pm % 60, type: .pre, classNumber: c.id))
                }
            }
            // 上课铃
            events.append(BellEvent(id: "\(config.day.rawValue)-\(c.id)-start",
                                    hour: c.startHour, minute: c.startMinute, type: .start, classNumber: c.id))
            // 下课铃
            events.append(BellEvent(id: "\(config.day.rawValue)-\(c.id)-end",
                                    hour: c.endHour, minute: c.endMinute, type: .end, classNumber: c.id))
        }
        return events
    }
    
    static func eventsForToday(configs: [DayConfig]) -> [BellEvent] {
        let calendar = Calendar.current
        let weekdayIndex = calendar.component(.weekday, from: Date())
        let today = Weekday.fromCalendar(weekdayIndex)
        guard let config = configs.first(where: { $0.day == today }), config.isActive else { return [] }
        return generateEvents(from: config)
    }
    
    static func nextEvent(configs: [DayConfig]) -> (event: BellEvent, minutesUntil: Int)? {
        let now = Date()
        let calendar = Calendar.current
        let currentMinute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let events = eventsForToday(configs: configs)
        for event in events {
            let eventMinute = event.hour * 60 + event.minute
            let diff = eventMinute - currentMinute
            if diff >= 0 { return (event, diff) }
        }
        return nil
    }
}
