import Testing
@testable import RadioMoustache

/// Matériel simulé : on modifie `devices`, puis on émet un événement comme le ferait le HAL.
final class MockAudioHardware: AudioHardwareProviding, @unchecked Sendable {
    var devices: [AudioDevice]
    var defaultInputUID: String?
    var defaultOutputUID: String?
    var failure: CoreAudioError?

    private let stream: AsyncStream<AudioHardwareEvent>
    private let continuation: AsyncStream<AudioHardwareEvent>.Continuation

    init(devices: [AudioDevice], defaultInputUID: String? = nil, defaultOutputUID: String? = nil) {
        self.devices = devices
        self.defaultInputUID = defaultInputUID
        self.defaultOutputUID = defaultOutputUID
        let (stream, continuation) = AsyncStream.makeStream(of: AudioHardwareEvent.self)
        self.stream = stream
        self.continuation = continuation
    }

    func snapshot() throws -> AudioHardwareSnapshot {
        if let failure { throw failure }
        return AudioHardwareSnapshot(
            devices: devices,
            defaultInputUID: defaultInputUID,
            defaultOutputUID: defaultOutputUID
        )
    }

    func events() -> AsyncStream<AudioHardwareEvent> {
        stream
    }

    func emit(_ event: AudioHardwareEvent) {
        continuation.yield(event)
    }
}

/// Mémoire de session en RAM.
final class InMemorySessionConfigStore: SessionConfigStore {
    var saved: DeviceSelection?

    init(saved: DeviceSelection? = nil) {
        self.saved = saved
    }

    func loadLastSelection() -> DeviceSelection? {
        saved
    }

    func saveLastSelection(_ selection: DeviceSelection) {
        saved = selection
    }
}

/// Attend qu'une condition devienne vraie (événements matériels asynchrones), dans la limite de `timeout`.
@MainActor
func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !condition() {
        guard clock.now < deadline else {
            Issue.record("Délai dépassé en attendant la condition")
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}
