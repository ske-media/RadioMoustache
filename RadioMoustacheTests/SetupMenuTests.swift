import Foundation
import Testing
@testable import RadioMoustache

@MainActor
struct SetupMenuTests {
    private func makeAudio(devices: [AudioDevice] = Fixtures.all) -> AudioManager {
        let hardware = MockAudioHardware(
            devices: devices,
            defaultInputUID: Fixtures.usbMic.uid,
            defaultOutputUID: Fixtures.builtInSpeakers.uid
        )
        let audio = AudioManager(hardware: hardware, store: InMemorySessionConfigStore(), refreshDelay: .zero)
        audio.refreshDevices()
        return audio
    }

    @Test func linesAlignLabelsDotsAndValues() {
        let lines = SetupMenu.lines(for: makeAudio(), focusedRow: .microphone)
        // Calculé hors de #expect : la macro ne sait pas décomposer un appel « rethrows » comme map.
        let rows = lines.map(\.row)

        #expect(rows == SetupRow.menuRows)
        #expect(lines[0].text == "> MICRO ..... SHURE MV7 · USB ~5 MS")
        #expect(lines[1].text == "  CANAL ..... ENTRÉE 1")
        #expect(lines[2].text == "  ENCEINTE .. HAUT-PARLEURS MACBOOK PRO · INTÉGRÉ ~5 MS")
        #expect(lines[3].text == "  CASQUE .... AUCUN")
        #expect(lines[4].text == "  LATENCE ... 256 ÉCHANTILLONS")
        #expect(lines[0].accessibilityText == "MICRO : SHURE MV7 · USB ~5 MS")
    }

    @Test func unpluggedDeviceIsFlagged() {
        let hardware = MockAudioHardware(devices: Fixtures.all, defaultInputUID: Fixtures.usbMic.uid)
        let audio = AudioManager(hardware: hardware, store: InMemorySessionConfigStore(), refreshDelay: .zero)
        audio.refreshDevices()
        audio.selectMainOutput(uid: Fixtures.bluetoothSpeaker.uid)

        // L'enceinte décroche : elle reste choisie, en attendant son retour.
        hardware.devices.removeAll { $0 == Fixtures.bluetoothSpeaker }
        audio.refreshDevices()
        let value = SetupMenu.value(for: .mainOutput, audio: audio)

        #expect(value.isAlert)
        #expect(value.text == "JBL FLIP · DÉBRANCHÉ")
    }

    @Test func missingMicrophoneMustBeChosen() {
        let audio = makeAudio(devices: [Fixtures.builtInSpeakers])

        let value = SetupMenu.value(for: .microphone, audio: audio)

        #expect(value.text == "À CHOISIR")
        #expect(value.isAlert)
    }

    @Test func optionsMarkTheCurrentChoice() {
        let audio = makeAudio()
        let options = SetupMenu.options(for: .microphone, audio: audio)
        let currentChoices = options.filter(\.isCurrent).map(\.choice)

        #expect(options.count == audio.inputDevices.count)
        #expect(currentChoices == [.microphone(uid: Fixtures.usbMic.uid)])
    }

    @Test func monitorOptionsOfferNoneAndSkipTheMainOutput() {
        let audio = makeAudio()
        let options = SetupMenu.options(for: .monitorOutput, audio: audio)
        let choices = options.map(\.choice)

        #expect(options.first?.text == "AUCUN (PAS DE RETOUR)")
        #expect(options.first?.isCurrent == true)
        #expect(!choices.contains(.monitorOutput(uid: Fixtures.builtInSpeakers.uid)))
        #expect(choices.contains(.monitorOutput(uid: Fixtures.wiredHeadphones.uid)))
    }

    @Test func latencyOptionsShowTheirDuration() {
        let audio = makeAudio()
        let texts = SetupMenu.options(for: .latency, audio: audio).map(\.text)

        #expect(texts.contains("256 ÉCHANTILLONS (5,3 MS)"))
        #expect(texts.contains("64 ÉCHANTILLONS (1,3 MS)"))
    }

    @Test func applyingAChoiceUpdatesTheSelection() {
        let audio = makeAudio()

        SetupMenu.apply(.microphone(uid: Fixtures.interface.uid), to: audio)
        SetupMenu.apply(.channels(.stereo(first: 0)), to: audio)
        SetupMenu.apply(.monitorOutput(uid: Fixtures.wiredHeadphones.uid), to: audio)
        SetupMenu.apply(.bufferFrameSize(128), to: audio)

        #expect(audio.selection.inputUID == Fixtures.interface.uid)
        #expect(audio.selection.inputChannels == .stereo(first: 0))
        #expect(audio.selection.monitorOutputUID == Fixtures.wiredHeadphones.uid)
        #expect(audio.selection.bufferFrameSize == 128)
    }

    @Test func extraAlertsAreSummarised() {
        let lines = ["a", "b", "c", "d"]

        #expect(SetupMenu.limited(lines, to: 3) == ["a", "b", "! ET 2 AUTRES ALERTES"])
        #expect(SetupMenu.limited(lines, to: 4) == lines)
        #expect(SetupMenu.limited(lines, to: 1) == ["a"])
        #expect(SetupMenu.limited(lines, to: 0).isEmpty)
    }

    @Test func longListsScrollAroundTheHighlightedChoice() {
        #expect(SetupMenu.visibleWindow(count: 5, highlighted: 4, capacity: 9) == 0..<5)
        #expect(SetupMenu.visibleWindow(count: 20, highlighted: 0, capacity: 9) == 0..<7)
        #expect(SetupMenu.visibleWindow(count: 20, highlighted: 10, capacity: 9) == 7..<14)
        #expect(SetupMenu.visibleWindow(count: 20, highlighted: 19, capacity: 9) == 13..<20)
    }
}

struct BootScriptTests {
    @Test func valuesLineUpInTheSameColumn() {
        let lines = BootScript.lines(deviceCount: 7)

        #expect(lines.count == 6)
        #expect(lines[1] == "CHAUFFAGE DES LAMPES ........... OK")
        #expect(lines[3] == "POSITION : EAUX INTERNATIONALES  OK")
        #expect(lines[4] == "FRÉQUENCE ...................... 102,4 MHZ")
        #expect(lines[5] == "MATÉRIEL AUDIO ................. 7 TROUVÉS")
    }

    @Test func deviceCountReadsNaturally() {
        #expect(BootScript.deviceCountText(0) == "AUCUN !")
        #expect(BootScript.deviceCountText(1) == "1 TROUVÉ")
        #expect(BootScript.deviceCountText(12) == "12 TROUVÉS")
    }
}

struct LogbookPageTests {
    @Test func firstBroadcastGetsAWelcome() {
        #expect(LogbookPage.lines(for: nil).count == 4)
        #expect(LogbookPage.note(for: nil) == "Bon vent !")
    }

    @Test func lastBroadcastIsTypedOut() {
        let entry = LogbookEntry(date: Date(timeIntervalSince1970: 0), microphone: "Shure MV7", mainOutput: "JBL Flip", monitorOutput: nil)

        let lines = LogbookPage.lines(for: entry)

        #expect(lines.count == 4)
        #expect(lines[0].hasPrefix("Dernière émission, le "))
        #expect(lines[1] == "micro Shure MV7")
        #expect(lines[2] == "enceinte JBL Flip")
        #expect(lines[3] == "sans casque de retour")
        #expect(LogbookPage.note(for: entry) == "On repart !")
    }
}

struct SetupIssueScreenMessageTests {
    private static let all: [SetupIssue] = [
        .missingDevice(.microphone), .missingDevice(.mainOutput), .missingDevice(.monitorOutput),
        .deviceDisconnected(.microphone), .deviceDisconnected(.mainOutput), .deviceDisconnected(.monitorOutput),
        .monitorSameAsMain, .invalidInputChannels,
        .highLatencyOutput(.mainOutput, .bluetooth), .highLatencyOutput(.monitorOutput, .bluetooth),
        .highLatencyOutput(.mainOutput, .airPlay), .bluetoothMicrophone, .builtInMicrophone,
    ]

    @Test(arguments: all)
    func messagesAreShortCapitalsWithTheirSeverity(issue: SetupIssue) {
        let message = issue.screenMessage

        #expect(message == message.screenUppercased)
        #expect(message.hasPrefix(issue.isBlocking ? "!! " : "! "))
        #expect(message.count <= 52)
    }
}
