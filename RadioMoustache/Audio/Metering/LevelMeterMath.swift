import AVFoundation

/// Calculs du niveau micro affiché par l'œil magique (logique pure, testée unitairement).
enum LevelMeterMath {
    /// Niveau renvoyé quand rien n'est mesuré, en dBFS.
    static let silence: Float = -160
    /// En dessous : œil grand ouvert (souffle du micro, silence).
    static let floorDecibels = -60.0
    /// Au-dessus : œil fermé (voix forte).
    static let ceilingDecibels = -8.0

    /// Crête en dBFS ramenée entre 0 (silence) et 1 (voix forte).
    static func normalized(decibels: Float) -> Double {
        guard decibels.isFinite else { return 0 }
        let value = (Double(decibels) - floorDecibels) / (ceilingDecibels - floorDecibels)
        return min(max(value, 0), 1)
    }

    /// Niveau à retenir parmi ceux des canaux reçus : le plus fort des canaux choisis,
    /// ou de tous les canaux si ceux qu'on a choisis n'arrivent pas.
    static func level(of channelLevels: [Float], channels: [Int]) -> Float {
        let selected = channels.filter { channelLevels.indices.contains($0) }.map { channelLevels[$0] }
        return (selected.isEmpty ? channelLevels : selected).max() ?? silence
    }

    /// Demi-angle (en degrés) de l'ombre de l'œil magique : large au silence, fine quand on parle fort.
    static func eyeShadowHalfAngle(level: Double) -> Double {
        45 - 42 * min(max(level, 0), 1)
    }

    /// Amplitude (0…1) convertie en dBFS ; un canal entièrement nul vaut `silence`.
    static func decibels(amplitude: Float) -> Float {
        guard amplitude > 0, amplitude.isFinite else { return silence }
        return max(20 * log10(amplitude), silence)
    }

    /// Crête de chaque canal d'un tampon, en dBFS, quel que soit son format PCM.
    /// Les pointeurs de canaux d'`AVAudioPCMBuffer` sont espacés de `stride` échantillons,
    /// entrelacé ou non : une seule lecture convient aux deux cas.
    static func peakDecibels(of buffer: AVAudioPCMBuffer) -> [Float] {
        let channelCount = Int(buffer.format.channelCount)
        let frames = Int(buffer.frameLength)
        let stride = buffer.stride
        var peaks = [Float](repeating: 0, count: channelCount)
        if let data = buffer.floatChannelData {
            for channel in 0..<channelCount {
                let samples = data[channel]
                var peak: Float = 0
                for frame in 0..<frames {
                    peak = max(peak, samples[frame * stride].magnitude)
                }
                peaks[channel] = peak
            }
        } else if let data = buffer.int16ChannelData {
            for channel in 0..<channelCount {
                let samples = data[channel]
                var peak: Float = 0
                for frame in 0..<frames {
                    peak = max(peak, Float(samples[frame * stride]).magnitude / 32_768)
                }
                peaks[channel] = peak
            }
        } else if let data = buffer.int32ChannelData {
            for channel in 0..<channelCount {
                let samples = data[channel]
                var peak: Float = 0
                for frame in 0..<frames {
                    peak = max(peak, Float(samples[frame * stride]).magnitude / 2_147_483_648)
                }
                peaks[channel] = peak
            }
        }
        return peaks.map(decibels(amplitude:))
    }
}

/// Inertie de l'aiguille… ou plutôt de l'œil : monte vite, redescend doucement.
struct LevelBallistics {
    private(set) var value: Double = 0
    /// Part de l'écart rattrapée à chaque pas quand le niveau monte.
    var attack = 0.55
    /// Part de l'écart rattrapée à chaque pas quand le niveau baisse.
    var release = 0.12

    mutating func next(toward target: Double) -> Double {
        let coefficient = target > value ? attack : release
        value += (target - value) * coefficient
        return value
    }

    mutating func reset() {
        value = 0
    }
}

/// Ce que l'on peut conclure de ce qui arrive (ou pas) du micro.
enum InputLevelDiagnosis {
    /// Sans aucun son reçu pendant ce délai, on conclut que rien ne vient du micro.
    static let noSignalDelay = 2.0
    /// Des zéros parfaits pendant ce délai : le micro est coupé (autorisation, bouton muet…).
    /// Un vrai micro a toujours un léger souffle, jamais un zéro parfait.
    static let mutedDelay = 3.0

    static func status(
        secondsSinceLastBuffer: Double?,
        digitalSilenceDuration: Double?,
        runningFor: Double
    ) -> InputLevelStatus {
        if let secondsSinceLastBuffer {
            if secondsSinceLastBuffer > noSignalDelay { return .noSignal }
        } else if runningFor > noSignalDelay {
            return .noSignal
        }
        if let digitalSilenceDuration, digitalSilenceDuration > mutedDelay {
            return .muted
        }
        return .running
    }
}
