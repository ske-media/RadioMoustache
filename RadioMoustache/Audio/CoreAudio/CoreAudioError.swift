import CoreAudio
import Foundation

/// Erreur renvoyée par une fonction du HAL Core Audio.
struct CoreAudioError: Error, Equatable, CustomStringConvertible {
    let status: OSStatus
    let operation: String

    var description: String {
        "\(operation) : erreur Core Audio \(status.fourCharCodeDescription)"
    }

    /// Lève une erreur si `status` signale un échec.
    static func check(_ status: OSStatus, _ operation: @autoclosure () -> String) throws {
        guard status == kAudioHardwareNoError else {
            throw CoreAudioError(status: status, operation: operation())
        }
    }
}

extension OSStatus {
    /// Code lisible : 'what' pour les codes à quatre caractères, sinon la valeur numérique.
    var fourCharCodeDescription: String {
        UInt32(bitPattern: self).fourCharCodeDescription ?? String(self)
    }
}

extension UInt32 {
    /// Représentation 'abcd' si les quatre octets sont des caractères ASCII imprimables.
    var fourCharCodeDescription: String? {
        let bytes = [
            UInt8(truncatingIfNeeded: self >> 24),
            UInt8(truncatingIfNeeded: self >> 16),
            UInt8(truncatingIfNeeded: self >> 8),
            UInt8(truncatingIfNeeded: self),
        ]
        guard bytes.allSatisfy({ (0x20...0x7E).contains($0) }) else { return nil }
        return "'" + String(decoding: bytes, as: UTF8.self) + "'"
    }
}
