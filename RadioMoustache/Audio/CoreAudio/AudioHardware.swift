import CoreAudio

/// Photo de l'état du matériel audio à un instant donné.
struct AudioHardwareSnapshot: Equatable, Sendable {
    var devices: [AudioDevice]
    var defaultInputUID: String?
    var defaultOutputUID: String?
}

/// Changement signalé par le HAL : branchement, débranchement, périphérique par défaut…
enum AudioHardwareEvent: Equatable, Sendable {
    case devicesChanged
    case defaultInputChanged
    case defaultOutputChanged
}

/// Source du matériel audio, abstraite pour pouvoir tester sans vrai périphérique.
protocol AudioHardwareProviding: Sendable {
    func snapshot() throws -> AudioHardwareSnapshot
    /// Flux des changements matériels ; l'écoute s'arrête quand le flux est abandonné.
    func events() -> AsyncStream<AudioHardwareEvent>
}

/// Implémentation réelle, adossée au HAL Core Audio.
struct CoreAudioHardware: AudioHardwareProviding {
    func snapshot() throws -> AudioHardwareSnapshot {
        let ids = try HAL.array(HAL.systemObject, HAL.property(kAudioHardwarePropertyDevices), of: AudioObjectID.self)
        // Un périphérique peut disparaître pendant sa lecture : il est simplement ignoré.
        let devices = ids.compactMap { try? AudioDeviceReader.read($0) }
        return AudioHardwareSnapshot(
            devices: devices,
            defaultInputUID: defaultDeviceUID(kAudioHardwarePropertyDefaultInputDevice, in: devices),
            defaultOutputUID: defaultDeviceUID(kAudioHardwarePropertyDefaultOutputDevice, in: devices)
        )
    }

    func events() -> AsyncStream<AudioHardwareEvent> {
        AsyncStream(bufferingPolicy: .bufferingNewest(8)) { continuation in
            let observer = HardwareObserver { event in
                continuation.yield(event)
            }
            do {
                try observer.start()
            } catch {
                continuation.finish()
                return
            }
            continuation.onTermination = { _ in
                observer.stop()
            }
        }
    }

    private func defaultDeviceUID(_ selector: AudioObjectPropertySelector, in devices: [AudioDevice]) -> String? {
        let unknown = AudioObjectID(kAudioObjectUnknown)
        guard
            let id = try? HAL.value(HAL.systemObject, HAL.property(selector), default: unknown),
            id != unknown
        else { return nil }
        return devices.first { $0.objectID == id }?.uid
    }
}
