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
    var logbook: LogbookEntry?

    init(saved: DeviceSelection? = nil, logbook: LogbookEntry? = nil) {
        self.saved = saved
        self.logbook = logbook
    }

    func loadLastSelection() -> DeviceSelection? {
        saved
    }

    func saveLastSelection(_ selection: DeviceSelection) {
        saved = selection
    }

    func loadLogbookEntry() -> LogbookEntry? {
        logbook
    }

    func saveLogbookEntry(_ entry: LogbookEntry) {
        logbook = entry
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

/// Œil magique simulé : note les démarrages et les arrêts.
@MainActor
final class RecordingLevelMonitor: InputLevelMonitoring {
    var level: Double = 0
    var status: InputLevelStatus = .stopped
    private(set) var startedUIDs: [String] = []
    private(set) var startedChannels: [InputChannelSelection] = []
    private(set) var stopCount = 0

    func start(deviceUID: String, deviceName: String, channels: InputChannelSelection) {
        startedUIDs.append(deviceUID)
        startedChannels.append(channels)
        status = .running
    }

    func stop() {
        stopCount += 1
        status = .stopped
    }
}

/// Bruitages simulés : note ce qui est joué et où.
@MainActor
final class RecordingInterfaceSounds: InterfaceSoundPlaying {
    private(set) var played: [InterfaceSound] = []
    private(set) var routedDeviceUID: String?
    private(set) var routeCount = 0

    func route(toDeviceUID uid: String?) {
        routedDeviceUID = uid
        routeCount += 1
    }

    func play(_ sound: InterfaceSound) {
        played.append(sound)
    }

    func count(of sound: InterfaceSound) -> Int {
        played.filter { $0 == sound }.count
    }
}

/// Sons d'essai simulés : note la sortie visée, peut échouer sur demande.
@MainActor
final class RecordingTestSignals: TestSignalPlaying {
    struct Failure: Error {}

    private(set) var targets: [TestTarget] = []
    private(set) var deviceUIDs: [String] = []
    private(set) var stopCount = 0
    var shouldFail = false

    func play(_ target: TestTarget, onDeviceUID uid: String) async throws -> Duration {
        targets.append(target)
        deviceUIDs.append(uid)
        if shouldFail { throw Failure() }
        return .zero
    }

    func stop() {
        stopCount += 1
    }
}
