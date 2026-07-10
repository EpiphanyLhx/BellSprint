import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── 顶部状态栏 ──
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                    .font(.title3)
                    .foregroundColor(appState.isEnabled ? .green : .red)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("上下课铃声")
                        .font(.headline)
                    Text(timeString)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $appState.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
                    .help(appState.isEnabled ? "点击暂停" : "点击恢复")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // ── 下一个事件 ──
            VStack(spacing: 4) {
                HStack {
                    Text("下一个")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                HStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(appState.nextEventText == "今日无课" || appState.nextEventText == "已结束" ? .secondary : .accentColor)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(appState.nextEventText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(appState.nextEventText == "今日无课" ? .secondary : .primary)
                        if appState.nextEventText != "今日无课" && appState.nextEventText != "暂无" && appState.nextEventText != "已结束" {
                            let parts = appState.nextEventText.split(separator: " ")
                            if parts.count >= 2 {
                                Text(String(parts[0]))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // ── 今日课程 ──
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("今日课程")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("共 \(todayCourses.count) 节")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
                
                if todayCourses.isEmpty {
                    HStack {
                        Image(systemName: "moon.zzz")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("今日无课")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                } else {
                    List(todayCourses) { course in
                        let st = status(for: course)
                        HStack(spacing: 6) {
                            Text("\(course.id)")
                                .font(.system(.caption, design: .rounded).bold())
                                .frame(width: 20, height: 18)
                                .background(st == .current ? Color.green : (st == .upcoming ? Color.orange : Color.accentColor).opacity(0.2))
                                .cornerRadius(4)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(course.name.isEmpty ? "未设置" : course.name)
                                    .font(.body)
                                    .lineLimit(1)
                                Text("\(course.startString) - \(course.endString)")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if st == .current {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green)
                            } else if st == .upcoming {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 4)
                        .background(
                            st == .current ? Color.green.opacity(0.12) :
                            st == .upcoming ? Color.orange.opacity(0.08) :
                            Color.clear
                        )
                        .cornerRadius(6)
                    }
                    .listStyle(.plain)
                    .frame(height: min(CGFloat(todayCourses.count) * 36, 200))
                }
            }
            
            Divider()
            
            // ── 操作按钮 ──
            VStack(spacing: 0) {
                MenuBarActionButton(
                    icon: appState.isEnabled ? "pause.circle" : "play.circle",
                    title: appState.isEnabled ? "暂停铃声" : "恢复铃声",
                    action: { appState.isEnabled.toggle() }
                )
                Divider().opacity(0.3)
                MenuBarActionButton(
                    icon: "speaker.wave.2",
                    title: "测试铃声",
                    action: { AudioService.shared.play(.start) }
                )
                Divider().opacity(0.3)
                MenuBarActionButton(
                    icon: "gearshape",
                    title: "打开设置",
                    action: {
                        openWindow(id: "settings")
                        NSApp.activate(ignoringOtherApps: true)
                    }
                )
                Divider().opacity(0.3)
                HStack(spacing: 8) {
                    Image(systemName: "power")
                        .font(.system(size: 13))
                        .frame(width: 16)
                    Text("开机自启动")
                        .font(.body)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.launchAtLogin },
                        set: { appState.launchAtLogin = $0 }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            
            Divider()
            
            // ── 退出 ──
            Button(action: { NSApplication.shared.terminate(nil) }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("退出")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .padding(.vertical, 4)
        .frame(width: 260)
        .onReceive(timer) { _ in currentTime = Date() }
    }
    
    private var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: currentTime)
    }
    
    private var currentMinuteOfDay: Int {
        let cal = Calendar.current
        let h = cal.component(.hour, from: currentTime)
        let m = cal.component(.minute, from: currentTime)
        return h * 60 + m
    }
    
    private var todayCourses: [CourseConfig] {
        let calendar = Calendar.current
        let weekdayIndex = calendar.component(.weekday, from: Date())
        let today = Weekday.fromCalendar(weekdayIndex)
        guard let config = appState.dayConfigs.first(where: { $0.day == today }), config.isActive, config.showCoursesInMenuBar else { return [] }
        return config.courses.sorted { $0.id < $1.id }
    }
    
    private enum CourseStatus { case past, current, upcoming }
    
    private func status(for course: CourseConfig) -> CourseStatus {
        let now = currentMinuteOfDay
        if now >= course.startMinuteOfDay && now < course.endMinuteOfDay { return .current }
        if now < course.startMinuteOfDay { return .upcoming }
        return .past
    }

}

struct MenuBarActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 16)
                Text(title)
                    .font(.body)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
