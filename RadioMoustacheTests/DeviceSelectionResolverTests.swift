import Testing
@testable import RadioMoustache

struct DeviceSelectionResolverTests {
    private let inputs = Fixtures.inputs
    private let outputs = Fixtures.outputs

    @Test func restoresTheLastSessionWhenItsDevicesArePlugged() {
        var saved = DeviceSelection()
        saved.inputUID = Fixtures.interface.uid
        saved.inputChannels = .mono(1)
        saved.mainOutputUID = Fixtures.bluetoothSpeaker.uid
        saved.monitorOutputUID = Fixtures.wiredHeadphones.uid
        saved.bufferFrameSize = 512

        let selection = DeviceSelectionResolver.initialSelection(
            saved: saved, inputs: inputs, outputs: outputs,
            defaultInputUID: Fixtures.builtInMic.uid, defaultOutputUID: Fixtures.builtInSpeakers.uid
        )

        #expect(selection == saved)
    }

    @Test func fallsBackToSystemDefaultsWhenTheLastDevicesAreGone() {
        var saved = DeviceSelection()
        saved.inputUID = "micro-disparu"
        saved.mainOutputUID = "enceinte-disparue"
        saved.monitorOutputUID = "casque-disparu"

        let selection = DeviceSelectionResolver.initialSelection(
            saved: saved, inputs: inputs, outputs: outputs,
            defaultInputUID: Fixtures.usbMic.uid, defaultOutputUID: Fixtures.builtInSpeakers.uid
        )

        #expect(selection.inputUID == Fixtures.usbMic.uid)
        #expect(selection.mainOutputUID == Fixtures.builtInSpeakers.uid)
        #expect(selection.monitorOutputUID == nil)
    }

    @Test func firstLaunchUsesSystemDefaultsWithoutMonitor() {
        let selection = DeviceSelectionResolver.initialSelection(
            saved: nil, inputs: inputs, outputs: outputs,
            defaultInputUID: Fixtures.builtInMic.uid, defaultOutputUID: Fixtures.bluetoothSpeaker.uid
        )

        #expect(selection.inputUID == Fixtures.builtInMic.uid)
        #expect(selection.inputChannels == .mono(0))
        #expect(selection.mainOutputUID == Fixtures.bluetoothSpeaker.uid)
        #expect(selection.monitorOutputUID == nil)
        #expect(selection.bufferFrameSize == BufferSizePolicy.defaultSize)
    }

    @Test func dropsASavedMonitorThatBecameTheMainOutput() {
        var saved = DeviceSelection()
        saved.monitorOutputUID = Fixtures.builtInSpeakers.uid

        let selection = DeviceSelectionResolver.initialSelection(
            saved: saved, inputs: inputs, outputs: outputs,
            defaultInputUID: nil, defaultOutputUID: Fixtures.builtInSpeakers.uid
        )

        #expect(selection.mainOutputUID == Fixtures.builtInSpeakers.uid)
        #expect(selection.monitorOutputUID == nil)
    }

    @Test func resetsAChannelThatDoesNotExistOnTheMicrophone() {
        var selection = DeviceSelection()
        selection.inputUID = Fixtures.usbMic.uid
        selection.inputChannels = .stereo(first: 0)

        let sanitized = DeviceSelectionResolver.sanitized(selection, inputs: inputs, outputs: outputs)

        #expect(sanitized.inputChannels == .mono(0))
    }

    @Test func keepsADisconnectedDeviceSelectedForAutomaticReconnection() {
        var selection = DeviceSelection()
        selection.inputUID = Fixtures.usbMic.uid
        selection.mainOutputUID = Fixtures.bluetoothSpeaker.uid

        let sanitized = DeviceSelectionResolver.sanitized(
            selection, inputs: inputs, outputs: outputs.filter { $0 != Fixtures.bluetoothSpeaker }
        )

        #expect(sanitized.mainOutputUID == Fixtures.bluetoothSpeaker.uid)
    }

    @Test func raisesTheBufferWhenABluetoothDeviceRefusesSmallSizes() {
        var selection = DeviceSelection()
        selection.inputUID = Fixtures.usbMic.uid
        selection.mainOutputUID = Fixtures.bluetoothSpeaker.uid
        selection.bufferFrameSize = 64

        let sanitized = DeviceSelectionResolver.sanitized(selection, inputs: inputs, outputs: outputs)

        #expect(sanitized.bufferFrameSize == 256)
    }
}
