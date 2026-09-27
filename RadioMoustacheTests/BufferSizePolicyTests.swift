import Testing
@testable import RadioMoustache

struct BufferSizePolicyTests {
    @Test func wiredDevicesAcceptEverySize() {
        #expect(BufferSizePolicy.options(for: [Fixtures.usbMic, Fixtures.builtInSpeakers]) == [64, 128, 256, 512])
    }

    @Test func bluetoothDevicesRuleOutTheSmallSizes() {
        #expect(BufferSizePolicy.options(for: [Fixtures.usbMic, Fixtures.bluetoothSpeaker]) == [256, 512])
    }

    @Test func everySizeIsOfferedWhenNoneFitsAllDevices() {
        let picky = AudioDevice.fixture(id: 90, uid: "picky", outputChannels: 2, bufferRange: 1024...2048)
        #expect(BufferSizePolicy.options(for: [picky]) == BufferSizePolicy.candidates)
    }

    @Test func unknownRangesRestrictNothing() {
        let unknown = AudioDevice.fixture(id: 91, uid: "unknown", outputChannels: 2, bufferRange: nil)
        #expect(BufferSizePolicy.options(for: [unknown]) == BufferSizePolicy.candidates)
    }

    @Test func resolveKeepsAnOfferedSizeOrPicksTheClosestToTheDefault() {
        #expect(BufferSizePolicy.resolve(128, options: [64, 128, 256]) == 128)
        #expect(BufferSizePolicy.resolve(64, options: [256, 512]) == 256)
        #expect(BufferSizePolicy.resolve(1024, options: [64, 128]) == 128)
    }
}
