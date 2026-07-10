import SwiftUI
import UniformTypeIdentifiers

struct SoundSettingsView: View {
    @ObservedObject var audioService: AudioService
    
    @State private var preBellPath = ""; @State private var startBellPath = ""; @State private var endBellPath = ""
    @State private var statusMessage = ""
    private let defaults = UserDefaults.standard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ── 音量 ──
            GroupBox(label: Label("音量", systemImage: "speaker.wave.2")) {
                VStack(spacing: 4) {
                    Slider(value: Binding(
                        get: { Double(audioService.volume) },
                        set: { audioService.volume = Float($0) }
                    ), in: 0...1, step: 0.05)
                    HStack {
                        Image(systemName: "speaker.fill").foregroundColor(.secondary).font(.caption)
                        Spacer()
                        Text("\(Int(audioService.volume * 100))%").font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "speaker.wave.3.fill").foregroundColor(.secondary).font(.caption)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // ── 输出设备 ──
            GroupBox(label: Label("输出设备", systemImage: "hifispeaker")) {
                VStack(spacing: 6) {
                    Picker("设备", selection: $audioService.selectedDeviceUID) {
                        Text("MacBook 内置扬声器").tag("")
                        ForEach(audioService.availableDevices) { device in
                            Text(device.name).tag(device.id)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Button("刷新设备列表") {
                        audioService.availableDevices = AudioService.enumerateOutputDevices()
                    }
                    .buttonStyle(.borderless).font(.caption).foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            // ── 铃声文件 ──
            GroupBox(label: Label("自定义铃声", systemImage: "music.note")) {
                VStack(spacing: 10) {
                    soundRow(label: "预备铃", key: "custom_sound_pre", path: $preBellPath)
                    soundRow(label: "上课铃", key: "custom_sound_start", path: $startBellPath)
                    soundRow(label: "下课铃", key: "custom_sound_end", path: $endBellPath)
                    if !statusMessage.isEmpty { Text(statusMessage).font(.caption).foregroundColor(.green) }
                    HStack { Spacer(); Button("恢复默认铃声") { resetAll() }.buttonStyle(.borderless).foregroundColor(.secondary) }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .onAppear(perform: loadPaths)
    }
    
    private func soundRow(label: String, key: String, path: Binding<String>) -> some View {
        HStack {
            Text(label).frame(width: 60, alignment: .leading)
            Text(path.wrappedValue.isEmpty ? "默认铃声" : URL(fileURLWithPath: path.wrappedValue).lastPathComponent)
                .foregroundColor(path.wrappedValue.isEmpty ? .secondary : .primary)
                .lineLimit(1).truncationMode(.middle)
            Spacer()
            Button("选择文件") { selectSound(key: key, path: path) }
            if !path.wrappedValue.isEmpty {
                Button("×") { clearSound(key: key, path: path) }.buttonStyle(.borderless).foregroundColor(.red)
            }
        }
    }
    
    private func selectSound(key: String, path: Binding<String>) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.wav, .mp3, .mpeg4Audio, .aiff]
        panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let dest = copyToSupport(url: url, name: key)
        path.wrappedValue = dest.path
        defaults.set(dest.path, forKey: key)
        statusMessage = "✓ \(key) 已更新"
        NotificationCenter.default.post(name: NSNotification.Name("CustomSoundChanged"), object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { statusMessage = "" }
    }
    
    private func clearSound(key: String, path: Binding<String>) {
        path.wrappedValue = ""; defaults.removeObject(forKey: key)
        statusMessage = "已恢复默认"
        NotificationCenter.default.post(name: NSNotification.Name("CustomSoundChanged"), object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { statusMessage = "" }
    }
    
    private func resetAll() {
        preBellPath = ""; startBellPath = ""; endBellPath = ""
        ["custom_sound_pre", "custom_sound_start", "custom_sound_end"].forEach { defaults.removeObject(forKey: $0) }
        statusMessage = "已恢复所有默认铃声"
        NotificationCenter.default.post(name: NSNotification.Name("CustomSoundChanged"), object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { statusMessage = "" }
    }
    
    private func copyToSupport(url: URL, name: String) -> URL {
        let fm = FileManager.default
        let supportDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = supportDir.appendingPathComponent("ClassBell")
        try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        let ext = url.pathExtension.isEmpty ? "wav" : url.pathExtension
        let dest = appDir.appendingPathComponent("\(name).\(ext)")
        try? fm.removeItem(at: dest); try? fm.copyItem(at: url, to: dest)
        return dest
    }
    
    private func loadPaths() {
        preBellPath = defaults.string(forKey: "custom_sound_pre") ?? ""
        startBellPath = defaults.string(forKey: "custom_sound_start") ?? ""
        endBellPath = defaults.string(forKey: "custom_sound_end") ?? ""
    }
}
