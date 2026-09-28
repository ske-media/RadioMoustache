import Foundation

/// Encode des échantillons mono en fichier WAV PCM 16 bits, lisible par `AVAudioPlayer`.
enum WAVEncoder {
    static let headerSize = 44

    static func encode(samples: [Float], sampleRate: Int) -> Data {
        let bytesPerSample = 2
        let dataSize = samples.count * bytesPerSample
        var data = Data(capacity: headerSize + dataSize)

        data.append(contentsOf: Array("RIFF".utf8))
        data.appendLittleEndian(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))

        data.append(contentsOf: Array("fmt ".utf8))
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1)) // PCM entier
        data.appendLittleEndian(UInt16(1)) // mono
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(sampleRate * bytesPerSample)) // octets par seconde
        data.appendLittleEndian(UInt16(bytesPerSample)) // taille d'une trame
        data.appendLittleEndian(UInt16(16)) // bits par échantillon

        data.append(contentsOf: Array("data".utf8))
        data.appendLittleEndian(UInt32(dataSize))
        for sample in samples {
            data.appendLittleEndian(pcm16(sample))
        }
        return data
    }

    /// Échantillon flottant (-1…1) converti en entier 16 bits, écrêté.
    static func pcm16(_ sample: Float) -> Int16 {
        let clamped = sample.isFinite ? min(max(sample, -1), 1) : 0
        return Int16((clamped * Float(Int16.max)).rounded())
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        // `Swift.` : dans une extension de Data, `withUnsafeBytes` désignerait la méthode de Data.
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
