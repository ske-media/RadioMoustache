import Testing
@testable import RadioMoustache

struct SetupValidatorTests {
    private func issues(
        input: AudioDevice? = Fixtures.usbMic,
        channels: InputChannelSelection = .mono(0),
        main: AudioDevice? = Fixtures.builtInSpeakers,
        monitor: AudioDevice? = nil,
        connected: [AudioDevice] = Fixtures.all
    ) -> [SetupIssue] {
        var selection = DeviceSelection()
        selection.inputUID = input?.uid
        selection.inputChannels = channels
        selection.mainOutputUID = main?.uid
        selection.monitorOutputUID = monitor?.uid
        return SetupValidator.issues(
            for: selection,
            inputs: connected.filter(\.hasInput),
            outputs: connected.filter(\.hasOutput)
        )
    }

    @Test func wiredSetupHasNoIssue() {
        #expect(issues(monitor: Fixtures.wiredHeadphones).isEmpty)
    }

    @Test func missingMicrophoneAndOutputAreBlocking() {
        let found = issues(input: nil, main: nil)
        #expect(found.contains(.missingDevice(.microphone)))
        #expect(found.contains(.missingDevice(.mainOutput)))
        #expect(found.allSatisfy(\.isBlocking))
    }

    @Test func monitorCannotBeTheMainOutput() {
        #expect(issues(main: Fixtures.wiredHeadphones, monitor: Fixtures.wiredHeadphones) == [.monitorSameAsMain])
    }

    @Test func disconnectedDevicesAreBlocking() {
        let found = issues(monitor: Fixtures.wiredHeadphones, connected: [Fixtures.builtInSpeakers])
        #expect(found.contains(.deviceDisconnected(.microphone)))
        #expect(found.contains(.deviceDisconnected(.monitorOutput)))
        #expect(!found.contains(.deviceDisconnected(.mainOutput)))
    }

    @Test func missingInputChannelIsBlocking() {
        #expect(issues(channels: .mono(1)) == [.invalidInputChannels])
    }

    @Test func bluetoothAndAirPlayOutputsOnlyWarn() {
        let speaker = issues(main: Fixtures.bluetoothSpeaker)
        #expect(speaker == [.highLatencyOutput(.mainOutput, .bluetooth)])
        #expect(speaker.allSatisfy { !$0.isBlocking })
        #expect(issues(monitor: Fixtures.airPods) == [.highLatencyOutput(.monitorOutput, .bluetooth)])
        #expect(issues(main: Fixtures.airPlaySpeaker) == [.highLatencyOutput(.mainOutput, .airPlay)])
    }

    @Test func riskyMicrophonesOnlyWarn() {
        #expect(issues(input: Fixtures.airPods) == [.bluetoothMicrophone])
        #expect(issues(input: Fixtures.builtInMic) == [.builtInMicrophone])
    }

    @Test func blockingIssuesComeFirst() {
        let found = issues(input: Fixtures.builtInMic, main: nil)
        #expect(found == [.missingDevice(.mainOutput), .builtInMicrophone])
    }

    @Test func everyIssueHasAMessage() {
        let perRole = DeviceRole.allCases.flatMap { role -> [SetupIssue] in
            [
                .missingDevice(role),
                .deviceDisconnected(role),
                .highLatencyOutput(role, .bluetooth),
                .highLatencyOutput(role, .airPlay),
            ]
        }
        let all = perRole + [.monitorSameAsMain, .invalidInputChannels, .bluetoothMicrophone, .builtInMicrophone]
        for issue in all {
            #expect(!issue.message.isEmpty)
        }
    }
}
