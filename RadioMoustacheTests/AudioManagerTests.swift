import CoreAudio
import Foundation
import Testing
@testable import RadioMoustache

@MainActor
struct AudioManagerTests {
    private func makeManager(
        devices: [AudioDevice] = Fixtures.all,
        defaultInput: String? = Fixtures.usbMic.uid,
        defaultOutput: String? = Fixtures.builtInSpeakers.uid,
        saved: DeviceSelection? = nil
    ) -> (manager: AudioManager, hardware: MockAudioHardware, store: InMemorySessionConfigStore) {
        let hardware = MockAudioHardware(devices: devices, defaultInputUID: defaultInput, defaultOutputUID: defaultOutput)
        let store = InMemorySessionConfigStore(saved: saved)
        let manager = AudioManager(hardware: hardware, store: store, refreshDelay: .zero)
        return (manager, hardware, store)
    }

    @Test func startListsUsableDevicesByRole() {
        let (manager, _, _) = makeManager()
        manager.start()
        defer { manager.stop() }

        #expect(manager.hasLoadedDevices)
        #expect(Set(manager.inputDevices) == Set(Fixtures.inputs))
        #expect(Set(manager.outputDevices) == Set(Fixtures.outputs))
        #expect(manager.defaultOutputUID == Fixtures.builtInSpeakers.uid)
    }

    @Test func startPrefillsTheLastSession() {
        var saved = DeviceSelection()
        saved.inputUID = Fixtures.interface.uid
        saved.inputChannels = .mono(1)
        saved.mainOutputUID = Fixtures.bluetoothSpeaker.uid
        saved.monitorOutputUID = Fixtures.wiredHeadphones.uid
        saved.bufferFrameSize = 512
        let (manager, _, _) = makeManager(saved: saved)
        manager.start()
        defer { manager.stop() }

        #expect(manager.selection == saved)
        #expect(manager.canConfirm)
    }

    @Test func choosingTheHeadphonesAsMainOutputClearsTheMonitor() {
        let (manager, _, _) = makeManager()
        manager.start()
        defer { manager.stop() }

        manager.selectMonitorOutput(uid: Fixtures.wiredHeadphones.uid)
        manager.selectMainOutput(uid: Fixtures.wiredHeadphones.uid)

        #expect(manager.selection.mainOutputUID == Fixtures.wiredHeadphones.uid)
        #expect(manager.selection.monitorOutputUID == nil)
        #expect(!manager.monitorCandidates.contains(Fixtures.wiredHeadphones))
    }

    @Test func changingMicrophoneResetsTheInputChannel() {
        let (manager, _, _) = makeManager()
        manager.start()
        defer { manager.stop() }

        manager.selectInput(uid: Fixtures.interface.uid)
        manager.selectInputChannels(.stereo(first: 0))
        #expect(manager.inputChannelOptions.count == 3)

        manager.selectInput(uid: Fixtures.usbMic.uid)
        #expect(manager.selection.inputChannels == .mono(0))
    }

    @Test func confirmingSavesAndReturnsTheSession() throws {
        let (manager, _, store) = makeManager()
        manager.start()
        defer { manager.stop() }

        manager.selectMonitorOutput(uid: Fixtures.wiredHeadphones.uid)
        let session = try manager.confirmSession()

        #expect(session.input == Fixtures.usbMic)
        #expect(session.mainOutput == Fixtures.builtInSpeakers)
        #expect(session.monitorOutput == Fixtures.wiredHeadphones)
        #expect(store.saved == manager.selection)
    }

    @Test func confirmingIsRefusedWhileSomethingIsMissing() {
        let (manager, _, store) = makeManager(devices: [Fixtures.builtInSpeakers], defaultInput: nil)
        manager.start()
        defer { manager.stop() }

        #expect(!manager.canConfirm)
        #expect(throws: SetupError.self) {
            try manager.confirmSession()
        }
        #expect(store.saved == nil)
    }

    @Test func unpluggedDeviceIsFlaggedThenPickedUpAgainAutomatically() async throws {
        let (manager, hardware, _) = makeManager()
        manager.start()
        defer { manager.stop() }
        manager.selectMainOutput(uid: Fixtures.bluetoothSpeaker.uid)

        // L'enceinte Bluetooth décroche…
        hardware.devices.removeAll { $0 == Fixtures.bluetoothSpeaker }
        hardware.emit(.devicesChanged)
        try await waitUntil { manager.issues.contains(.deviceDisconnected(.mainOutput)) }
        #expect(manager.selection.mainOutputUID == Fixtures.bluetoothSpeaker.uid)
        #expect(manager.displayName(forUID: Fixtures.bluetoothSpeaker.uid) == Fixtures.bluetoothSpeaker.name)
        #expect(!manager.canConfirm)

        // … puis revient : elle est reprise sans rien faire.
        hardware.devices.append(Fixtures.bluetoothSpeaker)
        hardware.emit(.devicesChanged)
        try await waitUntil { !manager.issues.contains(.deviceDisconnected(.mainOutput)) }
        #expect(manager.canConfirm)
    }

    @Test func privateAndDeadDevicesAreHidden() {
        let aggregate = AudioDevice.fixture(
            id: 99, uid: AudioDevice.privateUIDPrefix + "agregat", transport: .aggregate,
            inputChannels: 2, outputChannels: 4
        )
        let dead = AudioDevice.fixture(id: 98, uid: "mort", outputChannels: 2, isAlive: false)
        let (manager, _, _) = makeManager(devices: [Fixtures.usbMic, aggregate, dead])

        manager.refreshDevices()

        #expect(manager.allDevices == [Fixtures.usbMic])
    }

    @Test func confirmingWritesTheLogbookPage() throws {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let hardware = MockAudioHardware(
            devices: Fixtures.all,
            defaultInputUID: Fixtures.usbMic.uid,
            defaultOutputUID: Fixtures.builtInSpeakers.uid
        )
        let store = InMemorySessionConfigStore()
        let manager = AudioManager(hardware: hardware, store: store, refreshDelay: .zero, now: { date })
        manager.refreshDevices()
        manager.selectMonitorOutput(uid: Fixtures.wiredHeadphones.uid)

        try manager.confirmSession()

        let expected = LogbookEntry(
            date: date,
            microphone: Fixtures.usbMic.name,
            mainOutput: Fixtures.builtInSpeakers.name,
            monitorOutput: Fixtures.wiredHeadphones.name
        )
        #expect(store.logbook == expected)
        #expect(manager.logbook == expected)
    }

    @Test func theLogbookOfTheLastBroadcastIsReadAtLaunch() {
        let entry = LogbookEntry(date: .now, microphone: "Shure MV7", mainOutput: "JBL Flip", monitorOutput: nil)
        let store = InMemorySessionConfigStore(logbook: entry)

        let manager = AudioManager(hardware: MockAudioHardware(devices: Fixtures.all), store: store, refreshDelay: .zero)

        #expect(manager.logbook == entry)
    }

    @Test func restoredSessionIsReported() {
        var saved = DeviceSelection()
        saved.inputUID = Fixtures.interface.uid
        saved.mainOutputUID = Fixtures.bluetoothSpeaker.uid
        let (manager, _, _) = makeManager(saved: saved)
        manager.refreshDevices()

        #expect(manager.lastSessionRestored)
    }

    @Test func sessionWithAMissingMicrophoneIsNotRestored() {
        var saved = DeviceSelection()
        saved.inputUID = "micro-disparu"
        saved.mainOutputUID = Fixtures.bluetoothSpeaker.uid
        let (manager, _, _) = makeManager(saved: saved)
        manager.refreshDevices()

        #expect(!manager.lastSessionRestored)
        #expect(manager.selection.inputUID == Fixtures.usbMic.uid)
    }

    @Test func hardwareErrorsAreReported() {
        let (manager, hardware, _) = makeManager()
        hardware.failure = CoreAudioError(status: kAudioHardwareUnspecifiedError, operation: "Test")

        manager.refreshDevices()

        #expect(manager.lastErrorMessage != nil)
    }
}
