/// Tailles de buffer proposées, en échantillons : plus petit = plus réactif, mais plus gourmand en CPU.
enum BufferSizePolicy {
    static let candidates: [UInt32] = [64, 128, 256, 512]
    static let defaultSize: UInt32 = 256

    /// Tailles acceptées par tous les périphériques donnés (toutes, si aucune ne convient à tous).
    static func options(for devices: [AudioDevice]) -> [UInt32] {
        let ranges = devices.compactMap(\.bufferFrameSizeRange)
        let compatible = candidates.filter { size in ranges.allSatisfy { $0.contains(size) } }
        return compatible.isEmpty ? candidates : compatible
    }

    /// Taille retenue : celle demandée si elle est proposée, sinon la plus proche de la valeur par défaut.
    static func resolve(_ requested: UInt32, options: [UInt32]) -> UInt32 {
        if options.contains(requested) { return requested }
        return options.min { distanceToDefault($0) < distanceToDefault($1) } ?? defaultSize
    }

    private static func distanceToDefault(_ size: UInt32) -> UInt32 {
        size > defaultSize ? size - defaultSize : defaultSize - size
    }
}
