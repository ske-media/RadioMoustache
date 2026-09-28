import Testing
@testable import RadioMoustache

/// Écran de préparation branché sur du matériel, un œil magique, des bruitages et des sons d'essai simulés.
@MainActor
private struct Harness {
    let flow: SetupFlow
    let audio: AudioManager
    let hardware: MockAudioHardware
    let store: InMemorySessionConfigStore
    let meter = RecordingLevelMonitor()
    let sounds = RecordingInterfaceSounds()
    let testSignals = RecordingTestSignals()

    init(
        devices: [AudioDevice] = Fixtures.all,
        defaultInput: String? = Fixtures.usbMic.uid,
        saved: DeviceSelection? = nil,
        timing: SetupFlow.Timing = .instant
    ) {
        hardware = MockAudioHardware(
            devices: devices,
            defaultInputUID: defaultInput,
            defaultOutputUID: Fixtures.builtInSpeakers.uid
        )
        store = InMemorySessionConfigStore(saved: saved)
        audio = AudioManager(hardware: hardware, store: store, refreshDelay: .zero)
        audio.refreshDevices()
        flow = SetupFlow(
            audio: audio,
            services: SetupServices(meter: meter, sounds: sounds, testSignals: testSignals),
            timing: timing
        )
    }

    /// Allume le moniteur comme au lancement et attend la première étape.
    func startAndWait() async throws {
        flow.startAutomatically()
        try await waitUntil { flow.power == .ready }
    }

    /// Avance jusqu'au récapitulatif avec Entrée.
    func goToReview() {
        for _ in SetupStep.allCases {
            guard flow.step != .review else { return }
            flow.handle(.confirm)
        }
    }
}

/// Sélection de la dernière émission : interface audio, enceinte Bluetooth et casque filaire.
private let lastBroadcast: DeviceSelection = {
    var saved = DeviceSelection()
    saved.inputUID = Fixtures.interface.uid
    saved.mainOutputUID = Fixtures.bluetoothSpeaker.uid
    saved.monitorOutputUID = Fixtures.wiredHeadphones.uid
    return saved
}()

@MainActor
struct SetupFlowTests {
    // MARK: - Allumage

    @Test func monitorSwitchesItselfOnOnceTheDevicesAreKnown() async throws {
        let harness = Harness()

        harness.flow.startAutomatically()
        #expect(harness.flow.power == .booting)
        #expect(harness.flow.powerOnCount == 1)
        #expect(harness.sounds.played.prefix(2) == [.lever, .sparks])
        #expect(harness.meter.startedUIDs == [Fixtures.usbMic.uid])

        try await waitUntil { harness.flow.power == .ready }
        #expect(harness.flow.visibleBootLineCount == harness.flow.bootLines.count)
        #expect(harness.flow.bootLines.last == BootScript.dotted("MATÉRIEL AUDIO", "8 TROUVÉS"))
        #expect(harness.sounds.count(of: .crtPowerOn) == 1)
        #expect(harness.flow.step == .microphone)
        #expect(harness.flow.question == "DANS QUEL MICRO PARLES-TU ?")

        // Une seule fois par lancement : éteint à la main, il reste éteint.
        harness.flow.togglePower()
        harness.flow.startAutomatically()
        #expect(harness.flow.power == .off)
        #expect(harness.flow.powerOnCount == 1)
    }

    @Test func monitorWaitsForTheDeviceList() {
        let hardware = MockAudioHardware(devices: Fixtures.all)
        let audio = AudioManager(hardware: hardware, store: InMemorySessionConfigStore(), refreshDelay: .zero)
        let flow = SetupFlow(
            audio: audio,
            services: SetupServices(meter: RecordingLevelMonitor(), sounds: RecordingInterfaceSounds(), testSignals: RecordingTestSignals()),
            timing: .instant
        )

        flow.startAutomatically()
        #expect(flow.power == .off)

        audio.refreshDevices()
        flow.startAutomatically()
        #expect(flow.power == .booting)
    }

    @Test func bootSequenceTakesLessThanTwoSeconds() {
        let timing = SetupFlow.Timing.standard
        let lineCount = BootScript.lines(deviceCount: 3).count
        let total = timing.humDelay + timing.firstLineDelay + timing.lineInterval * lineCount + timing.readyDelay

        #expect(total < .seconds(2))
    }

    @Test func returnKeySkipsTheBootThenLeverWorksAgain() {
        let harness = Harness(timing: .standard)

        harness.flow.startAutomatically()
        #expect(harness.flow.handle(.confirm))
        #expect(harness.flow.power == .ready)
        #expect(harness.flow.visibleBootLineCount == 6)

        harness.flow.togglePower()
        #expect(harness.flow.power == .off)
        #expect(harness.flow.handle(.confirm))
        #expect(harness.flow.power == .booting)
    }

    @Test func sameHardwareAsLastTimeOpensOnTheRecap() async throws {
        let harness = Harness(saved: lastBroadcast)

        try await harness.startAndWait()

        #expect(harness.flow.step == .review)
        #expect(harness.flow.furthestStep == .review)
        #expect(harness.flow.question == "MÊME MATÉRIEL QUE LA DERNIÈRE FOIS ?")
        #expect(harness.flow.canGoLive)

        // Un changement, et ce n'est plus le même matériel.
        harness.flow.goTo(.monitorOutput)
        harness.flow.choose(at: 0)
        harness.flow.goTo(.review)
        #expect(harness.flow.question == "TOUT EST PRÊT ?")
    }

    @Test func missingLastHardwareStartsAtTheFirstQuestion() async throws {
        var saved = lastBroadcast
        saved.inputUID = "micro-disparu"
        let harness = Harness(saved: saved)

        try await harness.startAndWait()

        #expect(harness.flow.step == .microphone)
        #expect(harness.flow.furthestStep == .microphone)
    }

    // MARK: - Étapes

    @Test func stepsFollowEachOtherWithNextAndBack() async throws {
        let harness = Harness()
        try await harness.startAndWait()

        #expect(harness.flow.handle(.confirm))
        #expect(harness.flow.step == .mainOutput)
        #expect(harness.flow.question == "OÙ ÉCOUTE LE PUBLIC ?")
        #expect(harness.flow.handle(.right))
        #expect(harness.flow.step == .monitorOutput)
        #expect(harness.flow.question == "ET DANS TES OREILLES ?")
        harness.flow.next()
        #expect(harness.flow.step == .review)
        #expect(harness.flow.question == "TOUT EST PRÊT ?")
        // La flèche → ne part pas à l'antenne.
        #expect(!harness.flow.handle(.right))
        #expect(harness.flow.confirmedSession == nil)

        #expect(harness.flow.handle(.cancel))
        #expect(harness.flow.step == .monitorOutput)
        #expect(harness.flow.handle(.left))
        #expect(harness.flow.step == .mainOutput)
        #expect(harness.flow.back())
        #expect(harness.flow.step == .microphone)
        // Rien avant la première étape.
        #expect(!harness.flow.handle(.cancel))
        #expect(harness.flow.furthestStep == .review)
    }

    @Test func onlyReachedStepsOpenFromTheTabs() async throws {
        let harness = Harness()
        try await harness.startAndWait()

        harness.flow.goTo(.review)
        #expect(harness.flow.step == .microphone)
        #expect(!harness.flow.isReachable(.mainOutput))

        harness.flow.next()
        harness.flow.goTo(.microphone)
        #expect(harness.flow.step == .microphone)
        #expect(harness.flow.isReachable(.mainOutput))
        harness.flow.goTo(.mainOutput)
        #expect(harness.flow.step == .mainOutput)
    }

    @Test func nextIsRefusedUntilTheStepIsSettled() async throws {
        let harness = Harness(devices: [Fixtures.builtInSpeakers], defaultInput: nil)
        try await harness.startAndWait()

        #expect(!harness.flow.canGoNext)
        #expect(harness.flow.needsAttention(.microphone))
        #expect(harness.flow.options.isEmpty)

        harness.flow.handle(.confirm)

        #expect(harness.flow.step == .microphone)
        #expect(harness.flow.alertMessage == "!! CHOISIS UN MICRO")
        #expect(harness.flow.statusLines == ["!! CHOISIS UN MICRO"])
        #expect(harness.sounds.played.last == .menuBlip)
    }

    // MARK: - Choix

    @Test func arrowKeysTakeTheNeighbouringMicrophoneStraightAway() async throws {
        let harness = Harness()
        try await harness.startAndWait()
        // Micros par ordre alphabétique : AirPods Pro, Micro MacBook Pro, Scarlett 2i2, Shure MV7 (choisi).
        let choices = harness.flow.options.map(\.choice)
        #expect(choices.last == .microphone(uid: Fixtures.usbMic.uid))

        harness.flow.handle(.up)

        #expect(harness.audio.selection.inputUID == Fixtures.interface.uid)
        // L'œil magique écoute aussitôt le nouveau micro.
        #expect(harness.meter.startedUIDs.last == Fixtures.interface.uid)
        #expect(harness.sounds.played.last == .typewriterTick)

        // Au bout de la liste, la flèche ne fait plus rien.
        harness.flow.handle(.down)
        let ticks = harness.sounds.count(of: .typewriterTick)
        harness.flow.handle(.down)
        #expect(harness.audio.selection.inputUID == Fixtures.usbMic.uid)
        #expect(harness.sounds.count(of: .typewriterTick) == ticks)
    }

    @Test func clickingADeviceTakesIt() async throws {
        let harness = Harness()
        try await harness.startAndWait()
        harness.flow.next()

        let speakerIndex = harness.flow.options.firstIndex { $0.choice == .mainOutput(uid: Fixtures.bluetoothSpeaker.uid) }
        harness.flow.choose(at: try #require(speakerIndex))

        #expect(harness.audio.selection.mainOutputUID == Fixtures.bluetoothSpeaker.uid)
        #expect(harness.flow.statusLines.contains(SetupIssue.highLatencyOutput(.mainOutput, .bluetooth).screenMessage))
    }

    @Test func headphoneStepOffersNoneFirst() async throws {
        let harness = Harness()
        try await harness.startAndWait()
        harness.audio.selectMonitorOutput(uid: Fixtures.wiredHeadphones.uid)
        harness.flow.next()
        harness.flow.next()

        #expect(harness.flow.options.first?.choice == .monitorOutput(uid: nil))
        harness.flow.choose(at: 0)

        #expect(harness.audio.selection.monitorOutputUID == nil)
        #expect(harness.flow.canGoNext)
    }

    @Test func warningsOnlyConcernTheStepOnScreen() async throws {
        let harness = Harness()
        try await harness.startAndWait()
        harness.audio.selectInput(uid: Fixtures.builtInMic.uid)
        harness.audio.selectMainOutput(uid: Fixtures.bluetoothSpeaker.uid)
        let micWarning = SetupIssue.builtInMicrophone.screenMessage
        let speakerWarning = SetupIssue.highLatencyOutput(.mainOutput, .bluetooth).screenMessage

        #expect(harness.flow.warningLines == [micWarning])
        harness.flow.next()
        #expect(harness.flow.warningLines == [speakerWarning])
        harness.flow.next()
        #expect(harness.flow.warningLines.isEmpty)
        harness.flow.next()
        #expect(harness.flow.warningLines == [micWarning, speakerWarning])
    }

    @Test func unpluggedStepIsFlaggedOnItsTab() async throws {
        let harness = Harness()
        try await harness.startAndWait()
        harness.audio.selectMainOutput(uid: Fixtures.bluetoothSpeaker.uid)
        harness.goToReview()

        harness.hardware.devices.removeAll { $0 == Fixtures.bluetoothSpeaker }
        harness.audio.refreshDevices()

        #expect(harness.flow.needsAttention(.mainOutput))
        #expect(!harness.flow.needsAttention(.microphone))
        #expect(!harness.flow.canGoLive)
        let recap = harness.flow.recapLines[1]
        #expect(recap.isAlert)
        #expect(recap.text == "2 ENCEINTE .. JBL FLIP · DÉBRANCHÉ")
    }

    // MARK: - Réglages avancés

    @Test func channelSettingIsOfferedOnlyForMultiInputMicrophones() async throws {
        let harness = Harness()
        try await harness.startAndWait()
        #expect(harness.flow.availableAdvancedList == nil)

        harness.audio.selectInput(uid: Fixtures.interface.uid)
        #expect(harness.flow.availableAdvancedList == .channel)

        harness.flow.openAdvancedSettings()
        #expect(harness.flow.visibleList == .channel)
        #expect(harness.flow.question == "SUR QUELLE ENTRÉE EST LE MICRO ?")
        harness.flow.handle(.down)
        #expect(harness.audio.selection.inputChannels == .mono(1))
        #expect(harness.meter.startedChannels.last == .mono(1))

        harness.flow.handle(.confirm)
        #expect(harness.flow.advancedList == nil)
        #expect(harness.flow.step == .microphone)
    }

    @Test func latencyIsTheAdvancedSettingOfTheRecap() async throws {
        let harness = Harness(saved: lastBroadcast)
        try await harness.startAndWait()

        harness.flow.openAdvancedSettings()
        #expect(harness.flow.visibleList == .latency)
        let texts = harness.flow.options.map(\.text)
        #expect(texts.contains("256 ÉCHANTILLONS (5,3 MS)"))

        harness.flow.handle(.cancel)
        #expect(harness.flow.advancedList == nil)
        #expect(harness.flow.step == .review)
    }

    // MARK: - Sons d'essai

    @Test func speakerTestPlaysOnTheMainOutput() async throws {
        let harness = Harness()
        try await harness.startAndWait()
        harness.flow.next()

        harness.flow.handle(.space)
        #expect(harness.flow.testingTarget == .mainOutput)
        #expect(harness.flow.testMessage == "» ESSAI ENVOYÉ SUR HAUT-PARLEURS MACBOOK PRO")

        try await waitUntil { harness.flow.testingTarget == nil }
        #expect(harness.testSignals.deviceUIDs == [Fixtures.builtInSpeakers.uid])
        #expect(harness.testSignals.targets == [.mainOutput])
    }

    @Test func headphoneTestWithoutHeadphonesSaysSo() async throws {
        let harness = Harness()
        try await harness.startAndWait()

        harness.flow.test(.monitorOutput)

        #expect(harness.flow.testMessage == "» AUCUN CASQUE CHOISI")
        #expect(harness.flow.testingTarget == nil)
        #expect(harness.testSignals.targets.isEmpty)
    }

    @Test func failedTestIsReported() async throws {
        let harness = Harness()
        try await harness.startAndWait()
        harness.flow.next()
        harness.testSignals.shouldFail = true

        harness.flow.testCurrentOutput()

        try await waitUntil { harness.flow.testingTarget == nil }
        #expect(harness.flow.testMessage == "» ESSAI IMPOSSIBLE SUR HAUT-PARLEURS MACBOOK PRO")
    }

    @Test func leavingTheStepStopsTheTest() async throws {
        let harness = Harness(timing: .instant)
        try await harness.startAndWait()
        harness.flow.next()
        harness.flow.testCurrentOutput()
        #expect(harness.flow.testingTarget == .mainOutput)

        harness.flow.next()

        #expect(harness.flow.testingTarget == nil)
        #expect(harness.flow.testMessage == nil)
        #expect(harness.testSignals.stopCount == 1)
    }

    // MARK: - Validation

    @Test func goLiveSavesTheSessionAndLeavesTheMicrophone() async throws {
        let harness = Harness()
        try await harness.startAndWait()
        harness.goToReview()

        harness.flow.handle(.confirm)

        let session = try #require(harness.flow.confirmedSession)
        #expect(session.input == Fixtures.usbMic)
        #expect(harness.store.saved == harness.audio.selection)
        #expect(harness.store.logbook?.microphone == Fixtures.usbMic.name)
        #expect(harness.sounds.played.last == .goLive)
        #expect(harness.meter.stopCount == 1)

        harness.flow.backToSetup()
        #expect(harness.flow.confirmedSession == nil)
        #expect(harness.flow.step == .review)
        #expect(harness.meter.startedUIDs.count == 2)
    }

    @Test func goLiveIsRefusedWhileSomethingIsMissing() async throws {
        let harness = Harness()
        try await harness.startAndWait()
        harness.goToReview()
        harness.hardware.devices.removeAll { $0 == Fixtures.builtInSpeakers }
        harness.audio.refreshDevices()

        harness.flow.handle(.confirm)

        #expect(harness.flow.confirmedSession == nil)
        #expect(!harness.flow.canGoLive)
        let alert = try #require(harness.flow.alertMessage)
        #expect(harness.flow.statusLines.first == alert)
        #expect(harness.flow.statusLines.count == SetupFlow.statusCapacity)
        #expect(harness.store.saved == nil)
    }

    @Test func switchingOffResetsTheScreenAndStopsTheEye() async throws {
        let harness = Harness(saved: lastBroadcast)
        try await harness.startAndWait()
        harness.flow.openAdvancedSettings()

        harness.flow.togglePower()

        #expect(harness.flow.power == .off)
        #expect(harness.flow.advancedList == nil)
        #expect(harness.flow.visibleBootLineCount == 0)
        #expect(harness.meter.stopCount == 1)

        // Rallumé, le moniteur reprend où il en était.
        harness.flow.togglePower()
        try await waitUntil { harness.flow.power == .ready }
        #expect(harness.flow.step == .review)
    }

    // MARK: - Matériel

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
        try await harness.startAndWait()

        harness.meter.status = .denied
        #expect(harness.flow.warningLines.last == harness.flow.meterWarning)
        #expect(harness.flow.meterWarning != nil)
        #expect(harness.flow.levelHint == "RIEN !")

        harness.meter.status = .muted
        #expect(harness.flow.meterWarning == "! MICRO MUET : VÉRIFIE L'AUTORISATION MICRO")

        harness.meter.status = .noSignal
        #expect(harness.flow.meterWarning == "! ŒIL MAGIQUE : RIEN NE VIENT DU MICRO")

        // L'œil ne concerne pas les sorties.
        harness.flow.next()
        #expect(harness.flow.warningLines.isEmpty)
    }
}
