import CoreText
import SwiftUI

/// Polices embarquées dans l'app (licences OFL et Apache 2.0, fichiers dans Resources/Fonts).
enum PirateFont {
    /// Noms PostScript des polices, qui sont aussi les noms de leurs fichiers `.ttf`.
    static let bundledFonts = [
        "BlackOpsOne-Regular",
        "PermanentMarker-Regular",
        "SpecialElite-Regular",
        "VT323-Regular",
        "Jost-Light",
        "Jost-Medium",
        "Jost-Bold",
    ]

    enum JostWeight {
        case light
        case medium
        case bold

        var postScriptName: String {
            switch self {
            case .light: "Jost-Light"
            case .medium: "Jost-Medium"
            case .bold: "Jost-Bold"
            }
        }
    }

    /// Pochoir : noms peints sur la cloison, plaques des boîtiers.
    static func stencil(_ size: CGFloat) -> Font {
        .custom("BlackOpsOne-Regular", fixedSize: size)
    }

    /// Marqueur sur le scotch de masquage.
    static func marker(_ size: CGFloat) -> Font {
        .custom("PermanentMarker-Regular", fixedSize: size)
    }

    /// Machine à écrire du journal de bord.
    static func typewriter(_ size: CGFloat) -> Font {
        .custom("SpecialElite-Regular", fixedSize: size)
    }

    /// Texte vert des écrans cathodiques.
    static func screen(_ size: CGFloat) -> Font {
        .custom("VT323-Regular", fixedSize: size)
    }

    /// Gravures, étiquettes et chiffres.
    static func jost(_ size: CGFloat, weight: JostWeight = .medium) -> Font {
        .custom(weight.postScriptName, fixedSize: size)
    }

    /// Rend les polices du bundle utilisables par ce processus. Renvoie celles qui n'ont pas pu l'être.
    @discardableResult
    static func registerBundledFonts(in bundle: Bundle = .main) -> [String] {
        bundledFonts.filter { name in
            guard let url = bundle.url(forResource: name, withExtension: "ttf") else { return true }
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                return false
            }
            // Déjà enregistrée (second appel, tests) : ce n'est pas un échec.
            guard let failure = error?.takeRetainedValue() else { return true }
            return CFErrorGetCode(failure) != CTFontManagerError.alreadyRegistered.rawValue
        }
    }
}

/// Images du décor exportées de la maquette (sources dans Design/Decor, script scripts/export-decor.cjs).
enum DecorImage: String, CaseIterable, Sendable {
    case bulkhead = "Bulkhead"
    case wood = "Wood"
    case crinkle = "Crinkle"
    case paper = "Paper"
    case grain = "Grain"
    case pirateFlag = "PirateFlag"

    var image: Image {
        Image(rawValue)
    }
}
