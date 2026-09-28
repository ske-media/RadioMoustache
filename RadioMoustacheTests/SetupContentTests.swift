import Foundation
import Testing
@testable import RadioMoustache

@MainActor
struct SetupContentTests {
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

    @Test func recapLinesAlignLabelsDotsAndValues() {
        let lines = SetupContent.recapLines(for: makeAudio())
        // Calculé hors de #expect : la macro ne sait pas décomposer un appel « rethrows » comme map.
        let steps = lines.map(\.step)

        #expect(steps == [.microphone, .mainOutput, .monitorOutput])
        #expect(lines[0].text == "1 MICRO ..... SHURE MV7 · USB ~5 MS")
        #expect(lines[1].text == "2 ENCEINTE .. HAUT-PARLEURS MACBOOK PRO · INTÉGRÉ ~5 MS")
        #expect(lines[2].text == "3 CASQUE .... AUCUN")
        #expect(lines[0].accessibilityText == "MICRO : SHURE MV7 · USB ~5 MS")
        #expect(!lines[2].isAlert)
    }

    @Test func unpluggedDeviceIsFlagged() {
        let hardware = MockAudioHardware(devices: Fixtures.all, defaultInputUID: Fixtures.usbMic.uid)
        let audio = AudioManager(hardware: hardware, store: InMemorySessionConfigStore(), refreshDelay: .zero)
        audio.refreshDevices()
        audio.selectMainOutput(uid: Fixtures.bluetoothSpeaker.uid)

        // L'enceinte décroche : elle reste choisie, en attendant son retour.
        hardware.devices.removeAll { $0 == Fixtures.bluetoothSpeaker }
        audio.refreshDevices()
        let value = SetupContent.value(for: .mainOutput, audio: audio)

        #expect(value.isAlert)
        #expect(value.text == "JBL FLIP · DÉBRANCHÉ")
    }

    @Test func missingMicrophoneMustBeChosen() {
        let audio = makeAudio(devices: [Fixtures.builtInSpeakers])

        let value = SetupContent.value(for: .microphone, audio: audio)

        #expect(value.text == "À CHOISIR")
        #expect(value.isAlert)
    }

    @Test func optionsMarkTheCurrentChoice() {
        let audio = makeAudio()
        let options = SetupContent.options(for: .microphone, audio: audio)
        let currentChoices = options.filter(\.isCurrent).map(\.choice)

        #expect(options.count == audio.inputDevices.count)
        #expect(currentChoices == [.microphone(uid: Fixtures.usbMic.uid)])
    }

    @Test func monitorOptionsOfferNoneAndSkipTheMainOutput() {
        let audio = makeAudio()
        let options = SetupContent.options(for: .monitorOutput, audio: audio)
        let choices = options.map(\.choice)

        #expect(options.first?.text == "AUCUN (PAS DE RETOUR)")
        #expect(options.first?.isCurrent == true)
        #expect(!choices.contains(.monitorOutput(uid: Fixtures.builtInSpeakers.uid)))
        #expect(choices.contains(.monitorOutput(uid: Fixtures.wiredHeadphones.uid)))
    }

    @Test func channelOptionsFollowTheMicrophone() {
        let audio = makeAudio()
        audio.selectInput(uid: Fixtures.interface.uid)

        let texts = SetupContent.options(for: .channel, audio: audio).map(\.text)

        #expect(texts == ["ENTRÉE 1", "ENTRÉE 2", "ENTRÉES 1-2 (STÉRÉO)"])
    }

    @Test func latencyOptionsShowTheirDuration() {
        let audio = makeAudio()
        let texts = SetupContent.options(for: .latency, audio: audio).map(\.text)

        #expect(texts.contains("256 ÉCHANTILLONS (5,3 MS)"))
        #expect(texts.contains("64 ÉCHANTILLONS (1,3 MS)"))
    }

    @Test func applyingAChoiceUpdatesTheSelection() {
        let audio = makeAudio()

        SetupContent.apply(.microphone(uid: Fixtures.interface.uid), to: audio)
        SetupContent.apply(.channels(.stereo(first: 0)), to: audio)
        SetupContent.apply(.monitorOutput(uid: Fixtures.wiredHeadphones.uid), to: audio)
        SetupContent.apply(.bufferFrameSize(128), to: audio)

        #expect(audio.selection.inputUID == Fixtures.interface.uid)
        #expect(audio.selection.inputChannels == .stereo(first: 0))
        #expect(audio.selection.monitorOutputUID == Fixtures.wiredHeadphones.uid)
        #expect(audio.selection.bufferFrameSize == 128)
    }

    @Test func extraAlertsAreSummarised() {
        let lines = ["a", "b", "c", "d"]

        #expect(SetupContent.limited(lines, to: 3) == ["a", "b", "! ET 2 AUTRES ALERTES"])
        #expect(SetupContent.limited(lines, to: 4) == lines)
        #expect(SetupContent.limited(lines, to: 1) == ["a"])
        #expect(SetupContent.limited(lines, to: 0).isEmpty)
    }

    @Test func longListsScrollToKeepTheCurrentChoiceVisible() {
        // Tout tient.
        #expect(SetupContent.visibleWindow(count: 5, highlighted: 4, capacity: 6) == 0..<5)
        // Début ou fin de liste : une seule ligne « ... ».
        #expect(SetupContent.visibleWindow(count: 10, highlighted: 0, capacity: 6) == 0..<5)
        #expect(SetupContent.visibleWindow(count: 10, highlighted: 4, capacity: 6) == 0..<5)
        #expect(SetupContent.visibleWindow(count: 10, highlighted: 5, capacity: 6) == 5..<10)
        #expect(SetupContent.visibleWindow(count: 20, highlighted: 19, capacity: 6) == 15..<20)
        // Milieu : « ... » en haut et en bas.
        #expect(SetupContent.visibleWindow(count: 20, highlighted: 10, capacity: 6) == 8..<12)
    }

    @Test func levelBarFillsWithTheVoice() {
        #expect(SetupContent.levelBar(level: 0) == "[....................]")
        #expect(SetupContent.levelBar(level: 0.5) == "[##########..........]")
        #expect(SetupContent.levelBar(level: 1) == "[####################]")
        #expect(SetupContent.levelBar(level: 3, width: 4) == "[####]")
        #expect(SetupContent.levelBar(level: .nan, width: 4) == "[....]")
    }

    @Test func levelHintSaysWhatToDo() {
        #expect(SetupContent.levelHint(level: 0, status: .running) == "PARLE !")
        #expect(SetupContent.levelHint(level: 0.6, status: .running) == "ÇA CAPTE !")
        #expect(SetupContent.levelHint(level: 0, status: .starting) == "MISE EN ROUTE...")
        #expect(SetupContent.levelHint(level: 0.6, status: .noSignal) == "RIEN !")
    }
}

struct SetupStepTests {
    @Test func stepsComeInOrder() {
        #expect(SetupStep.allCases == [.microphone, .mainOutput, .monitorOutput, .review])
        #expect(SetupStep.microphone.previous == nil)
        #expect(SetupStep.microphone.next == .mainOutput)
        #expect(SetupStep.review.previous == .monitorOutput)
        #expect(SetupStep.review.next == nil)
        #expect(SetupStep.mainOutput < .review)
    }

    @Test func eachDeviceStepHasItsListAndItsTest() {
        #expect(SetupStep.microphone.list == .microphone)
        #expect(SetupStep.microphone.testTarget == nil)
        #expect(SetupStep.mainOutput.list == .mainOutput)
        #expect(SetupStep.mainOutput.testTarget == .mainOutput)
        #expect(SetupStep.monitorOutput.list == .monitorOutput)
        #expect(SetupStep.monitorOutput.testTarget == .monitorOutput)
        #expect(SetupStep.review.list == nil)
        #expect(SetupStep.review.question == "TOUT EST PRÊT ?")
    }

    @Test func questionsFitOnTheScreen() {
        let questions = SetupStep.allCases.map(\.question) + [SetupList.channel.question, SetupList.latency.question]
        let longest = questions.map(\.count).max() ?? 0

        // 27 points en VT323 : 45 caractères tiennent sur la largeur de l'écran.
        #expect(longest <= 45)
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
        let lines = LogbookPage.lines(for: nil)

        #expect(lines.count == 4)
        #expect(lines[3] == "puis « Paré à émettre ! ».")
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
    static let all: [SetupIssue] = [
        .missingDevice(.microphone), .missingDevice(.mainOutput), .missingDevice(.monitorOutput),
        .deviceDisconnected(.microphone), .deviceDisconnected(.mainOutput), .deviceDisconnected(.monitorOutput),
        .monitorSameAsMain, .invalidInputChannels,
        .highLatencyOutput(.mainOutput, .bluetooth), .highLatencyOutput(.monitorOutput, .bluetooth),
        .highLatencyOutput(.mainOutput, .airPlay), .bluetoothMicrophone, .builtInMicrophone,
    ]

    @Test(arguments: SetupIssueScreenMessageTests.all)
    func messagesAreShortCapitalsWithTheirSeverity(issue: SetupIssue) {
        let message = issue.screenMessage

        #expect(message == message.screenUppercased)
        #expect(message.hasPrefix(issue.isBlocking ? "!! " : "! "))
        #expect(message.count <= 52)
    }

    @Test(arguments: SetupIssueScreenMessageTests.all)
    func eachIssueIsFixedAtAStepWithADeviceList(issue: SetupIssue) {
        #expect(issue.step.list != nil)
    }

    @Test func issuesPointToTheirStep() {
        #expect(SetupIssue.invalidInputChannels.step == .microphone)
        #expect(SetupIssue.deviceDisconnected(.mainOutput).step == .mainOutput)
        #expect(SetupIssue.highLatencyOutput(.monitorOutput, .bluetooth).step == .monitorOutput)
        #expect(SetupIssue.monitorSameAsMain.step == .monitorOutput)
    }
}
