import AVFoundation
import CoreAudio
import AppKit

final class AudioService {
    private var soundData: [BellType: Data] = [:]
    private var engines: [AVAudioEngine] = []
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
        if let p = defaults.string(forKey: key), !p.isEmpty,
           let data = try? Data(contentsOf: URL(fileURLWithPath: p)) {
            soundData[type] = data; return
        }
        if let url = Bundle.module.url(forResource: fn, withExtension: "wav")
           ?? Bundle.main.url(forResource: fn, withExtension: "wav"),
           let data = try? Data(contentsOf: url) {
            soundData[type] = data
        }
    }
    
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
            
            // Route output to built-in speakers
            if let deviceID = getBuiltInOutputDeviceID(), let audioUnit = engine.outputNode.audioUnit {
                var devId = deviceID
                AudioUnitSetProperty(audioUnit,
                    kAudioOutputUnitProperty_CurrentDevice,
                    kAudioUnitScope_Global, 0, &devId, UInt32(MemoryLayout<AudioDeviceID>.size))
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
            player.volume = 1.0
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
            player.volume = 1.0; player.prepareToPlay(); player.play()
        } catch {
            DispatchQueue.main.async { NSSound.beep() }
        }
    }
    
    private func getBuiltInOutputDeviceID() -> AudioDeviceID? {
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
            // Must have output streams
            var streamProp = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            AudioObjectGetPropertyDataSize(deviceID, &streamProp, 0, nil, &streamSize)
            guard streamSize > 0 else { continue }
            
            // Must be a built-in device
            var transportType: UInt32 = 0
            var transportProp = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var transportSize = UInt32(MemoryLayout<UInt32>.size)
            AudioObjectGetPropertyData(deviceID, &transportProp, 0, nil, &transportSize, &transportType)
            
            if transportType == kAudioDeviceTransportTypeBuiltIn {
                return deviceID
            }
        }
        return nil
    }
    
    deinit { NotificationCenter.default.removeObserver(self) }
}
