import Foundation

/// Canal (ou paire de canaux) du micro à utiliser, indexé à partir de 0.
enum InputChannelSelection: Codable, Hashable, Sendable {
    case mono(Int)
    case stereo(first: Int)

    var channels: [Int] {
        switch self {
        case .mono(let channel): [channel]
        case .stereo(let first): [first, first + 1]
        }
    }

    func isValid(forChannelCount count: Int) -> Bool {
        channels.allSatisfy { (0..<count).contains($0) }
    }

    /// Choix proposés pour un périphérique : chaque canal seul, puis chaque paire stéréo (1-2, 3-4…).
    static func options(forChannelCount count: Int) -> [InputChannelSelection] {
        guard count > 0 else { return [.mono(0)] }
        let monoOptions = (0..<count).map { InputChannelSelection.mono($0) }
        let stereoOptions = stride(from: 0, to: count - 1, by: 2).map { InputChannelSelection.stereo(first: $0) }
        return monoOptions + stereoOptions
    }

    /// Libellé affiché, avec les noms de canaux fournis par le pilote quand ils existent.
    func label(on device: AudioDevice?) -> String {
        switch self {
        case .mono(let channel):
            device?.inputChannelLabel(channel) ?? String(localized: "Entrée \(channel + 1)")
        case .stereo(let first):
            String(localized: "Entrées \(first + 1)-\(first + 2) (stéréo)")
        }
    }
}

/// Choix de périphériques : en cours d'édition dans l'écran de préparation, ou mémorisé de la dernière session.
/// Seuls les UID sont stockés : ils restent stables d'un branchement à l'autre.
struct DeviceSelection: Codable, Hashable, Sendable {
    var inputUID: String?
    var inputChannels: InputChannelSelection = .mono(0)
    var mainOutputUID: String?
    var monitorOutputUID: String?
    var bufferFrameSize: UInt32 = BufferSizePolicy.defaultSize

    func uid(for role: DeviceRole) -> String? {
        switch role {
        case .microphone: inputUID
        case .mainOutput: mainOutputUID
        case .monitorOutput: monitorOutputUID
        }
    }
}
