import CoreAudio
import Testing
@testable import RadioMoustache

struct CoreAudioHelpersTests {
    @Test func mapsCoreAudioTransportTypes() {
        let cases: [(UInt32, AudioTransport)] = [
            (kAudioDeviceTransportTypeBuiltIn, .builtIn),
            (kAudioDeviceTransportTypeUSB, .usb),
            (kAudioDeviceTransportTypeBluetooth, .bluetooth),
            (kAudioDeviceTransportTypeBluetoothLE, .bluetoothLE),
            (kAudioDeviceTransportTypeAirPlay, .airPlay),
            (kAudioDeviceTransportTypeVirtual, .virtual),
            (kAudioDeviceTransportTypeAggregate, .aggregate),
        ]
        for (value, expected) in cases {
            #expect(AudioTransport(coreAudioTransportType: value) == expected)
        }
        #expect(AudioTransport(coreAudioTransportType: 0x7A7A_7A7A) == .other(0x7A7A_7A7A))
    }

    @Test func onlyBluetoothAndAirPlayAddAudibleDelay() {
        #expect(AudioTransport.bluetooth.hasHighLatency)
        #expect(AudioTransport.bluetoothLE.hasHighLatency)
        #expect(AudioTransport.airPlay.hasHighLatency)
        #expect(!AudioTransport.usb.hasHighLatency)
        #expect(!AudioTransport.builtIn.hasHighLatency)
    }

    @Test func statusCodesAreReadable() {
        #expect(UInt32(0x7768_6174).fourCharCodeDescription == "'what'")
        #expect(kAudioHardwareUnspecifiedError.fourCharCodeDescription == "'what'")
        #expect(OSStatus(-50).fourCharCodeDescription == "-50")
    }

    @Test func privateAggregatesAndDeadDevicesAreNotSelectable() {
        #expect(Fixtures.usbMic.isSelectable)
        #expect(!AudioDevice.fixture(id: 1, uid: AudioDevice.privateUIDPrefix + "agregat", outputChannels: 4).isSelectable)
        #expect(!AudioDevice.fixture(id: 2, uid: "mort", outputChannels: 2, isAlive: false).isSelectable)
    }

    @Test func latencyEstimateIncludesTheBuffer() throws {
        // 480 échantillons à 48 kHz = 10 ms.
        let latency = try #require(Fixtures.usbMic.estimatedLatency(for: .microphone, bufferFrameSize: 480))
        #expect(abs(latency - 10) < 0.001)
    }
}
