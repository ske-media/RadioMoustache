import SwiftUI

/// Couleurs de Radio Moustache : des lueurs d'époque sur fond de bakélite.
/// Les matières et la typographie vintage arrivent à l'étape 2.
enum Palette {
    /// Lueur des tubes et des chiffres Nixie.
    static let electricOrange = Color(hex: 0xFF6B00)
    /// Œil magique et voyants.
    static let neonGreen = Color(hex: 0x3EFB0A)
    /// Enseigne ON AIR et alertes.
    static let deepBordeaux = Color(hex: 0x6A0E15)
    /// Bakélite noire (fond).
    static let bakelite = Color(hex: 0x141210)
    /// Bakélite des panneaux, légèrement éclairée.
    static let bakeliteRaised = Color(hex: 0x221E1A)
    /// Ivoire des plaques et des graduations.
    static let ivory = Color(hex: 0xECE3CF)
}

extension Color {
    /// Couleur sRGB à partir d'une valeur 0xRRGGBB.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
