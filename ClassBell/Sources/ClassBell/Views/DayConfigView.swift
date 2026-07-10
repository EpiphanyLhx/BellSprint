import SwiftUI

struct DayConfigView: View {
    @Binding var config: DayConfig
    @ObservedObject var appState: AppState
    
    @State private var globalDuration: Int = 45
    @State private var isCascading = false
    @State private var courseSnapshots: [Int: (start: Int, end: Int)] = [:]
    
    private let hhFmt: NumberFormatter = {
        let f = NumberFormatter(); f.minimumIntegerDigits = 2; f.maximumIntegerDigits = 2; f.minimum = 0; f.maximum = 23; return f
    }()
    private let mmFmt: NumberFormatter = {
        let f = NumberFormatter(); f.minimumIntegerDigits = 2; f.maximumIntegerDigits = 2; f.minimum = 0; f.maximum = 59; return f
    }()
    private let durFmt: NumberFormatter = {
        let f = NumberFormatter(); f.minimum = 10; f.maximum = 180; return f
    }()
    
    private var conflicts: [ConflictResult] { config.conflicts() }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // ── 基本设置 ──
                GroupBox(label: Label("基本设置", systemImage: "gearshape")) {
                    VStack(spacing: 10) {
                        HStack { Text("启用"); Spacer(); Toggle("", isOn: $config.isActive).toggleStyle(.switch).labelsHidden().onChange(of: config.isActive) { _ in save() } }
                        HStack { Text("菜单栏显示课程"); Spacer(); Toggle("", isOn: $config.showCoursesInMenuBar).toggleStyle(.switch).labelsHidden().onChange(of: config.showCoursesInMenuBar) { _ in save() } }
                        HStack { Text("预备铃提前"); Spacer(); Stepper(value: $config.preBellMinutes, in: 0...10) { Text("\(config.preBellMinutes) 分钟").monospacedDigit() }.onChange(of: config.preBellMinutes) { _ in save() } }
                        HStack { Text("第一节课开始"); Spacer(); courseTimeField(hour: $config.startHour, minute: $config.startMinute).onChange(of: config.startHour) { _ in regenerateFromStart() }.onChange(of: config.startMinute) { _ in regenerateFromStart() } }
                        HStack { Text("最后一节课结束"); Spacer(); courseTimeField(hour: $config.endHour, minute: $config.endMinute).onChange(of: config.endHour) { _ in regenerateFromStart() }.onChange(of: config.endMinute) { _ in regenerateFromStart() } }
                        HStack { Text("每节课时长"); Spacer(); Stepper(value: $config.classDuration, in: 5...120) { Text("\(config.classDuration) 分钟").monospacedDigit() }.onChange(of: config.classDuration) { _ in regenerateFromStart() } }
                        HStack { Text("课间休息"); Spacer(); Stepper(value: $config.breakDuration, in: 0...60) { Text("\(config.breakDuration) 分钟").monospacedDigit() }.onChange(of: config.breakDuration) { _ in regenerateFromStart() } }
                    }
                    .padding(.vertical, 4)
                }

                // ── 休息时间（可编辑）──
                GroupBox(label: Label("休息时间", systemImage: "moon")) {
                    VStack(spacing: 12) {
                        breakRow(label: "午休", icon: "sun.max.fill", color: .yellow,
                                 breakConfig: $config.lunchBreak)
                        Divider()
                        breakRow(label: "晚饭", icon: "sunset.fill", color: .orange,
                                 breakConfig: $config.dinnerBreak)
                    }
                    .padding(.vertical, 4)
                }

                // ── 课程表 ──
                GroupBox(label:
                    HStack(spacing: 12) {
                        Label("课程表", systemImage: "tablecells")
                        Spacer()
                        HStack(spacing: 4) {
                            Text("每节课程时长").font(.caption2).foregroundColor(.secondary)
                            Button(action: { adjustAllDuration(-5) }) { Image(systemName: "minus.circle").foregroundColor(.accentColor) }.buttonStyle(.plain).disabled(globalDuration <= 10)
                            TextField("", value: $globalDuration, formatter: durFmt).textFieldStyle(.roundedBorder).frame(width: 44).multilineTextAlignment(.center).font(.system(.caption, design: .monospaced)).onChange(of: globalDuration) { _ in
                                DispatchQueue.main.async {
                                    var d = globalDuration
                                    if d < 10 { d = 10; globalDuration = d }
                                    for i in config.courses.indices {
                                        let newEnd = config.courses[i].startMinuteOfDay + d
                                        config.courses[i].endHour = newEnd / 60
                                        config.courses[i].endMinute = newEnd % 60
                                    }
                                    save()
                                }
                            }
                            Button(action: { adjustAllDuration(5) }) { Image(systemName: "plus.circle").foregroundColor(.accentColor) }.buttonStyle(.plain)
                        }
                        Divider().frame(height: 16)
                        Button(action: addCourse) { Label("添加", systemImage: "plus") }.buttonStyle(.bordered).controlSize(.small)
                        Button("一键生成") { generateCourses() }.buttonStyle(.bordered).controlSize(.small).foregroundColor(.secondary)
                    }
                ) {
                    let conf = conflicts
                    if !conf.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                            Text(conf.map(\.message).joined(separator: "；")).font(.caption).foregroundColor(.red)
                        }
                        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08)).cornerRadius(6).padding(.bottom, 4)
                    }
                    
                    if config.courses.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "plus.circle").font(.title3).foregroundColor(.secondary)
                            Text("点击「添加」或「一键生成」开始排课").font(.caption).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                    } else {
                        VStack(spacing: 0) {
                            HStack(spacing: 8) {
                                Text("").frame(width: 44)
                                Text("预备铃").frame(width: 56)
                                Text("开始").frame(width: 58); Text("结束").frame(width: 58)
                                Text("时长").frame(width: 106); Text("科目").frame(width: 80)
                                Text("").frame(width: 24)
                            }
                            .font(.system(.caption, design: .rounded)).foregroundColor(.secondary).padding(.bottom, 6)
                            Divider()
                            ForEach(0..<config.courses.count, id: \.self) { idx in
                                CourseRowView(course: $config.courses[idx], config: $config, appState: appState, hhFmt: hhFmt, mmFmt: mmFmt, durFmt: durFmt,
                                              onTimeChanged: onCourseTimeChanged,
                                              onDelete: { deleteCourse(id: config.courses[idx].id) })
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 520)
        .onAppear {
            if !config.courses.isEmpty {
                globalDuration = config.courses.map { $0.endMinuteOfDay - $0.startMinuteOfDay }.first ?? config.classDuration
                for c in config.courses {
                    courseSnapshots[c.id] = (c.startMinuteOfDay, c.endMinuteOfDay)
                }
            }
        }
    }
    
    // 休息时间行（开关 + 开始时间 + 时长 +/-）
    private func courseTimeField(hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack(spacing: 2) {
            TextField("00", value: hour, formatter: hhFmt).textFieldStyle(.roundedBorder).frame(width: 26, height: 22).multilineTextAlignment(.center).font(.system(.body, design: .monospaced))
            Text(":").font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)
            TextField("00", value: minute, formatter: mmFmt).textFieldStyle(.roundedBorder).frame(width: 26, height: 22).multilineTextAlignment(.center).font(.system(.body, design: .monospaced))
        }
    }

    private func breakRow(label: String, icon: String, color: Color, breakConfig: Binding<BreakConfig>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(color).frame(width: 16)
            Text(label)
                .frame(width: 36, alignment: .leading)
            Toggle("", isOn: breakConfig.isEnabled)
                .toggleStyle(.switch).labelsHidden()
            
            if breakConfig.wrappedValue.isEnabled {
                // 开始时间
                Text("开始").font(.caption).foregroundColor(.secondary)
                courseTimeField(hour: breakConfig.startHour, minute: breakConfig.startMinute)
                
                // 结束时间（可编辑）
                Text("结束").font(.caption).foregroundColor(.secondary)
                courseTimeField(
                    hour: Binding(
                        get: { breakConfig.wrappedValue.endHour },
                        set: {
                            let startMin = breakConfig.wrappedValue.startMinuteOfDay
                            let newEnd = $0 * 60 + breakConfig.wrappedValue.endMinute
                            let newDuration = newEnd - startMin
                            if newDuration >= 10 { breakConfig.duration.wrappedValue = newDuration }
                            regenerateFromStart()
                        }
                    ),
                    minute: Binding(
                        get: { breakConfig.wrappedValue.endMinute },
                        set: {
                            let startMin = breakConfig.wrappedValue.startMinuteOfDay
                            let newEnd = breakConfig.wrappedValue.endHour * 60 + $0
                            let newDuration = newEnd - startMin
                            if newDuration >= 10 { breakConfig.duration.wrappedValue = newDuration }
                            regenerateFromStart()
                        }
                    )
                )

                // 时长调整
                Text("时长").font(.caption).foregroundColor(.secondary)
                HStack(spacing: 2) {
                    Button(action: {
                        breakConfig.duration.wrappedValue = max(10, breakConfig.duration.wrappedValue - 5)
                        regenerateFromStart()
                    }) {
                        Image(systemName: "minus.circle").foregroundColor(breakConfig.wrappedValue.duration <= 10 ? .gray : .accentColor)
                    }.buttonStyle(.plain).disabled(breakConfig.wrappedValue.duration <= 10)
                    
                    TextField("", value: breakConfig.duration, formatter: durFmt)
                        .textFieldStyle(.roundedBorder).frame(width: 44).multilineTextAlignment(.center)
                        .font(.system(.caption, design: .monospaced))
                    
                    Button(action: {
                        breakConfig.duration.wrappedValue = min(180, breakConfig.duration.wrappedValue + 5)
                        regenerateFromStart()
                    }) {
                        Image(systemName: "plus.circle").foregroundColor(.accentColor)
                    }.buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .onChange(of: breakConfig.wrappedValue.isEnabled) { _ in regenerateFromStart() }
        .onChange(of: breakConfig.wrappedValue.startHour) { _ in regenerateFromStart() }
        .onChange(of: breakConfig.wrappedValue.startMinute) { _ in regenerateFromStart() }
        .onChange(of: breakConfig.wrappedValue.duration) { _ in regenerateFromStart() }
    }
    
    private func adjustAllDuration(_ delta: Int) {
        globalDuration = max(10, globalDuration + delta)
        for i in config.courses.indices {
            let newEnd = config.courses[i].startMinuteOfDay + globalDuration
            config.courses[i].endHour = newEnd / 60
            config.courses[i].endMinute = newEnd % 60
        }
        save()
    }
    
    private func addCourse() {
        let lastEnd = config.courses.last?.endMinuteOfDay ?? (config.startHour * 60 + config.startMinute)
        let newId = (config.courses.map(\.id).max() ?? 0) + 1
        let dur = globalDuration
        let sm = lastEnd % 60; let sh = lastEnd / 60
        let em = lastEnd + dur
        config.courses.append(CourseConfig(id: newId, name: "", startHour: sh, startMinute: sm, endHour: em / 60, endMinute: em % 60))
        save()
    }
    
    private func deleteCourse(id: Int) { config.courses.removeAll { $0.id == id }; save() }
    private func regenerateFromStart() {
        config.courses = DayConfig.defaultCourses(from: config)
        globalDuration = config.classDuration
        save()
    }
    private func generateCourses() { config.courses = DayConfig.defaultCourses(from: config); globalDuration = config.classDuration; save() }
    private func save() { refreshSnapshots(); appState.updateConfig(config) }

    private func refreshSnapshots() {
        courseSnapshots.removeAll()
        for c in config.courses {
            courseSnapshots[c.id] = (c.startMinuteOfDay, c.endMinuteOfDay)
        }
    }
    
    private func onCourseTimeChanged(courseId: Int) {
        guard let idx = config.courses.firstIndex(where: { $0.id == courseId }) else { return }
        let course = config.courses[idx]
        guard let snap = courseSnapshots[courseId] else { return }
        let endDelta = course.endMinuteOfDay - snap.end
        guard endDelta != 0 else { return }
        config.shiftCourses(after: courseId, by: endDelta)
        // Update snapshots for cascaded courses
        for i in idx..<config.courses.count {
            let c = config.courses[i]
            courseSnapshots[c.id] = (c.startMinuteOfDay, c.endMinuteOfDay)
        }
        save()
    }
}

struct CourseRowView: View {
    @Binding var course: CourseConfig
    @Binding var config: DayConfig
    let appState: AppState
    let hhFmt: NumberFormatter; let mmFmt: NumberFormatter; let durFmt: NumberFormatter
    let onTimeChanged: (Int) -> Void
    let onDelete: () -> Void
    
    private var duration: Int { max(0, course.endMinuteOfDay - course.startMinuteOfDay) }
    
    var body: some View {
        HStack(spacing: 8) {
            Text("\(course.id)").font(.system(.caption, design: .rounded).bold())
                .frame(width: 44, height: 28).background(Color.accentColor.opacity(0.15)).cornerRadius(6)
            if config.preBellMinutes > 0 {
                let pm = course.startMinuteOfDay - config.preBellMinutes
                if pm >= 0 { Text(String(format: "%02d:%02d", pm / 60, pm % 60)).font(.system(.caption2, design: .monospaced)).foregroundColor(.orange).frame(width: 56) }
                else { Text("—").foregroundColor(.secondary).frame(width: 56) }
            } else { Color.clear.frame(width: 56) }
            courseTimeField(hour: $course.startHour, minute: $course.startMinute).frame(width: 58)
            courseTimeField(hour: $course.endHour, minute: $course.endMinute).frame(width: 58)
            HStack(spacing: 2) {
                Button(action: { adjustDuration(-5) }) { Image(systemName: "minus.circle").foregroundColor(duration <= 10 ? .gray : .accentColor) }.buttonStyle(.plain).disabled(duration <= 10)
                TextField("", value: durationBinding, formatter: durFmt).textFieldStyle(.roundedBorder).frame(width: 44).multilineTextAlignment(.center).font(.system(.caption, design: .monospaced))
                Button(action: { adjustDuration(5) }) { Image(systemName: "plus.circle").foregroundColor(.accentColor) }.buttonStyle(.plain)
            }.frame(width: 106)
            TextField("科目", text: $course.name).textFieldStyle(.roundedBorder).frame(width: 80)
            Button(action: onDelete) { Image(systemName: "xmark.circle.fill").foregroundColor(.red.opacity(0.7)).font(.system(size: 15)) }.buttonStyle(.plain).frame(width: 24)
        }
        .padding(.vertical, 4)
        .onChange(of: course.name) { _ in appState.updateConfig(config) }
        .onChange(of: course.startHour) { _ in onChanged() }
        .onChange(of: course.startMinute) { _ in onChanged() }
        .onChange(of: course.endHour) { _ in onChanged() }
        .onChange(of: course.endMinute) { _ in onChanged() }
        Divider().opacity(0.3)
    }
    
    private func onChanged() {
        appState.updateConfig(config)
        DispatchQueue.main.async {
            onTimeChanged(course.id)
        }
    }
    
    private var durationBinding: Binding<Int> {
        Binding<Int>(
            get: { duration },
            set: { newDur in
                let d = max(10, newDur)
                let newEnd = course.startMinuteOfDay + d
                course.endHour = newEnd / 60; course.endMinute = newEnd % 60
            }
        )
    }
    
    private func adjustDuration(_ delta: Int) {
        let newDuration = max(10, duration + delta)
        let newEnd = course.startMinuteOfDay + newDuration
        course.endHour = newEnd / 60; course.endMinute = newEnd % 60
    }
    
    private func courseTimeField(hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack(spacing: 2) {
            TextField("00", value: hour, formatter: hhFmt).textFieldStyle(.roundedBorder).frame(width: 26, height: 22).multilineTextAlignment(.center).font(.system(.body, design: .monospaced))
            Text(":").font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)
            TextField("00", value: minute, formatter: mmFmt).textFieldStyle(.roundedBorder).frame(width: 26, height: 22).multilineTextAlignment(.center).font(.system(.body, design: .monospaced))
        }
    }
}
    
