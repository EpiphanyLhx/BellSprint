import SwiftUI

enum SyncMode: String, CaseIterable {
    case all = "全部"
    case time = "时间安排"
    case courses = "课程安排"
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDay: Weekday = .monday
    @State private var showSyncSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                List(Weekday.allCases.sorted(), id: \.self) { day in
                    let active = appState.dayConfigs.first(where: { $0.day == day })?.isActive ?? false
                    HStack(spacing: 8) {
                        Circle().fill(active ? Color.green : Color.gray.opacity(0.4)).frame(width: 8, height: 8)
                        Text(day.displayName).foregroundColor(active ? .primary : .secondary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selectedDay = day } }
                    .padding(.vertical, 4).padding(.horizontal, 8)
                    .background(selectedDay == day ? Color.accentColor.opacity(0.15) : Color.clear).cornerRadius(6)
                }
                .listStyle(.plain).frame(width: 120)
                Divider()
                VStack(spacing: 0) {
                    if appState.dayConfigs.contains(where: { $0.day == selectedDay }) {
                        DayConfigView(config: Binding(
                            get: { appState.dayConfigs.first(where: { $0.day == selectedDay }) ?? DayConfig(day: selectedDay) },
                            set: { appState.updateConfig($0) }
                        ), appState: appState)
                        .id(selectedDay)
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                                removal: .move(edge: .bottom).combined(with: .opacity)))
                    } else {
                        Spacer(); Text("请选择一天").foregroundColor(.secondary); Spacer()
                    }
                    Divider()
                    HStack {
                        Spacer()
                        Button(action: { showSyncSheet = true }) {
                            Label("同步到其他天", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!(appState.dayConfigs.first(where: { $0.day == selectedDay })?.isActive ?? false))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                    }
                }
                .frame(minWidth: 420)
            }
            Divider()
            SoundSettingsView().frame(maxWidth: .infinity)
        }
        .frame(minWidth: 560, minHeight: 600)
        .sheet(isPresented: $showSyncSheet) { syncSheet }
    }
    
    private var syncSheet: some View {
        VStack(spacing: 16) {
            Text("将「\(selectedDay.displayName)」同步到：").font(.headline)
            SyncDayPicker(dayConfigs: appState.dayConfigs, sourceDay: selectedDay) { targets, mode in
                guard let src = appState.dayConfigs.first(where: { $0.day == selectedDay }) else { return }
                for targetDay in targets {
                    guard let idx = appState.dayConfigs.firstIndex(where: { $0.day == targetDay }) else { continue }
                    switch mode {
                    case .all:
                        var copy = src; copy.day = targetDay; appState.dayConfigs[idx] = copy
                    case .time:
                        var t = appState.dayConfigs[idx]
                        t.isActive = src.isActive; t.startHour = src.startHour; t.startMinute = src.startMinute
                        t.endHour = src.endHour; t.endMinute = src.endMinute; t.classDuration = src.classDuration
                        t.breakDuration = src.breakDuration; t.preBellMinutes = src.preBellMinutes
                        t.lunchBreak = src.lunchBreak; t.dinnerBreak = src.dinnerBreak
                        appState.dayConfigs[idx] = t
                    case .courses:
                        var t = appState.dayConfigs[idx]; t.courseNames = src.courseNames; appState.dayConfigs[idx] = t
                    }
                }
                showSyncSheet = false
            }
            Button("取消") { showSyncSheet = false }.keyboardShortcut(.escape)
        }
        .padding().frame(width: 320)
    }
}

struct SyncDayPicker: View {
    let dayConfigs: [DayConfig]; let sourceDay: Weekday
    let onSync: ([Weekday], SyncMode) -> Void
    @State private var selected: Set<Weekday> = []
    @State private var syncMode: SyncMode = .all
    
    var body: some View {
        let available = Weekday.allCases.filter { $0 != sourceDay }.sorted()
        Picker("同步内容", selection: $syncMode) {
            ForEach(SyncMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }.pickerStyle(.segmented)
        Divider()
        VStack(alignment: .leading, spacing: 8) {
            ForEach(available, id: \.self) { day in
                let config = dayConfigs.first(where: { $0.day == day })
                HStack {
                    Toggle("", isOn: Binding(get: { selected.contains(day) }, set: { if $0 { selected.insert(day) } else { selected.remove(day) } }))
                        .toggleStyle(.checkbox).labelsHidden()
                    Circle().fill(config?.isActive == true ? Color.green : Color.gray.opacity(0.4)).frame(width: 6, height: 6)
                    Text(day.displayName).foregroundColor(config?.isActive == true ? .primary : .secondary)
                    if let c = config, c.isActive {
                        Text("(\(c.courses.count)节)").font(.caption).foregroundColor(.secondary)
                    } else { Text("(未启用)").font(.caption).foregroundColor(.secondary) }
                }
            }
        }
        .padding(.vertical, 4)
        Divider()
        HStack(spacing: 12) {
            Button("全选") { selected = Set(available) }.buttonStyle(.borderless).font(.caption)
            Button("取消全选") { selected.removeAll() }.buttonStyle(.borderless).font(.caption)
            Spacer()
            Button("同步 (\(selected.count))") { guard !selected.isEmpty else { return }; onSync(Array(selected).sorted(), syncMode) }
                .buttonStyle(.borderedProminent).disabled(selected.isEmpty)
        }
    }
}
