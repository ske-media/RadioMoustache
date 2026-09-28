import AVFoundation
import os

/// Sortie à tester depuis l'écran de préparation.
enum TestTarget: Hashable, Sendable {
    case mainOutput
    case monitorOutput

    var role: DeviceRole {
        switch self {
        case .mainOutput: .mainOutput
        case .monitorOutput: .monitorOutput
        }
    }

    /// Phrase dite par la voix du Mac avant le bip.
    var announcement: String {
        switch self {
        case .mainOutput: String(localized: "Essai enceinte, un, deux.")
        case .monitorOutput: String(localized: "Essai casque, un, deux.")
        }
    }
}

enum TestSignalError: Error {
    case playbackFailed
}

/// Joue le son d'essai (voix + bip) sur une sortie précise.
@MainActor
protocol TestSignalPlaying: AnyObject {
    /// Lance le son d'essai et renvoie sa durée.
    func play(_ target: TestTarget, onDeviceUID uid: String) async throws -> Duration
    func stop()
}

/// Son d'essai : la voix française du Mac annonce la sortie, puis un bip de 1 kHz.
@MainActor
final class TestSignalPlayer: TestSignalPlaying {
    private var clips: [TestTarget: Data] = [:]
    private var player: AVAudioPlayer?
    private let speech = SpeechRenderer()

    func play(_ target: TestTarget, onDeviceUID uid: String) async throws -> Duration {
        let data = await clip(for: target)
        player?.stop()
        let player = try AVAudioPlayer(data: data)
        // La sortie est imposée : on n'utilise jamais la sortie par défaut du système.
        player.currentDevice = uid
        player.prepareToPlay()
        guard player.play() else { throw TestSignalError.playbackFailed }
        self.player = player
        return .milliseconds(Int((player.duration * 1000).rounded()))
    }

    func stop() {
        player?.stop()
        player = nil
    }

    private func clip(for target: TestTarget) async -> Data {
        if let cached = clips[target] {
            return cached
        }
        let voice = await speech.render(target.announcement)
        let sampleRate = voice?.sampleRate ?? SoundSynth.sampleRate
        var samples = voice.map { SoundSynth.normalized($0.samples, peak: 0.8) } ?? []
        if !samples.isEmpty {
            samples += [Float](repeating: 0, count: Int(0.25 * sampleRate))
        }
        samples += SoundSynth.testBeep(sampleRate: sampleRate)
        let data = WAVEncoder.encode(samples: samples, sampleRate: Int(sampleRate))
        clips[target] = data
        return data
    }
}

/// Aucun son d'essai (app lancée comme hôte des tests).
@MainActor
final class SilentTestSignals: TestSignalPlaying {
    func play(_ target: TestTarget, onDeviceUID uid: String) async throws -> Duration { .zero }
    func stop() {}
}

/// Son produit par la synthèse vocale : échantillons mono et leur fréquence.
struct SpeechRendering: Sendable {
    let samples: [Float]
    let sampleRate: Double
}

/// Fait dire une phrase à la voix française du Mac et récupère le son, sans le jouer.
@MainActor
final class SpeechRenderer {
    /// Gardé en vie pendant la synthèse.
    private var synthesizer: AVSpeechSynthesizer?

    func render(_ text: String, language: String = "fr-FR", timeout: Duration = .seconds(8)) async -> SpeechRendering? {
        let synthesizer = AVSpeechSynthesizer()
        self.synthesizer = synthesizer
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)

        let collector = SpeechCollector()
        let rendering = await withCheckedContinuation { (continuation: CheckedContinuation<SpeechRendering?, Never>) in
            collector.setContinuation(continuation)
            // Appelé sur un fil quelconque : la fermeture n'est isolée à aucun acteur.
            synthesizer.write(utterance) { @Sendable buffer in
                collector.append(buffer)
            }
            Task {
                try? await Task.sleep(for: timeout)
                collector.finish()
            }
        }
        self.synthesizer = nil
        return rendering
    }
}

/// Accumule les tampons de la synthèse vocale (appelé depuis le fil de la synthèse).
final class SpeechCollector: Sendable {
    private struct State: Sendable {
        var samples: [Float] = []
        var sampleRate: Double = 0
        var continuation: CheckedContinuation<SpeechRendering?, Never>?
        var isFinished = false
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    func setContinuation(_ continuation: CheckedContinuation<SpeechRendering?, Never>) {
        state.withLock { $0.continuation = continuation }
    }

    func append(_ buffer: AVAudioBuffer) {
        guard let pcm = buffer as? AVAudioPCMBuffer else { return }
        // Un tampon vide marque la fin de la phrase.
        guard pcm.frameLength > 0 else {
            finish()
            return
        }
        let samples = Self.firstChannel(of: pcm)
        let sampleRate = pcm.format.sampleRate
        state.withLock { state in
            guard !state.isFinished else { return }
            state.samples += samples
            state.sampleRate = sampleRate
        }
    }

    func finish() {
        let result = state.withLock { state -> (CheckedContinuation<SpeechRendering?, Never>, SpeechRendering?)? in
            guard !state.isFinished, let continuation = state.continuation else { return nil }
            state.isFinished = true
            state.continuation = nil
            let rendering = state.samples.isEmpty || state.sampleRate <= 0
                ? nil
                : SpeechRendering(samples: state.samples, sampleRate: state.sampleRate)
            return (continuation, rendering)
        }
        guard let (continuation, rendering) = result else { return }
        continuation.resume(returning: rendering)
    }

    /// Premier canal du tampon, en flottants (-1…1), quel que soit son format.
    static func firstChannel(of buffer: AVAudioPCMBuffer) -> [Float] {
        let count = Int(buffer.frameLength)
        if let channel = buffer.floatChannelData?[0] {
            let stride = buffer.stride
            return (0..<count).map { channel[$0 * stride] }
        }
        if let channel = buffer.int16ChannelData?[0] {
            let stride = buffer.stride
            return (0..<count).map { Float(channel[$0 * stride]) / Float(Int16.max) }
        }
        if let channel = buffer.int32ChannelData?[0] {
            let stride = buffer.stride
            return (0..<count).map { Float(channel[$0 * stride]) / Float(Int32.max) }
        }
        return []
    }
}
