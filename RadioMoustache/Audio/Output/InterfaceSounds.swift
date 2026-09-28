import AVFoundation

/// Bruitages de l'interface (fabriqués par `SoundSynth`).
enum InterfaceSound: CaseIterable, Sendable {
    case lever
    case sparks
    case crtPowerOn
    case typewriterTick
    case menuBlip
    case goLive
}

/// Joue les bruitages de l'interface, jamais sur l'enceinte ni à l'antenne.
@MainActor
protocol InterfaceSoundPlaying: AnyObject {
    /// Sortie où jouer les bruitages (`nil` : silence).
    func route(toDeviceUID uid: String?)
    func play(_ sound: InterfaceSound)
}

/// Choix de la sortie des bruitages : les haut-parleurs intégrés du Mac, sinon le casque de retour.
/// Jamais la sortie principale (l'enceinte du public).
enum InterfaceSoundRouting {
    static func deviceUID(outputs: [AudioDevice], mainOutputUID: String?, monitorOutputUID: String?) -> String? {
        if let builtIn = outputs.first(where: { $0.transport == .builtIn && $0.uid != mainOutputUID }) {
            return builtIn.uid
        }
        if let monitorOutputUID, monitorOutputUID != mainOutputUID,
           outputs.contains(where: { $0.uid == monitorOutputUID }) {
            return monitorOutputUID
        }
        return nil
    }
}

/// Lecteur des bruitages sur un périphérique précis (`AVAudioPlayer.currentDevice`).
@MainActor
final class InterfaceSoundPlayer: InterfaceSoundPlaying {
    private var players: [InterfaceSound: AVAudioPlayer] = [:]
    private var deviceUID: String?
    private let volume: Float

    init(volume: Float = 0.6) {
        self.volume = volume
        for sound in InterfaceSound.allCases {
            let data = WAVEncoder.encode(samples: SoundSynth.samples(for: sound), sampleRate: Int(SoundSynth.sampleRate))
            guard let player = try? AVAudioPlayer(data: data) else { continue }
            player.volume = volume
            players[sound] = player
        }
    }

    func route(toDeviceUID uid: String?) {
        guard uid != deviceUID else { return }
        deviceUID = uid
        for player in players.values {
            player.stop()
            // Sans sortie autorisée, on ne touche pas au lecteur : il ne jouera plus.
            if let uid {
                player.currentDevice = uid
                player.prepareToPlay()
            }
        }
    }

    func play(_ sound: InterfaceSound) {
        // Jamais sur la sortie par défaut du système : ce pourrait être l'enceinte.
        guard let deviceUID, let player = players[sound] else { return }
        if player.currentDevice != deviceUID {
            player.currentDevice = deviceUID
        }
        player.currentTime = 0
        player.play()
    }
}

/// Aucun bruitage (app lancée comme hôte des tests).
@MainActor
final class SilentInterfaceSounds: InterfaceSoundPlaying {
    func route(toDeviceUID uid: String?) {}
    func play(_ sound: InterfaceSound) {}
}
