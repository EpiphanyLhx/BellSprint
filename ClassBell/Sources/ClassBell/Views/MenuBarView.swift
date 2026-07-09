import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(appState.isEnabled ? .green : .red)
                Text("上下课铃声")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(appState.isEnabled ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
            }
            .padding(.horizontal, 10)
            
            HStack {
                Text("下一个:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(appState.nextEventText)
                    .font(.system(.caption, design: .monospaced))
                Spacer()
            }
            .padding(.horizontal, 10)
            
            Divider()
            
            if !appState.todayEvents.isEmpty {
                Text("今日铃声")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                ForEach(0..<min(appState.todayEvents.count, 4), id: \.self) { i in
                    let event = appState.todayEvents[i]
                    HStack(spacing: 6) {
                        Image(systemName: event.type.symbol)
                            .foregroundColor(colorForType(event.type))
                            .frame(width: 14)
                        Text(event.timeString)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 38, alignment: .leading)
                        Text(event.type.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("第\(event.classNumber)节")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                }
                if appState.todayEvents.count > 4 {
                    Text("还有 \(appState.todayEvents.count - 4) 个铃声...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                }
            } else {
                Text("今日无课")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
            }
            
            Divider()
            
            Button(appState.isEnabled ? "暂停铃声" : "恢复铃声") {
                appState.isEnabled.toggle()
            }
            .padding(.horizontal, 10)
            
            Button("🔊 测试铃声") {
                AudioService().play(.start)
            }
            .padding(.horizontal, 10)
            
            Button("⚙️ 打开设置") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            .padding(.horizontal, 10)
            
            Divider()
            
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.horizontal, 10)
        }
        .padding(.vertical, 6)
        .frame(width: 240)
    }
    
    private func colorForType(_ type: BellType) -> Color {
        switch type {
        case .pre: return .orange
        case .start: return .green
        case .end: return .red
        }
    }
}
