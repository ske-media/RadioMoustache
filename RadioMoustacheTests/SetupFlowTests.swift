import Testing
@testable import RadioMoustache

/// Écran de préparation branché sur du matériel, un œil magique, des bruitages et des sons d'essai simulés.
@MainActor
private struct Harness {
    let flow: SetupFlow
    let audio: AudioManager
    let store: InMemorySessionConfigStore
    let meter = RecordingLevelMonitor()
    let sounds = RecordingInterfaceSounds()
    let testSignals = RecordingTestSignals()

    init(
        devices: [AudioDevice] = Fixtures.all,
        defaultInput: String? = Fixtures.usbMic.uid,
        timing: SetupFlow.Timing = .instant
    ) {
        let hardware = MockAudioHardware(
            devices: devices,
            defaultInputUID: defaultInput,
            defaultOutputUID: Fixtures.builtInSpeakers.uid
        )
        store = InMemorySessionConfigStore()
        audio = AudioManager(hardware: hardware, store: store, refreshDelay: .zero)
        audio.refreshDevices()
        flow = SetupFlow(
            audio: audio,
            services: SetupServices(meter: meter, sounds: sounds, testSignals: testSignals),
            timing: timing
        )
    }

    /// Met sous tension et attend la fin de la séquence de démarrage.
    func powerOnAndWait() async throws {
        flow.togglePower()
        try await waitUntil { flow.power == .ready }
    }
}

@MainActor
struct SetupFlowTests {
    @Test func startsSwitchedOffAndIgnoresTheMenuKeys() {
        let harness = Harness()

        #expect(harness.flow.power == .off)
        #expect(!harness.flow.handle(.down))
        #expect(harness.meter.startedUIDs.isEmpty)
    }

    @Test func leverBootsTheMonitorThenShowsTheMenu() async throws {
        let harness = Harness()

        harness.flow.togglePower()
        #expect(harness.flow.power == .booting)
        #expect(harness.flow.powerOnCount == 1)
        #expect(harness.sounds.played.prefix(2) == [.lever, .sparks])
        #expect(harness.meter.startedUIDs == [Fixtures.usbMic.uid])

        try await waitUntil { harness.flow.power == .ready }
        #expect(harness.flow.visibleBootLineCount == harness.flow.bootLines.count)
        #expect(harness.flow.bootLines.last == BootScript.dotted("MATÉRIEL AUDIO", "8 TROUVÉS"))
        #expect(harness.sounds.count(of: .crtPowerOn) == 1)
        #expect(harness.sounds.count(of: .typewriterTick) == 6)
    }

    @Test func returnKeyPullsTheLeverThenSkipsTheBoot() {
        let harness = Harness(timing: .standard)

        #expect(harness.flow.handle(.confirm))
        #expect(harness.flow.power == .booting)

        #expect(harness.flow.handle(.confirm))
        #expect(harness.flow.power == .ready)
        #expect(harness.flow.visibleBootLineCount == 6)
    }

    @Test func arrowKeysMoveTheCursorWithinTheMenu() async throws {
        let harness = Harness()
        try await harness.powerOnAndWait()

        harness.flow.handle(.down)
        #expect(harness.flow.focusedRow == .channel)
        for _ in 0..<3 {
            harness.flow.handle(.up)
        }
        #expect(harness.flow.focusedRow == .microphone)
        for _ in 0..<10 {
            harness.flow.handle(.down)
        }
        #expect(harness.flow.focusedRow == .goLive)
    }

    @Test func returnOpensTheListOnTheCurrentChoiceThenPicksAnother() async throws {
        let harness = Harness()
        try await harness.powerOnAndWait()

        harness.flow.handle(.confirm)
        #expect(harness.flow.openRow == .microphone)
        let options = harness.flow.openOptions
        let currentIndex = options.firstIndex { $0.isCurrent }
        #expect(currentIndex == harness.flow.highlightedOption)

        // Calculé hors des macros : elles ne savent pas décomposer un appel « rethrows » comme firstIndex(where:).
        let interfaceIndex = options.firstIndex { $0.choice == .microphone(uid: Fixtures.interface.uid) }
        let target = try #require(interfaceIndex)
        while harness.flow.highlightedOption < target {
            harness.flow.handle(.down)
        }
        while harness.flow.highlightedOption > target {
            harness.flow.handle(.up)
        }
        harness.flow.handle(.confirm)

        #expect(harness.flow.openRow == nil)
        #expect(harness.audio.selection.inputUID == Fixtures.interface.uid)
        #expect(harness.meter.startedUIDs.last == Fixtures.interface.uid)
    }

    @Test func escapeClosesTheListWithoutChangingAnything() async throws {
        let harness = Harness()
        try await harness.powerOnAndWait()
        let before = harness.audio.selection

        harness.flow.activate(.mainOutput)
        harness.flow.handle(.down)
        harness.flow.handle(.cancel)

        #expect(harness.flow.openRow == nil)
        #expect(harness.audio.selection == before)
    }

    @Test func choosingABluetoothSpeakerShowsItsWarning() async throws {
        let harness = Harness()
        try await harness.powerOnAndWait()

        harness.flow.activate(.mainOutput)
        let speakerIndex = harness.flow.openOptions.firstIndex { $0.choice == .mainOutput(uid: Fixtures.bluetoothSpeaker.uid) }
        harness.flow.chooseOption(at: try #require(speakerIndex))

        #expect(harness.audio.selection.mainOutputUID == Fixtures.bluetoothSpeaker.uid)
        #expect(harness.flow.statusLines.contains(SetupIssue.highLatencyOutput(.mainOutput, .bluetooth).screenMessage))
    }

    @Test func monitorListStartsWithNone() async throws {
        let harness = Harness()
        try await harness.powerOnAndWait()
        harness.audio.selectMonitorOutput(uid: Fixtures.wiredHeadphones.uid)

        harness.flow.activate(.monitorOutput)
        #expect(harness.flow.openOptions.first?.choice == .monitorOutput(uid: nil))
        harness.flow.chooseOption(at: 0)

        #expect(harness.audio.selection.monitorOutputUID == nil)
    }

    @Test func goLiveSavesTheSessionAndLeavesTheMicrophone() async throws {
        let harness = Harness()
        try await harness.powerOnAndWait()

        for _ in 0..<SetupRow.allCases.count {
            harness.flow.handle(.down)
        }
        harness.flow.handle(.confirm)

        let session = try #require(harness.flow.confirmedSession)
        #expect(session.input == Fixtures.usbMic)
        #expect(harness.store.saved == harness.audio.selection)
        #expect(harness.store.logbook?.microphone == Fixtures.usbMic.name)
        #expect(harness.sounds.played.last == .goLive)
        #expect(harness.meter.stopCount == 1)

        harness.flow.backToSetup()
        #expect(harness.flow.confirmedSession == nil)
        #expect(harness.flow.focusedRow == .goLive)
        #expect(harness.meter.startedUIDs.count == 2)
    }

    @Test func goLiveIsRefusedWhileSomethingIsMissing() async throws {
        let harness = Harness(devices: [Fixtures.builtInSpeakers], defaultInput: nil)
        try await harness.powerOnAndWait()

        harness.flow.activate(.goLive)

        #expect(harness.flow.confirmedSession == nil)
        #expect(!harness.flow.canGoLive)
        let alert = try #require(harness.flow.alertMessage)
        #expect(harness.flow.statusLines.first == alert)
        #expect(harness.store.saved == nil)
    }

    @Test func switchingOffResetsTheScreenAndStopsTheEye() async throws {
        let harness = Harness()
        try await harness.powerOnAndWait()
        harness.flow.activate(.latency)

        harness.flow.togglePower()

        #expect(harness.flow.power == .off)
        #expect(harness.flow.openRow == nil)
        #expect(harness.flow.visibleBootLineCount == 0)
        #expect(harness.meter.stopCount == 1)
        #expect(harness.testSignals.stopCount == 1)
    }

    @Test func speakerTestPlaysOnTheMainOutput() async throws {
        let harness = Harness()
        try await harness.powerOnAndWait()

        harness.flow.test(.mainOutput)
        #expect(harness.flow.testingTarget == .mainOutput)
        #expect(harness.flow.testMessage == "» ESSAI ENVOYÉ SUR HAUT-PARLEURS MACBOOK PRO")

        try await waitUntil { harness.flow.testingTarget == nil }
        #expect(harness.testSignals.deviceUIDs == [Fixtures.builtInSpeakers.uid])
        #expect(harness.testSignals.targets == [.mainOutput])
    }

    @Test func headphoneTestWithoutHeadphonesSaysSo() async throws {
        let harness = Harness()
        try await harness.powerOnAndWait()

        harness.flow.test(.monitorOutput)

        #expect(harness.flow.testMessage == "» AUCUN CASQUE CHOISI")
        #expect(harness.flow.testingTarget == nil)
        #expect(harness.testSignals.targets.isEmpty)
    }

    @Test func failedTestIsReported() async throws {
        let harness = Harness()
        try await harness.powerOnAndWait()
        harness.testSignals.shouldFail = true

        harness.flow.test(.mainOutput)

        try await waitUntil { harness.flow.testingTarget == nil }
        #expect(harness.flow.testMessage == "» ESSAI IMPOSSIBLE SUR HAUT-PARLEURS MACBOOK PRO")
    }

    @Test func interfaceSoundsNeverUseTheMainOutput() {
        let harness = Harness()

        // Les haut-parleurs du Mac sont la sortie principale et il n'y a pas de casque : silence.
        harness.flow.syncWithHardware()
        #expect(harness.sounds.routedDeviceUID == nil)

        // Avec un casque, les bruitages y passent.
        harness.audio.selectMonitorOutput(uid: Fixtures.wiredHeadphones.uid)
        harness.flow.syncWithHardware()
        #expect(harness.sounds.routedDeviceUID == Fixtures.wiredHeadphones.uid)

        // Si l'enceinte est ailleurs, les haut-parleurs du Mac sont libres.
        harness.audio.selectMainOutput(uid: Fixtures.bluetoothSpeaker.uid)
        harness.flow.syncWithHardware()
        #expect(harness.sounds.routedDeviceUID == Fixtures.builtInSpeakers.uid)
    }

    @Test func magicEyeWarnsWhenTheMicrophoneIsRefused() async throws {
        let harness = Harness()
        try await harness.powerOnAndWait()

        harness.meter.status = .denied

        #expect(harness.flow.warningLines.last == harness.flow.meterWarning)
        #expect(harness.flow.meterWarning != nil)
    }
}
