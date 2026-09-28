/// Calculs du niveau micro affiché par l'œil magique (logique pure, testée unitairement).
enum LevelMeterMath {
    /// Niveau renvoyé quand rien n'est mesuré, en dBFS.
    static let silence: Float = -160
    /// En dessous : œil grand ouvert (silence).
    static let floorDecibels = -55.0
    /// Au-dessus : œil fermé (voix forte).
    static let ceilingDecibels = -5.0

    /// Niveau en dBFS ramené entre 0 (silence) et 1 (voix forte).
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
        38 - 32 * min(max(level, 0), 1)
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
