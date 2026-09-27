import CoreAudio
import Foundation

/// Écoute les propriétés globales du HAL (liste des périphériques, périphériques par défaut)
/// et relaie chaque changement. Les blocs d'écoute sont appelés sur une file série privée.
final class HardwareObserver: @unchecked Sendable {
    private struct Registration {
        var address: AudioObjectPropertyAddress
        let block: AudioObjectPropertyListenerBlock
    }

    private static let watchedProperties: [(AudioObjectPropertySelector, AudioHardwareEvent)] = [
        (kAudioHardwarePropertyDevices, .devicesChanged),
        (kAudioHardwarePropertyDefaultInputDevice, .defaultInputChanged),
        (kAudioHardwarePropertyDefaultOutputDevice, .defaultOutputChanged),
    ]

    private let queue = DispatchQueue(label: "com.skemedia.RadioMoustache.hardware-observer")
    private let handler: @Sendable (AudioHardwareEvent) -> Void
    // Protège `registrations` : start() et stop() peuvent être appelés depuis des threads différents.
    private let lock = NSLock()
    private var registrations: [Registration] = []

    init(handler: @escaping @Sendable (AudioHardwareEvent) -> Void) {
        self.handler = handler
    }

    func start() throws {
        lock.lock()
        defer { lock.unlock() }
        guard registrations.isEmpty else { return }

        for (selector, event) in Self.watchedProperties {
            var address = HAL.property(selector)
            let handler = self.handler
            let block: AudioObjectPropertyListenerBlock = { _, _ in handler(event) }
            let status = AudioObjectAddPropertyListenerBlock(HAL.systemObject, &address, queue, block)
            guard status == kAudioHardwareNoError else {
                removeAllRegistrations()
                throw CoreAudioError(status: status, operation: "Écoute du matériel audio")
            }
            registrations.append(Registration(address: address, block: block))
        }
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        removeAllRegistrations()
    }

    /// À appeler avec le verrou tenu.
    private func removeAllRegistrations() {
        for var registration in registrations {
            _ = AudioObjectRemovePropertyListenerBlock(HAL.systemObject, &registration.address, queue, registration.block)
        }
        registrations.removeAll()
    }
}
