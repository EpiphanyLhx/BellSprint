import AVFoundation
import CoreAudio
import AppKit
import Combine

final class AudioService: ObservableObject {
    static let shared = AudioService()
    
    @Published var volume: Float {
        didSet { UserDefaults.standard.set(volume, forKey: "audio_volume") }
    }
    @Published var selectedDeviceUID: String {
        didSet { UserDefaults.standard.set(selectedDeviceUID, forKey: "audio_device_uid") }
    }
    @Published var availableDevices: [OutputDevice] = []
    
    struct OutputDevice: Identifiable, Equatable {
        let id: String // UID
        let name: String
        var isBuiltIn: Bool
    }
    
    private init() {
        let savedVolume = UserDefaults.standard.float(forKey: "audio_volume")
        volume = (savedVolume > 0 && savedVolume <= 1) ? savedVolume : 1.0
        selectedDeviceUID = UserDefaults.standard.string(forKey: "audio_device_uid") ?? ""
        availableDevices = AudioService.enumerateOutputDevices()
        // 如果保存的设备已不存在，回退到内置扬声器
        if !selectedDeviceUID.isEmpty, !availableDevices.contains(where: { $0.id == selectedDeviceUID }) {
            selectedDeviceUID = ""
        }
        loadAllSounds()
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: NSNotification.Name("CustomSoundChanged"), object: nil)
    }
    
    @objc private func reload() { loadAllSounds() }
    
    // MARK: - Sound Data
    
    private var soundData: [BellType: Data] = [:]
    private var engines: [AVAudioEngine] = []
    
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
        if let p = UserDefaults.standard.string(forKey: key), !p.isEmpty,
           let data = try? Data(contentsOf: URL(fileURLWithPath: p)) {
            soundData[type] = data; return
        }
        if let url = Bundle.module.url(forResource: fn, withExtension: "wav")
           ?? Bundle.main.url(forResource: fn, withExtension: "wav"),
           let data = try? Data(contentsOf: url) {
            soundData[type] = data
        }
    }
    
    // MARK: - Playback
    
    func play(_ type: BellType) {
        guard let data = soundData[type] else {
            DispatchQueue.main.async { NSSound.beep() }
            return
        }
        
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID().uuidString).wav")
        try? data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        do {
            let audioFile = try AVAudioFile(forReading: tempURL)
            let format = audioFile.processingFormat
            let capacity = UInt32(audioFile.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
                fallback(data); return
            }
            try audioFile.read(into: buffer)
            
            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            engine.attach(player)
            
            // Set output device
            let targetDeviceID: AudioDeviceID?
            if !selectedDeviceUID.isEmpty {
                targetDeviceID = getDeviceID(byUID: selectedDeviceUID)
            } else {
                targetDeviceID = getBuiltInOutputDeviceID()
            }
            if let devId = targetDeviceID, let audioUnit = engine.outputNode.audioUnit {
                var d = devId
                AudioUnitSetProperty(audioUnit,
                    kAudioOutputUnitProperty_CurrentDevice,
                    kAudioUnitScope_Global, 0, &d, UInt32(MemoryLayout<AudioDeviceID>.size))
            }
            
            engine.connect(player, to: engine.mainMixerNode, format: format)
            engine.prepare()
            try engine.start()
            
            player.scheduleBuffer(buffer, at: nil, options: .interruptsAtLoop) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    engine.stop()
                    self.engines.removeAll { $0 === engine }
                }
            }
            player.volume = volume
            player.play()
            engines.append(engine)
        } catch {
            print("AudioService error: \(error)")
            fallback(data)
        }
    }
    
    private func fallback(_ data: Data) {
        do {
            let player = try AVAudioPlayer(data: data)
            player.volume = volume; player.prepareToPlay(); player.play()
        } catch {
            DispatchQueue.main.async { NSSound.beep() }
        }
    }
    
    // MARK: - CoreAudio Helpers
    
    static func enumerateOutputDevices() -> [OutputDevice] {
        var propAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propAddr, 0, nil, &dataSize) == noErr else { return [] }
        
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propAddr, 0, nil, &dataSize, &devices) == noErr else { return [] }
        
        var result: [OutputDevice] = []
        for deviceID in devices {
            // Must have output streams
            var streamProp = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            AudioObjectGetPropertyDataSize(deviceID, &streamProp, 0, nil, &streamSize)
            guard streamSize > 0 else { continue }
            
            let name = getDeviceName(deviceID)
            let uid = getDeviceUID(deviceID)
            let builtIn = isBuiltInDevice(deviceID)
            
            result.append(OutputDevice(id: uid, name: name, isBuiltIn: builtIn))
        }
        return result
    }
    
    private static func getDeviceName(_ deviceID: AudioDeviceID) -> String {
        var nameProp = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString? = nil
        var nameSize = UInt32(MemoryLayout<CFString?>.size)
        AudioObjectGetPropertyData(deviceID, &nameProp, 0, nil, &nameSize, &name)
        return (name as String?) ?? "未知设备"
    }
    
    private static func getDeviceUID(_ deviceID: AudioDeviceID) -> String {
        var uidProp = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: CFString? = nil
        var uidSize = UInt32(MemoryLayout<CFString?>.size)
        AudioObjectGetPropertyData(deviceID, &uidProp, 0, nil, &uidSize, &uid)
        return (uid as String?) ?? ""
    }
    
    private static func isBuiltInDevice(_ deviceID: AudioDeviceID) -> Bool {
        var transportProp = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transportType: UInt32 = 0
        var transportSize = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &transportProp, 0, nil, &transportSize, &transportType) == noErr else { return false }
        return transportType == kAudioDeviceTransportTypeBuiltIn
    }
    
    private func getBuiltInOutputDeviceID() -> AudioDeviceID? {
        for device in AudioService.enumerateOutputDevices() {
            if device.isBuiltIn, let id = getDeviceID(byUID: device.id) {
                return id
            }
        }
        return nil
    }
    
    private func getDeviceID(byUID uid: String) -> AudioDeviceID? {
        var propAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propAddr, 0, nil, &dataSize) == noErr else { return nil }
        
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propAddr, 0, nil, &dataSize, &devices) == noErr else { return nil }
        
        for deviceID in devices {
            if AudioService.getDeviceUID(deviceID) == uid {
                return deviceID
            }
        }
        return nil
    }
    
    deinit { NotificationCenter.default.removeObserver(self) }
}
