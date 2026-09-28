import AVFoundation
import Testing
@testable import RadioMoustache

struct LevelMeterMathTests {
    @Test func decibelsAreScaledBetweenSilenceAndLoudVoice() {
        #expect(LevelMeterMath.normalized(decibels: LevelMeterMath.silence) == 0)
        #expect(LevelMeterMath.normalized(decibels: -60) == 0)
        #expect(LevelMeterMath.normalized(decibels: -34) == 0.5)
        #expect(LevelMeterMath.normalized(decibels: -8) == 1)
        #expect(LevelMeterMath.normalized(decibels: 3) == 1)
        #expect(LevelMeterMath.normalized(decibels: .nan) == 0)
        #expect(LevelMeterMath.normalized(decibels: -.infinity) == 0)
    }

    @Test func theChosenChannelsDriveTheEye() {
        let levels: [Float] = [-40, -20]

        #expect(LevelMeterMath.level(of: levels, channels: [0]) == -40)
        #expect(LevelMeterMath.level(of: levels, channels: [1]) == -20)
        #expect(LevelMeterMath.level(of: levels, channels: [0, 1]) == -20)
    }

    @Test func missingChannelsFallBackToAllChannels() {
        #expect(LevelMeterMath.level(of: [-40, -20], channels: [4]) == -20)
        #expect(LevelMeterMath.level(of: [], channels: [0]) == LevelMeterMath.silence)
    }

    @Test func eyeShadowNarrowsWhenTheVoiceIsLoud() {
        #expect(LevelMeterMath.eyeShadowHalfAngle(level: 0) == 45)
        #expect(LevelMeterMath.eyeShadowHalfAngle(level: 1) == 3)
        #expect(LevelMeterMath.eyeShadowHalfAngle(level: 2) == 3)
        #expect(LevelMeterMath.eyeShadowHalfAngle(level: -1) == 45)
    }

    @Test func amplitudesBecomeDecibels() {
        #expect(LevelMeterMath.decibels(amplitude: 1) == 0)
        #expect(abs(LevelMeterMath.decibels(amplitude: 0.5) + 6.0206) < 0.001)
        #expect(LevelMeterMath.decibels(amplitude: 0) == LevelMeterMath.silence)
        #expect(LevelMeterMath.decibels(amplitude: .nan) == LevelMeterMath.silence)
    }

    @Test func peaksAreMeasuredOnEachSeparateChannel() throws {
        let format = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 2, interleaved: false))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480))
        buffer.frameLength = 480
        let left = try #require(buffer.floatChannelData?[0])
        let right = try #require(buffer.floatChannelData?[1])
        for index in 0..<480 {
            left[index] = 0.5 * sin(2 * .pi * Float(index) / 48)
            right[index] = 0
        }

        let peaks = LevelMeterMath.peakDecibels(of: buffer)

        #expect(peaks.count == 2)
        #expect(abs(peaks[0] + 6.0206) < 0.01)
        #expect(peaks[1] == LevelMeterMath.silence)
    }

    @Test func peaksAreMeasuredOnInterleavedIntegerChannels() throws {
        let format = try #require(AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44_100, channels: 2, interleaved: true))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4))
        buffer.frameLength = 4
        let samples = try #require(buffer.int16ChannelData?[0])
        // Trames entrelacées : gauche, droite, gauche, droite…
        let interleaved: [Int16] = [0, 100, 16_384, 0, 0, 0, -16_384, 0]
        for (index, value) in interleaved.enumerated() {
            samples[index] = value
        }

        let peaks = LevelMeterMath.peakDecibels(of: buffer)

        #expect(abs(peaks[0] + 6.0206) < 0.01)
        #expect(abs(peaks[1] - LevelMeterMath.decibels(amplitude: 100.0 / 32_768)) < 0.01)
    }

    @Test func silenceFromTheMicrophoneIsDiagnosed() {
        // Démarrage : pas encore de son, mais pas d'alerte avant 2 s.
        #expect(InputLevelDiagnosis.status(secondsSinceLastBuffer: nil, digitalSilenceDuration: nil, runningFor: 1) == .running)
        #expect(InputLevelDiagnosis.status(secondsSinceLastBuffer: nil, digitalSilenceDuration: nil, runningFor: 3) == .noSignal)
        // Le son arrive, puis s'interrompt.
        #expect(InputLevelDiagnosis.status(secondsSinceLastBuffer: 0.05, digitalSilenceDuration: nil, runningFor: 10) == .running)
        #expect(InputLevelDiagnosis.status(secondsSinceLastBuffer: 5, digitalSilenceDuration: nil, runningFor: 10) == .noSignal)
        // Des zéros parfaits : micro coupé.
        #expect(InputLevelDiagnosis.status(secondsSinceLastBuffer: 0.05, digitalSilenceDuration: 1, runningFor: 10) == .running)
        #expect(InputLevelDiagnosis.status(secondsSinceLastBuffer: 0.05, digitalSilenceDuration: 4, runningFor: 10) == .muted)
    }

    @Test func ballisticsRiseFastAndFallSlowly() {
        var ballistics = LevelBallistics()

        let risen = ballistics.next(toward: 1)
        let fallen = ballistics.next(toward: 0)

        #expect(abs(risen - 0.55) < 1e-9)
        #expect(abs(fallen - 0.484) < 1e-9)

        ballistics.reset()
        #expect(ballistics.value == 0)
    }
}
