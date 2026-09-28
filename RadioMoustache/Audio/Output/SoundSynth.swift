import Foundation

/// Bruitages fabriqués par l'app, sans fichier son : clac du levier, étincelles, allumage du moniteur,
/// frappe du texte, bip du menu, validation, et le bip de 1 kHz des sons d'essai.
///
/// Le bruit vient d'un générateur à graine fixe : chaque bruitage sonne pareil d'une fois sur l'autre.
enum SoundSynth {
    static let sampleRate = 44_100.0

    static func samples(for sound: InterfaceSound) -> [Float] {
        switch sound {
        case .lever: lever()
        case .sparks: sparks()
        case .crtPowerOn: crtPowerOn()
        case .typewriterTick: typewriterTick()
        case .menuBlip: menuBlip()
        case .goLive: goLiveChime()
        }
    }

    // MARK: - Bruitages

    /// Clac du levier « SECTEUR » : choc sourd du couteau, puis contact métallique des mâchoires.
    static func lever() -> [Float] {
        var noise = NoiseGenerator(seed: 7)
        var thumpPhase = 0.0
        return render(duration: 0.4, peak: 0.9) { t in
            // Choc sourd dont la hauteur tombe de 120 à 55 Hz.
            let frequency = 55 + 65 * exp(-t / 0.03)
            thumpPhase += 2 * .pi * frequency / sampleRate
            var value = 0.8 * sin(thumpPhase) * exp(-t / 0.045)
            value += metallicHit(at: t, start: 0, gain: 1)
            value += metallicHit(at: t, start: 0.055, gain: 0.55)
            if t < 0.008 {
                value += 0.5 * Double(noise.next()) * (1 - t / 0.008)
            }
            return value
        }
    }

    /// Étincelles du couteau : bourdonnement électrique et crépitements de plus en plus espacés.
    static func sparks() -> [Float] {
        let count = frameCount(0.6)
        var output = [Float](repeating: 0, count: count)
        var noise = NoiseGenerator(seed: 21)

        for index in 0..<count {
            let t = Double(index) / sampleRate
            var buzz = 0.0
            for harmonic in stride(from: 1, through: 15, by: 2) {
                buzz += sin(2 * .pi * 100 * Double(harmonic) * t) / Double(harmonic)
            }
            output[index] = Float(0.12 * buzz * exp(-t / 0.12))
        }

        var position = 0
        while position < count {
            let t = Double(position) / sampleRate
            let burstLength = max(1, Int(sampleRate * (0.001 + 0.003 * Double(abs(noise.next())))))
            let amplitude = (0.35 + 0.5 * Double(abs(noise.next()))) * exp(-t / 0.25)
            var previous: Float = 0
            for offset in 0..<burstLength where position + offset < count {
                let white = noise.next()
                // Différence entre deux tirages : un bruit plus aigu, qui claque comme une étincelle.
                let crackle = white - previous
                previous = white
                let envelope = 1 - Double(offset) / Double(burstLength)
                output[position + offset] += Float(amplitude * envelope * 0.5) * crackle
            }
            let gap = sampleRate * (0.004 + 0.03 * Double(abs(noise.next())) + t * 0.12)
            position += burstLength + Int(gap)
        }

        applyFades(to: &output)
        return normalized(output, peak: 0.85)
    }

    /// Allumage du moniteur : relais, ronflement du transformateur et grésillement de la haute tension.
    static func crtPowerOn() -> [Float] {
        var noise = NoiseGenerator(seed: 5)
        var hiss: Float = 0
        return render(duration: 1.2, peak: 0.8) { t in
            let humEnvelope = min(t / 0.06, 1) * exp(-t / 0.35) * (1 + 0.25 * sin(2 * .pi * 7 * t))
            let hum = 0.5 * sin(2 * .pi * 50 * t) + 0.3 * sin(2 * .pi * 100 * t) + 0.15 * sin(2 * .pi * 150 * t)
            hiss += (noise.next() - hiss) * 0.25
            let crackle = Double(hiss) * 0.35 * exp(-t / 0.4)
            let relay = t < 0.05 ? 0.7 * sin(2 * .pi * 90 * t) * exp(-t / 0.015) : 0
            return humEnvelope * hum + crackle + relay
        }
    }

    /// Frappe d'une ligne sur le moniteur, façon téléscripteur.
    static func typewriterTick() -> [Float] {
        var noise = NoiseGenerator(seed: 3)
        return render(duration: 0.03, peak: 0.5, fadeOut: 0.004) { t in
            let click = t < 0.002 ? Double(noise.next()) * (1 - t / 0.002) : 0
            let ring = 0.6 * sin(2 * .pi * 2400 * t) * exp(-t / 0.004)
            let body = 0.4 * sin(2 * .pi * 620 * t) * exp(-t / 0.007)
            return click + ring + body
        }
    }

    /// Petit bip du menu vert.
    static func menuBlip() -> [Float] {
        render(duration: 0.08, peak: 0.35) { t in
            let envelope = min(t / 0.002, 1) * exp(-t / 0.025)
            return envelope * (sin(2 * .pi * 1760 * t) + 0.3 * sin(2 * .pi * 3520 * t))
        }
    }

    /// « Paré à émettre » : relais puis deux notes montantes.
    static func goLiveChime() -> [Float] {
        var noise = NoiseGenerator(seed: 11)
        return render(duration: 0.45, peak: 0.6) { t in
            let relay = t < 0.006 ? 0.8 * Double(noise.next()) * (1 - t / 0.006) : 0
            let first = tone(frequency: 660, time: t, length: 0.14)
            let second = tone(frequency: 990, time: t - 0.12, length: 0.33)
            return relay + 0.5 * (first + second)
        }
    }

    /// Bip de test : 1 kHz pendant une demi-seconde, à environ -8 dBFS.
    static func testBeep(sampleRate rate: Double) -> [Float] {
        let count = Int(0.5 * rate)
        let fade = Int(0.01 * rate)
        return (0..<count).map { index in
            let t = Double(index) / rate
            let envelope = min(Double(min(index, count - 1 - index)) / Double(max(fade, 1)), 1)
            return Float(0.4 * envelope * sin(2 * .pi * 1000 * t))
        }
    }

    // MARK: - Outils

    private static let metallicPartials: [(frequency: Double, amplitude: Double, decay: Double)] = [
        (1870, 0.16, 0.05), (2630, 0.12, 0.04), (3950, 0.09, 0.03), (5210, 0.06, 0.02),
    ]

    private static func metallicHit(at time: Double, start: Double, gain: Double) -> Double {
        let t = time - start
        guard t >= 0 else { return 0 }
        var value = 0.0
        for partial in metallicPartials {
            value += partial.amplitude * sin(2 * .pi * partial.frequency * t) * exp(-t / partial.decay)
        }
        return gain * value
    }

    /// Note un peu « carrée » (fondamentale + troisième harmonique) avec attaque et relâche courtes.
    private static func tone(frequency: Double, time t: Double, length: Double) -> Double {
        guard t >= 0, t < length else { return 0 }
        let envelope = min(t / 0.005, 1) * min((length - t) / 0.03, 1)
        return envelope * (sin(2 * .pi * frequency * t) + 0.25 * sin(6 * .pi * frequency * t))
    }

    private static func frameCount(_ duration: Double) -> Int {
        Int(duration * sampleRate)
    }

    private static func render(
        duration: Double,
        peak: Float,
        fadeOut: Double = 0.01,
        _ sample: (Double) -> Double
    ) -> [Float] {
        var output = [Float](repeating: 0, count: frameCount(duration))
        for index in output.indices {
            output[index] = Float(sample(Double(index) / sampleRate))
        }
        applyFades(to: &output, fadeOut: fadeOut)
        return normalized(output, peak: peak)
    }

    /// Fondus très courts aux extrémités, pour éviter les clics.
    private static func applyFades(to samples: inout [Float], fadeIn: Double = 0.001, fadeOut: Double = 0.01) {
        let inCount = min(Int(fadeIn * sampleRate), samples.count)
        let outCount = min(Int(fadeOut * sampleRate), samples.count)
        for index in 0..<inCount {
            samples[index] *= Float(index) / Float(max(inCount, 1))
        }
        for offset in 0..<outCount {
            samples[samples.count - 1 - offset] *= Float(offset) / Float(max(outCount, 1))
        }
    }

    /// Ramène la crête du son à `peak`.
    static func normalized(_ samples: [Float], peak: Float) -> [Float] {
        let maximum = samples.reduce(Float(0)) { max($0, abs($1)) }
        guard maximum > 0 else { return samples }
        let gain = peak / maximum
        return samples.map { $0 * gain }
    }
}

/// Générateur pseudo-aléatoire « xorshift » à graine fixe.
struct NoiseGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    /// Valeur uniforme entre -1 et 1.
    mutating func next() -> Float {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Float(Double(state >> 11) / Double(UInt64(1) << 53)) * 2 - 1
    }
}
