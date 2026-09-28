import Testing
@testable import RadioMoustache

struct LevelMeterMathTests {
    @Test func decibelsAreScaledBetweenSilenceAndLoudVoice() {
        #expect(LevelMeterMath.normalized(decibels: LevelMeterMath.silence) == 0)
        #expect(LevelMeterMath.normalized(decibels: -55) == 0)
        #expect(LevelMeterMath.normalized(decibels: -30) == 0.5)
        #expect(LevelMeterMath.normalized(decibels: -5) == 1)
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
        #expect(LevelMeterMath.eyeShadowHalfAngle(level: 0) == 38)
        #expect(LevelMeterMath.eyeShadowHalfAngle(level: 1) == 6)
        #expect(LevelMeterMath.eyeShadowHalfAngle(level: 2) == 6)
        #expect(LevelMeterMath.eyeShadowHalfAngle(level: -1) == 38)
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
