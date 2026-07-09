import SwiftUI
import UniformTypeIdentifiers

struct SoundSettingsView: View {
    @State private var preBellPath = ""; @State private var startBellPath = ""; @State private var endBellPath = ""
    @State private var statusMessage = ""
    private let defaults = UserDefaults.standard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("自定义铃声").font(.headline)
            soundRow(label: "预备铃", key: "custom_sound_pre", path: $preBellPath)
            soundRow(label: "上课铃", key: "custom_sound_start", path: $startBellPath)
            soundRow(label: "下课铃", key: "custom_sound_end", path: $endBellPath)
            if !statusMessage.isEmpty { Text(statusMessage).font(.caption).foregroundColor(.green) }
            HStack { Spacer(); Button("恢复默认铃声") { resetAll() }.buttonStyle(.borderless).foregroundColor(.secondary) }
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
