import SwiftUI

/// Couleurs de Radio Moustache : des lueurs d'époque dans la cabine radio d'un chalutier, la nuit.
enum Palette {
    // MARK: - Lueurs

    /// Lueur des lampes de l'émetteur, chiffres Nixie, moustache du drapeau.
    static let electricOrange = Color(hex: 0xFF6B00)
    /// Écrans cathodiques, œil magique et voyants.
    static let neonGreen = Color(hex: 0x3EFB0A)
    /// Enseigne ON AIR et alertes.
    static let deepBordeaux = Color(hex: 0x6A0E15)

    // MARK: - Matières

    /// Bakélite noire (fond de l'écran de diagnostic).
    static let bakelite = Color(hex: 0x141210)
    /// Bakélite des panneaux, légèrement éclairée.
    static let bakeliteRaised = Color(hex: 0x221E1A)
    /// Ivoire des plaques et des graduations.
    static let ivory = Color(hex: 0xECE3CF)
    /// Nuit au fond de la cabine (bandes autour du décor en plein écran).
    static let night = Color(hex: 0x070605)
    /// Acier de la cloison, peint en vert d'eau.
    static let bulkhead = Color(hex: 0x2C5A54)
    /// Tôle froissée noire des boîtiers.
    static let crinkle = Color(hex: 0x171716)
    /// Tôle kaki du moniteur.
    static let olive = Color(hex: 0x3F4636)
    /// Bois sombre du bureau.
    static let wood = Color(hex: 0x3A2414)
    /// Scotch de masquage.
    static let maskingTape = Color(hex: 0xE7D9A6)
    /// Papier du journal de bord.
    static let logbookPaper = Color(hex: 0xE3D6A6)
    /// Encre du marqueur noir.
    static let markerInk = Color(hex: 0x161616)
    /// Marqueur rouge.
    static let markerRed = Color(hex: 0xB3261E)
    /// Ruban de la machine à écrire.
    static let typewriterInk = Color(hex: 0x2A241A)
    /// Peinture blanc cassé des pochoirs et des plaques.
    static let stencilPaint = Color(hex: 0xECE5D2)
    /// Texte sur fond vert (ligne sélectionnée de l'écran).
    static let phosphorInk = Color(hex: 0x031003)
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
