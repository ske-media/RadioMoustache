import CoreAudio
@testable import RadioMoustache

extension AudioDevice {
    /// Périphérique factice pour les tests.
    static func fixture(
        id: AudioObjectID,
        uid: String,
        name: String? = nil,
        transport: AudioTransport = .usb,
        inputChannels: Int = 0,
        outputChannels: Int = 0,
        sampleRate: Double = 48_000,
        bufferRange: ClosedRange<UInt32>? = 15...4096,
        isAlive: Bool = true,
        isHidden: Bool = false
    ) -> AudioDevice {
        AudioDevice(
            objectID: id,
            uid: uid,
            name: name ?? uid,
            manufacturer: "Test",
            transport: transport,
            inputChannelNames: Array(repeating: nil, count: inputChannels),
            outputChannelCount: outputChannels,
            nominalSampleRate: sampleRate,
            bufferFrameSizeRange: bufferRange,
            inputLatencyFrames: 0,
            outputLatencyFrames: 0,
            isAlive: isAlive,
            isHidden: isHidden
        )
    }
}

/// Parc matériel typique d'une soirée.
enum Fixtures {
    static let usbMic = AudioDevice.fixture(
        id: 10, uid: "usb-mic", name: "Shure MV7", inputChannels: 1
    )
    static let interface = AudioDevice.fixture(
        id: 11, uid: "scarlett", name: "Scarlett 2i2", inputChannels: 2, outputChannels: 2
    )
    static let builtInMic = AudioDevice.fixture(
        id: 12, uid: "builtin-mic", name: "Micro MacBook Pro", transport: .builtIn, inputChannels: 1
    )
    static let airPods = AudioDevice.fixture(
        id: 13, uid: "airpods", name: "AirPods Pro", transport: .bluetooth,
        inputChannels: 1, outputChannels: 2, bufferRange: 256...4096
    )
    static let builtInSpeakers = AudioDevice.fixture(
        id: 20, uid: "builtin-out", name: "Haut-parleurs MacBook Pro", transport: .builtIn, outputChannels: 2
    )
    static let bluetoothSpeaker = AudioDevice.fixture(
        id: 21, uid: "jbl", name: "JBL Flip", transport: .bluetooth, outputChannels: 2, bufferRange: 256...4096
    )
    static let wiredHeadphones = AudioDevice.fixture(
        id: 22, uid: "headphones", name: "Casque filaire", outputChannels: 2
    )
    static let airPlaySpeaker = AudioDevice.fixture(
        id: 23, uid: "airplay", name: "Salon", transport: .airPlay, outputChannels: 2
    )

    static let all = [
        usbMic, interface, builtInMic, airPods,
        builtInSpeakers, bluetoothSpeaker, wiredHeadphones, airPlaySpeaker,
    ]
    static var inputs: [AudioDevice] { all.filter(\.hasInput) }
    static var outputs: [AudioDevice] { all.filter(\.hasOutput) }
}
