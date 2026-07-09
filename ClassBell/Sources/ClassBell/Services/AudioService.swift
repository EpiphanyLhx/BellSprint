import AVFoundation
import AppKit

final class AudioService {
    private var soundData: [BellType: Data] = [:]
    private var activePlayers: [AVAudioPlayer] = []
    private let defaults = UserDefaults.standard
    
    init() {
        loadAllSounds()
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: NSNotification.Name("CustomSoundChanged"), object: nil)
    }
    @objc private func reload() { loadAllSounds() }
    
    private func loadAllSounds() {
        soundData.removeAll()
        for type in [BellType.pre, BellType.start, BellType.end] { loadSound(type) }
    }
    
    private func loadSound(_ type: BellType) {
        let key: String; let fn: String
        switch type {
        case .pre:   key = "custom_sound_pre";   fn = "pre_bell"
        case .start: key = "custom_sound_start"; fn = "start_bell"
        case .end:   key = "custom_sound_end";   fn = "end_bell"
        }
        // Custom sound
        if let p = defaults.string(forKey: key), !p.isEmpty,
           let data = try? Data(contentsOf: URL(fileURLWithPath: p)) {
            soundData[type] = data
            print("Loaded custom \(fn): \(data.count) bytes")
            return
        }
        // Bundled sound
        if let url = Bundle.module.url(forResource: fn, withExtension: "wav")
           ?? Bundle.main.url(forResource: fn, withExtension: "wav"),
           let data = try? Data(contentsOf: url) {
            soundData[type] = data
            print("Loaded bundled \(fn): \(data.count) bytes")
        }
    }
    
    func play(_ type: BellType) {
        guard let data = soundData[type] else {
            DispatchQueue.main.async { NSSound.beep() }
            return
        }
        do {
            let player = try AVAudioPlayer(data: data)
            player.volume = 1.0
            player.prepareToPlay()
            player.play()
            // Keep reference until done; use real duration + buffer
            let duration = player.duration + 5.0
            activePlayers.append(player)
            DispatchQueue.global().asyncAfter(deadline: .now() + duration) { [weak self] in
                self?.activePlayers.removeAll { $0 === player }
            }
            print("Playing \(type): \(data.count) bytes, duration=\(player.duration)s")
        } catch {
            print("AudioService error: \(error)")
            DispatchQueue.main.async { NSSound.beep() }
        }
    }
    
    deinit { NotificationCenter.default.removeObserver(self) }
}
