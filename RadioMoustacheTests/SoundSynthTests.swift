import Foundation
import Testing
@testable import RadioMoustache

struct SoundSynthTests {
    private static func peak(_ samples: [Float]) -> Float {
        samples.reduce(0) { max($0, abs($1)) }
    }

    @Test(arguments: InterfaceSound.allCases)
    func interfaceSoundsAreAudibleAndNeverClip(sound: InterfaceSound) {
        let samples = SoundSynth.samples(for: sound)
        let peak = Self.peak(samples)

        #expect(!samples.isEmpty)
        #expect(peak <= 1)
        #expect(peak > 0.2)
    }

    @Test(arguments: InterfaceSound.allCases)
    func interfaceSoundsAreTheSameEveryTime(sound: InterfaceSound) {
        #expect(SoundSynth.samples(for: sound) == SoundSynth.samples(for: sound))
    }

    @Test func soundsLastAsLongAsDesigned() {
        #expect(SoundSynth.lever().count == Int(0.4 * SoundSynth.sampleRate))
        #expect(SoundSynth.typewriterTick().count == Int(0.03 * SoundSynth.sampleRate))
        #expect(SoundSynth.crtPowerOn().count == Int(1.2 * SoundSynth.sampleRate))
    }

    @Test func testBeepIsHalfASecondAtMinusEightDecibels() {
        let beep = SoundSynth.testBeep(sampleRate: 22_050)
        let peak = Self.peak(beep)

        #expect(beep.count == 11_025)
        #expect(peak <= 0.4)
        #expect(peak > 0.39)
        #expect(beep.first == 0)
    }

    @Test func noiseStaysBetweenMinusOneAndOneAndRepeats() {
        var first = NoiseGenerator(seed: 42)
        var second = NoiseGenerator(seed: 42)
        let a = (0..<1000).map { _ in first.next() }
        let b = (0..<1000).map { _ in second.next() }
        let inRange = a.allSatisfy { (-1...1).contains($0) }

        #expect(a == b)
        #expect(inRange)
    }
}

struct WAVEncoderTests {
    private func uint32(_ data: Data, at offset: Int) -> UInt32 {
        data[offset..<offset + 4].enumerated().reduce(0) { $0 | UInt32($1.element) << (8 * UInt32($1.offset)) }
    }

    private func uint16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private func text(_ data: Data, at offset: Int) -> String {
        String(decoding: data[offset..<offset + 4], as: UTF8.self)
    }

    @Test func headerDescribesMono16BitPCM() {
        let data = WAVEncoder.encode(samples: [0, 0.5, -0.5, 1], sampleRate: 44_100)

        #expect(data.count == WAVEncoder.headerSize + 8)
        #expect(text(data, at: 0) == "RIFF")
        #expect(uint32(data, at: 4) == UInt32(36 + 8))
        #expect(text(data, at: 8) == "WAVE")
        #expect(text(data, at: 12) == "fmt ")
        #expect(uint32(data, at: 16) == 16)
        #expect(uint16(data, at: 20) == 1)
        #expect(uint16(data, at: 22) == 1)
        #expect(uint32(data, at: 24) == 44_100)
        #expect(uint32(data, at: 28) == 88_200)
        #expect(uint16(data, at: 32) == 2)
        #expect(uint16(data, at: 34) == 16)
        #expect(text(data, at: 36) == "data")
        #expect(uint32(data, at: 40) == 8)
    }

    @Test func samplesAreConvertedAndClipped() {
        #expect(WAVEncoder.pcm16(0) == 0)
        #expect(WAVEncoder.pcm16(1) == Int16.max)
        #expect(WAVEncoder.pcm16(-1) == -Int16.max)
        #expect(WAVEncoder.pcm16(2) == Int16.max)
        #expect(WAVEncoder.pcm16(.nan) == 0)
        #expect(WAVEncoder.pcm16(0.5) == 16_384)
    }
}

struct InterfaceSoundRoutingTests {
    private let outputs = Fixtures.outputs

    @Test func macSpeakersArePreferred() {
        let uid = InterfaceSoundRouting.deviceUID(
            outputs: outputs,
            mainOutputUID: Fixtures.bluetoothSpeaker.uid,
            monitorOutputUID: Fixtures.wiredHeadphones.uid
        )
        #expect(uid == Fixtures.builtInSpeakers.uid)
    }

    @Test func headphonesTakeOverWhenTheMacSpeakersAreTheMainOutput() {
        let uid = InterfaceSoundRouting.deviceUID(
            outputs: outputs,
            mainOutputUID: Fixtures.builtInSpeakers.uid,
            monitorOutputUID: Fixtures.wiredHeadphones.uid
        )
        #expect(uid == Fixtures.wiredHeadphones.uid)
    }

    @Test func silenceRatherThanTheMainOutput() {
        #expect(InterfaceSoundRouting.deviceUID(
            outputs: outputs,
            mainOutputUID: Fixtures.builtInSpeakers.uid,
            monitorOutputUID: nil
        ) == nil)
        #expect(InterfaceSoundRouting.deviceUID(
            outputs: [Fixtures.bluetoothSpeaker],
            mainOutputUID: Fixtures.bluetoothSpeaker.uid,
            monitorOutputUID: Fixtures.bluetoothSpeaker.uid
        ) == nil)
    }

    @Test func unpluggedHeadphonesAreIgnored() {
        let uid = InterfaceSoundRouting.deviceUID(
            outputs: [Fixtures.bluetoothSpeaker],
            mainOutputUID: Fixtures.bluetoothSpeaker.uid,
            monitorOutputUID: Fixtures.wiredHeadphones.uid
        )
        #expect(uid == nil)
    }
}
