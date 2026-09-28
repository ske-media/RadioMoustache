import AVFoundation
import Observation
import os

/// État de la mesure du niveau micro.
enum InputLevelStatus: Equatable, Sendable {
    case stopped
    case starting
    case running
    /// L'accès au micro a été refusé dans Réglages Système.
    case denied
    /// Le micro n'a pas pu être ouvert (débranché, occupé…).
    case unavailable
    /// Le micro est ouvert, mais aucun son n'en arrive.
    case noSignal
    /// Le micro n'envoie que des zéros parfaits : il est coupé (autorisation, bouton muet…).
    case muted
}

/// Niveau du micro choisi, pour l'œil magique.
@MainActor
protocol InputLevelMonitoring: AnyObject {
    /// Niveau lissé, de 0 (silence) à 1 (voix forte).
    var level: Double { get }
    var status: InputLevelStatus { get }
    func start(deviceUID: String, deviceName: String, channels: InputChannelSelection)
    func stop()
}

/// Mesure le niveau d'un micro précis avec AVCapture, hors du temps réel (l'œil magique n'a besoin
/// que d'une trentaine de valeurs par seconde). Le moteur temps réel de l'étape 3 prendra le relais.
@MainActor
@Observable
final class InputLevelMonitor: InputLevelMonitoring {
    private(set) var level: Double = 0
    private(set) var status: InputLevelStatus = .stopped

    @ObservationIgnored private let source = CaptureLevelSource()
    @ObservationIgnored private var startTask: Task<Void, Never>?
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var ballistics = LevelBallistics()

    func start(deviceUID: String, deviceName: String, channels: InputChannelSelection) {
        startTask?.cancel()
        pollTask?.cancel()
        status = .starting
        let source = self.source
        startTask = Task { [weak self] in
            guard await MicrophoneAccess.request() else {
                CaptureLevelSource.logger.error("Accès au micro refusé")
                if !Task.isCancelled { self?.status = .denied }
                return
            }
            guard !Task.isCancelled else { return }
            do {
                try await source.start(deviceUID: deviceUID, deviceName: deviceName, channels: channels.channels)
            } catch {
                CaptureLevelSource.logger.error("Micro impossible à ouvrir : \(String(describing: error), privacy: .public)")
                if !Task.isCancelled { self?.status = .unavailable }
                return
            }
            guard !Task.isCancelled, let self else { return }
            self.status = .running
            self.startPolling()
        }
    }

    func stop() {
        startTask?.cancel()
        startTask = nil
        pollTask?.cancel()
        pollTask = nil
        status = .stopped
        level = 0
        ballistics.reset()
        let source = self.source
        Task { await source.stop() }
    }

    private func startPolling() {
        pollTask?.cancel()
        let startedAt = ProcessInfo.processInfo.systemUptime
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let now = ProcessInfo.processInfo.systemUptime
                let report = self.source.report(at: now)
                let status = InputLevelDiagnosis.status(
                    secondsSinceLastBuffer: report.secondsSinceLastBuffer,
                    digitalSilenceDuration: report.digitalSilenceDuration,
                    runningFor: now - startedAt
                )
                // L'état n'est republié que s'il change : l'écran vert ne se redessine pas 30 fois par seconde.
                if status != self.status {
                    self.status = status
                }
                let target = status == .running ? LevelMeterMath.normalized(decibels: report.decibels) : 0
                self.level = self.ballistics.next(toward: target)
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }
}

/// Mesure muette (app lancée comme hôte des tests).
@MainActor
final class SilentLevelMonitor: InputLevelMonitoring {
    private(set) var level: Double = 0
    private(set) var status: InputLevelStatus = .stopped
    func start(deviceUID: String, deviceName: String, channels: InputChannelSelection) {}
    func stop() {}
}

/// Autorisation d'accès au micro (demandée une seule fois par macOS).
enum MicrophoneAccess {
    static func request() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }
}

/// Session AVCapture qui mesure la crête de chaque canal d'un micro.
/// Tout se passe sur une file série privée ; la dernière mesure est partagée sous verrou
/// (ce n'est pas un fil temps réel : le verrou y est permis).
final class CaptureLevelSource: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    enum Failure: Error {
        case deviceNotFound(uid: String, name: String)
        case cannotAttachInput
        case cannotAttachOutput
    }

    /// Dernière mesure, vue depuis l'interface.
    struct Report: Sendable {
        var decibels: Float
        /// Secondes depuis le dernier tampon reçu (`nil` : aucun tampon encore).
        var secondsSinceLastBuffer: Double?
        /// Depuis combien de secondes le micro n'envoie que des zéros (`nil` : il envoie du son).
        var digitalSilenceDuration: Double?
    }

    private struct Reading: Sendable {
        var channels: [Int] = [0]
        var decibels: Float = LevelMeterMath.silence
        var lastBuffer: Double?
        var silentSince: Double?
    }

    /// Journal visible dans la console d'Xcode (catégorie « oeil-magique »).
    static let logger = Logger(subsystem: "com.skemedia.RadioMoustache", category: "oeil-magique")

    private let queue = DispatchQueue(label: "com.skemedia.RadioMoustache.level-meter")
    /// Manipulées uniquement sur `queue`.
    private var session: AVCaptureSession?
    private var hasLoggedFormat = false
    private let reading = OSAllocatedUnfairLock(initialState: Reading())

    func report(at now: Double) -> Report {
        reading.withLock { reading in
            Report(
                decibels: reading.decibels,
                secondsSinceLastBuffer: reading.lastBuffer.map { now - $0 },
                digitalSilenceDuration: reading.silentSince.map { now - $0 }
            )
        }
    }

    func start(deviceUID: String, deviceName: String, channels: [Int]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            queue.async {
                do {
                    try self.run(deviceUID: deviceUID, deviceName: deviceName, channels: channels)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                self.session?.stopRunning()
                self.session = nil
                self.reading.withLock { $0 = Reading() }
                continuation.resume()
            }
        }
    }

    private func run(deviceUID: String, deviceName: String, channels: [Int]) throws {
        session?.stopRunning()
        session = nil
        guard let device = Self.captureDevice(uid: deviceUID, name: deviceName) else {
            throw Failure.deviceNotFound(uid: deviceUID, name: deviceName)
        }
        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: queue)

        let session = AVCaptureSession()
        session.beginConfiguration()
        guard session.canAddInput(input) else { throw Failure.cannotAttachInput }
        session.addInput(input)
        guard session.canAddOutput(output) else { throw Failure.cannotAttachOutput }
        session.addOutput(output)
        session.commitConfiguration()

        reading.withLock { $0 = Reading(channels: channels) }
        hasLoggedFormat = false
        session.startRunning()
        self.session = session
        Self.logger.info("Micro ouvert : \(device.localizedName, privacy: .public), canaux \(channels, privacy: .public)")
    }

    /// Sur macOS, l'identifiant AVCapture d'un micro est normalement son UID Core Audio ;
    /// à défaut, on le cherche par son nom.
    private static func captureDevice(uid: String, name: String) -> AVCaptureDevice? {
        if let device = AVCaptureDevice(uniqueID: uid) {
            return device
        }
        let discovered = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        ).devices
        let known = discovered.map { "\($0.localizedName) [\($0.uniqueID)]" }.joined(separator: ", ")
        logger.warning("UID \(uid, privacy: .public) inconnu d'AVCapture ; micros vus : \(known, privacy: .public)")
        return discovered.first { $0.localizedName == name }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = ProcessInfo.processInfo.systemUptime
        let measured = Self.peakDecibels(of: sampleBuffer)
        // Repli : les niveaux calculés par AVCapture, si le format du tampon n'est pas lisible.
        let levels = measured ?? connection.audioChannels.map(\.averagePowerLevel)
        let isDigitalSilence = measured.map { peaks in peaks.allSatisfy { $0 <= LevelMeterMath.silence } } ?? false
        if !hasLoggedFormat {
            hasLoggedFormat = true
            let description = CMSampleBufferGetFormatDescription(sampleBuffer)
            let format = description.map { AVAudioFormat(cmAudioFormatDescription: $0) }
            Self.logger.info("Premier son reçu : \(format?.description ?? "format inconnu", privacy: .public), niveaux \(levels, privacy: .public)")
        }
        reading.withLock { reading in
            reading.lastBuffer = now
            reading.decibels = LevelMeterMath.level(of: levels, channels: reading.channels)
            if isDigitalSilence {
                if reading.silentSince == nil { reading.silentSince = now }
            } else {
                reading.silentSince = nil
            }
        }
    }

    /// Crête de chaque canal d'un tampon AVCapture, en dBFS (`nil` si le format n'est pas du PCM lisible).
    static func peakDecibels(of sampleBuffer: CMSampleBuffer) -> [Float]? {
        guard let description = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }
        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard frameCount > 0 else { return nil }
        let format = AVAudioFormat(cmAudioFormatDescription: description)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(frameCount),
            into: buffer.mutableAudioBufferList
        )
        guard status == noErr else { return nil }
        return LevelMeterMath.peakDecibels(of: buffer)
    }
}
