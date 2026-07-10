import Combine
import Foundation
import AppKit
import ServiceManagement

final class AppState: ObservableObject {
    @Published var dayConfigs: [DayConfig] = [] { didSet { saveConfigs() } }
        @Published var isEnabled = true { didSet { if isEnabled { lastRungIDs.removeAll() } } }
    @Published var launchAtLogin = false { didSet {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("SMAppService error: \(error)")
            DispatchQueue.main.async { self.launchAtLogin = !self.launchAtLogin }
        }
        UserDefaults.standard.set(launchAtLogin, forKey: "launch_at_login")
    } }
    @Published var todayEvents: [BellEvent] = []
    @Published var nextEventText: String = "暂无"
    
    let audioService = AudioService.shared
    private var timer: Timer?
    private var lastRungIDs: Set<String> = []
    private var lastDayCheck = -1
    private var lastRefreshMinute = -1
    private let saveKey = "ClassBellDayConfigs"
    
    init() {
        launchAtLogin = UserDefaults.standard.bool(forKey: "launch_at_login")
        loadConfigs()
        if dayConfigs.isEmpty { initDefaultConfigs() }
        updateTodayEvents()
        startTimer()
    }
    
    private func initDefaultConfigs() {
        let pairs: [(Weekday, Bool)] = [
            (.monday, true), (.tuesday, true), (.wednesday, true),
            (.thursday, true), (.friday, true), (.saturday, false), (.sunday, false)
        ]
        dayConfigs = pairs.map { day, active in
            DayConfig(day: day, isActive: active,
                      startHour: 8, startMinute: 0,
                      endHour: 21, endMinute: 0,
                      classDuration: 45, breakDuration: 10, preBellMinutes: 2)
        }
    }
    
    func updateConfig(_ config: DayConfig) {
        guard let idx = dayConfigs.firstIndex(where: { $0.day == config.day }) else { return }
        dayConfigs[idx] = config; updateTodayEvents()
    }
    
    private func saveConfigs() {
        if let data = try? JSONEncoder().encode(dayConfigs) { UserDefaults.standard.set(data, forKey: saveKey) }
    }
    
    private func loadConfigs() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let configs = try? JSONDecoder().decode([DayConfig].self, from: data) else { return }
        dayConfigs = configs
    }
    
    func updateTodayEvents() {
        todayEvents = BellScheduler.eventsForToday(configs: dayConfigs); updateNextEvent()
    }
    
    private func updateNextEvent() {
        if let next = BellScheduler.nextEvent(configs: dayConfigs) {
            nextEventText = "\(next.event.timeString) \(next.event.type.rawValue)"
        } else { nextEventText = todayEvents.isEmpty ? "今日无课" : "已结束" }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    private func tick() {
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentMinuteOfDay = hour * 60 + minute
        
        if weekday != lastDayCheck {
            lastDayCheck = weekday; updateTodayEvents(); lastRungIDs.removeAll()
        }

        // 每分钟刷新一次事件列表，防止 todayEvents 陈旧导致漏铃
        if currentMinuteOfDay != lastRefreshMinute {
            lastRefreshMinute = currentMinuteOfDay
            updateTodayEvents()
        }

        guard isEnabled else { return }
        for event in todayEvents where !lastRungIDs.contains(event.id) {
            if event.matches(hour: hour, minute: minute) {
                lastRungIDs.insert(event.id)
                audioService.play(event.type)
                break
            }
        }
        updateNextEvent()
    }
    
    deinit { timer?.invalidate() }
}
