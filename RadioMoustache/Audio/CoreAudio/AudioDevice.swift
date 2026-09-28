import CoreAudio
import Foundation

/// Instantané d'un périphérique audio tel que vu par le HAL.
///
/// `objectID` change à chaque reconnexion du périphérique : seul `uid` est stable
/// et peut être mémorisé d'une session à l'autre.
struct AudioDevice: Identifiable, Hashable, Sendable {
    let objectID: AudioObjectID
    let uid: String
    let name: String
    let manufacturer: String
    let transport: AudioTransport
    /// Nom de chaque canal d'entrée, `nil` quand le pilote n'en fournit pas.
    let inputChannelNames: [String?]
    let outputChannelCount: Int
    let nominalSampleRate: Double
    let bufferFrameSizeRange: ClosedRange<UInt32>?
    /// Latence propre du périphérique (pilote + marge de sécurité + flux), hors taille de buffer.
    let inputLatencyFrames: UInt32
    let outputLatencyFrames: UInt32
    let isAlive: Bool
    let isHidden: Bool

    /// Préfixe des UID des périphériques privés créés par l'app (agrégés de l'étape 3).
    static let privateUIDPrefix = "com.skemedia.RadioMoustache."

    var id: String { uid }
    var inputChannelCount: Int { inputChannelNames.count }
    var hasInput: Bool { inputChannelCount > 0 }
    var hasOutput: Bool { outputChannelCount > 0 }

    /// Vrai si le périphérique peut être proposé dans l'écran de préparation.
    var isSelectable: Bool {
        isAlive && !isHidden && !uid.hasPrefix(Self.privateUIDPrefix)
    }

    /// Latence estimée en millisecondes pour une taille de buffer donnée.
    func estimatedLatency(for role: DeviceRole, bufferFrameSize: UInt32) -> Double? {
        guard nominalSampleRate > 0 else { return nil }
        let deviceFrames = role == .microphone ? inputLatencyFrames : outputLatencyFrames
        return (Double(deviceFrames) + Double(bufferFrameSize)) / nominalSampleRate * 1000
    }

    /// Libellé d'un canal d'entrée, numéroté à partir de 1 comme sur les interfaces audio.
    func inputChannelLabel(_ index: Int) -> String {
        let number = index + 1
        if inputChannelNames.indices.contains(index), let name = inputChannelNames[index] {
            return String(localized: "Entrée \(number) · \(name)")
        }
        return String(localized: "Entrée \(number)")
    }

    /// Ordre d'affichage : alphabétique, insensible à la casse et aux accents.
    static func displayOrder(_ lhs: AudioDevice, _ rhs: AudioDevice) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
