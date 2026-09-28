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
}

/// Niveau du micro choisi, pour l'œil magique.
@MainActor
protocol InputLevelMonitoring: AnyObject {
    /// Niveau lissé, de 0 (silence) à 1 (voix forte).
    var level: Double { get }
    var status: InputLevelStatus { get }
    func start(deviceUID: String, channels: InputChannelSelection)
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

    func start(deviceUID: String, channels: InputChannelSelection) {
        startTask?.cancel()
        pollTask?.cancel()
        status = .starting
        let source = self.source
        startTask = Task { [weak self] in
            guard await MicrophoneAccess.request() else {
                if !Task.isCancelled { self?.status = .denied }
                return
            }
            guard !Task.isCancelled else { return }
            do {
                try await source.start(deviceUID: deviceUID, channels: channels.channels)
            } catch {
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
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let target = LevelMeterMath.normalized(decibels: self.source.decibels)
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
    func start(deviceUID: String, channels: InputChannelSelection) {}
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

/// Session AVCapture qui lit le niveau des canaux d'un micro.
/// Tout se passe sur une file série privée ; le dernier niveau est partagé sous verrou
/// (ce n'est pas un fil temps réel : le verrou y est permis).
final class CaptureLevelSource: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    enum Failure: Error {
        case deviceNotFound
        case cannotAttachInput
        case cannotAttachOutput
    }

    private struct Reading: Sendable {
        var channels: [Int] = [0]
        var decibels: Float = LevelMeterMath.silence
    }

    private let queue = DispatchQueue(label: "com.skemedia.RadioMoustache.level-meter")
    /// Manipulée uniquement sur `queue`.
    private var session: AVCaptureSession?
    private let reading = OSAllocatedUnfairLock(initialState: Reading())

    /// Dernier niveau mesuré, en dBFS.
    var decibels: Float {
        reading.withLock { $0.decibels }
    }

    func start(deviceUID: String, channels: [Int]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            queue.async {
                do {
                    try self.run(deviceUID: deviceUID, channels: channels)
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
                self.reading.withLock { $0.decibels = LevelMeterMath.silence }
                continuation.resume()
            }
        }
    }

    private func run(deviceUID: String, channels: [Int]) throws {
        session?.stopRunning()
        session = nil
        // Sur macOS, l'identifiant AVCapture d'un micro est son UID Core Audio.
        guard let device = AVCaptureDevice(uniqueID: deviceUID) else { throw Failure.deviceNotFound }
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

        reading.withLock { $0 = Reading(channels: channels, decibels: LevelMeterMath.silence) }
        session.startRunning()
        self.session = session
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let levels = connection.audioChannels.map(\.averagePowerLevel)
        reading.withLock { reading in
            reading.decibels = LevelMeterMath.level(of: levels, channels: reading.channels)
        }
    }
}
