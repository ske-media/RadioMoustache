import Foundation
import Observation

/// Services audio de l'écran de préparation : réels dans l'app, muets quand l'app sert d'hôte aux tests.
@MainActor
struct SetupServices {
    var meter: any InputLevelMonitoring
    var sounds: any InterfaceSoundPlaying
    var testSignals: any TestSignalPlaying

    static func live() -> SetupServices {
        SetupServices(meter: InputLevelMonitor(), sounds: InterfaceSoundPlayer(), testSignals: TestSignalPlayer())
    }

    static func silent() -> SetupServices {
        SetupServices(meter: SilentLevelMonitor(), sounds: SilentInterfaceSounds(), testSignals: SilentTestSignals())
    }
}

/// Déroulé de l'écran « Préparation de l'émission » : le moniteur s'allume tout seul, puis pose ses questions
/// dans l'ordre (micro, enceinte, casque) avant le récapitulatif et « Paré à émettre ». Chaque étape a son outil :
/// niveau du micro, son d'essai de la sortie. La vue affiche cet état et relaie clics et touches.
@MainActor
@Observable
final class SetupFlow {
    enum Power: Equatable, Sendable {
        case off
        case booting
        case ready
    }

    /// Rythme de la séquence de démarrage.
    struct Timing: Sendable {
        /// Du clac du levier au ronflement du moniteur.
        var humDelay: Duration
        /// Du ronflement à la première ligne.
        var firstLineDelay: Duration
        var lineInterval: Duration
        /// Pause après la dernière ligne, avant la première étape.
        var readyDelay: Duration

        /// Moins de 2 secondes : le moniteur s'allume tout seul à chaque lancement.
        static let standard = Timing(
            humDelay: .milliseconds(150),
            firstLineDelay: .milliseconds(350),
            lineInterval: .milliseconds(170),
            readyDelay: .milliseconds(250)
        )
        static let instant = Timing(humDelay: .zero, firstLineDelay: .zero, lineInterval: .zero, readyDelay: .zero)
    }

    private struct MeterTarget: Equatable {
        let uid: String
        let name: String
        let channels: InputChannelSelection
    }

    /// Nombre de lignes de messages sous la liste.
    static let statusCapacity = 2

    // MARK: - État affiché

    private(set) var power: Power = .off
    private(set) var bootLines: [String] = []
    private(set) var visibleBootLineCount = 0
    /// Augmente à chaque mise sous tension : relance les étincelles et l'allumage du tube.
    private(set) var powerOnCount = 0
    /// Étape affichée par le moniteur.
    private(set) var step: SetupStep = .microphone
    /// Étape la plus avancée déjà atteinte : les onglets suivants restent éteints.
    private(set) var furthestStep: SetupStep = .microphone
    /// Réglage avancé ouvert par-dessus l'étape (canal d'entrée ou latence).
    private(set) var advancedList: SetupList?
    /// Sortie en cours d'essai.
    private(set) var testingTarget: TestTarget?
    private(set) var testMessage: String?
    private(set) var alertMessage: String?
    /// Session validée par « Paré à émettre » : l'app passe alors dans la cabine.
    private(set) var confirmedSession: SessionConfiguration?
    /// Matériel de la dernière émission, retrouvé au lancement (l'écran s'ouvre alors sur le récapitulatif).
    private var restoredSelection: DeviceSelection?

    let audio: AudioManager
    let meter: any InputLevelMonitoring
    private let sounds: any InterfaceSoundPlaying
    private let testSignals: any TestSignalPlaying
    private let timing: Timing

    @ObservationIgnored private var bootTask: Task<Void, Never>?
    @ObservationIgnored private var testTask: Task<Void, Never>?
    @ObservationIgnored private var meterTarget: MeterTarget?
    @ObservationIgnored private var hasStartedAutomatically = false
    @ObservationIgnored private var hasOpenedFirstStep = false

    init(audio: AudioManager, services: SetupServices, timing: Timing = .standard) {
        self.audio = audio
        self.meter = services.meter
        self.sounds = services.sounds
        self.testSignals = services.testSignals
        self.timing = timing
    }

    // MARK: - Informations dérivées

    var isOn: Bool { power != .off }

    /// Liste affichée : le réglage avancé ouvert, sinon les appareils de l'étape.
    var visibleList: SetupList? {
        advancedList ?? step.list
    }

    var options: [SetupOption] {
        visibleList.map { SetupContent.options(for: $0, audio: audio) } ?? []
    }

    var question: String {
        if let advancedList {
            return advancedList.question
        }
        if step == .review, isSameAsLastTime {
            return String(localized: "MÊME MATÉRIEL QUE LA DERNIÈRE FOIS ?")
        }
        return step.question
    }

    /// Vrai tant que la sélection est celle de la dernière émission, retrouvée au lancement.
    var isSameAsLastTime: Bool {
        restoredSelection != nil && restoredSelection == audio.selection
    }

    var recapLines: [SetupRecapLine] {
        SetupContent.recapLines(for: audio)
    }

    /// Réglage avancé proposé à l'étape affichée : le canal si le micro a plusieurs entrées,
    /// la latence au récapitulatif.
    var availableAdvancedList: SetupList? {
        switch step {
        case .microphone:
            return audio.inputChannelOptions.count > 1 ? .channel : nil
        case .review:
            return .latency
        case .mainOutput, .monitorOutput:
            return nil
        }
    }

    /// Premier problème qui empêche de quitter une étape.
    func blockingIssue(for step: SetupStep) -> SetupIssue? {
        audio.issues.first { $0.isBlocking && $0.step == step }
    }

    /// Onglet marqué « ! » : l'étape a un problème bloquant.
    func needsAttention(_ step: SetupStep) -> Bool {
        blockingIssue(for: step) != nil
    }

    /// Onglet cliquable : étape déjà atteinte.
    func isReachable(_ step: SetupStep) -> Bool {
        step <= furthestStep
    }

    var canGoNext: Bool {
        power == .ready && step.next != nil && blockingIssue(for: step) == nil
    }

    var canGoLive: Bool {
        power == .ready && audio.canConfirm
    }

    /// Alertes de l'étape affichée (toutes au récapitulatif), puis celle de l'œil magique.
    var warningLines: [String] {
        let issues = step == .review ? audio.issues : audio.issues.filter { $0.step == step }
        let meterLines = step == .microphone || step == .review ? [meterWarning].compactMap { $0 } : []
        return issues.map(\.screenMessage) + meterLines
    }

    /// Lignes sous la liste, au plus deux : refus, son d'essai, puis alertes de l'étape.
    var statusLines: [String] {
        let messages = [alertMessage, testMessage].compactMap { $0 }
        let warnings = warningLines.filter { !messages.contains($0) }
        let room = Self.statusCapacity - messages.count
        guard room > 0 else { return Array(messages.prefix(Self.statusCapacity)) }
        return messages + SetupContent.limited(warnings, to: room)
    }

    var meterWarning: String? {
        guard isOn else { return nil }
        switch meter.status {
        case .denied: return String(localized: "! MICRO REFUSÉ : AUTORISE-LE DANS RÉGLAGES SYSTÈME")
        case .unavailable: return String(localized: "! ŒIL MAGIQUE : MICRO INJOIGNABLE")
        case .noSignal: return String(localized: "! ŒIL MAGIQUE : RIEN NE VIENT DU MICRO")
        case .muted: return String(localized: "! MICRO MUET : VÉRIFIE L'AUTORISATION MICRO")
        case .stopped, .starting, .running: return nil
        }
    }

    /// Mot affiché après la barre de niveau de l'étape Micro.
    var levelHint: String {
        SetupContent.levelHint(level: meter.level, status: meter.status)
    }

    // MARK: - Secteur

    /// Allumage automatique, une seule fois par lancement, dès que le matériel est connu.
    func startAutomatically() {
        guard !hasStartedAutomatically, audio.hasLoadedDevices, power == .off else { return }
        syncWithHardware()
        powerOn()
    }

    func togglePower() {
        if power == .off {
            powerOn()
        } else {
            powerOff()
        }
    }

    func powerOn() {
        guard power == .off else { return }
        hasStartedAutomatically = true
        bootLines = BootScript.lines(deviceCount: audio.allDevices.count)
        visibleBootLineCount = 0
        alertMessage = nil
        testMessage = nil
        power = .booting
        powerOnCount += 1
        sounds.play(.lever)
        sounds.play(.sparks)
        syncMeter()

        bootTask?.cancel()
        let timing = self.timing
        bootTask = Task { [weak self] in
            try? await Task.sleep(for: timing.humDelay)
            guard !Task.isCancelled else { return }
            self?.sounds.play(.crtPowerOn)
            try? await Task.sleep(for: timing.firstLineDelay)
            let lineCount = self?.bootLines.count ?? 0
            for index in 0..<lineCount {
                guard !Task.isCancelled, let self else { return }
                self.visibleBootLineCount = index + 1
                self.sounds.play(.typewriterTick)
                try? await Task.sleep(for: timing.lineInterval)
            }
            try? await Task.sleep(for: timing.readyDelay)
            guard !Task.isCancelled else { return }
            self?.finishBoot()
        }
    }

    func powerOff() {
        guard power != .off else { return }
        bootTask?.cancel()
        bootTask = nil
        stopTest()
        power = .off
        visibleBootLineCount = 0
        advancedList = nil
        alertMessage = nil
        sounds.play(.lever)
        syncMeter()
    }

    /// Passe la séquence de démarrage (clic sur l'écran, Entrée).
    func skipBoot() {
        guard power == .booting else { return }
        bootTask?.cancel()
        bootTask = nil
        finishBoot()
    }

    private func finishBoot() {
        visibleBootLineCount = bootLines.count
        if !hasOpenedFirstStep {
            hasOpenedFirstStep = true
            openFirstStep()
        }
        power = .ready
    }

    /// Premier écran après l'allumage : le récapitulatif si tout le matériel de la dernière émission
    /// est là, sinon la première question. Ensuite, le moniteur rallumé reprend où il en était.
    private func openFirstStep() {
        if audio.lastSessionRestored, audio.canConfirm {
            restoredSelection = audio.selection
            step = .review
            furthestStep = .review
        } else {
            step = .microphone
            furthestStep = .microphone
        }
    }

    // MARK: - Étapes

    /// Clic sur un onglet ou une ligne du récapitulatif : seules les étapes déjà atteintes s'ouvrent.
    func goTo(_ target: SetupStep) {
        guard power == .ready, isReachable(target), target != step || advancedList != nil else { return }
        show(target)
    }

    /// « Suivant » : l'étape doit être réglée ; au récapitulatif, c'est « Paré à émettre ».
    func next() {
        guard power == .ready else { return }
        guard advancedList == nil else {
            closeAdvancedSettings()
            return
        }
        guard let following = step.next else {
            goLive()
            return
        }
        if let issue = blockingIssue(for: step) {
            alertMessage = issue.screenMessage
            sounds.play(.menuBlip)
            return
        }
        show(following)
    }

    /// « Retour » : étape précédente (ou fermeture des réglages avancés).
    @discardableResult
    func back() -> Bool {
        guard power == .ready else { return false }
        guard advancedList == nil else {
            closeAdvancedSettings()
            return true
        }
        guard let previous = step.previous else { return false }
        show(previous)
        return true
    }

    private func show(_ target: SetupStep) {
        stopTest()
        advancedList = nil
        alertMessage = nil
        step = target
        furthestStep = max(furthestStep, target)
        sounds.play(.menuBlip)
    }

    // MARK: - Choix

    /// Clic sur un appareil (ou un réglage) de la liste affichée : il est pris tout de suite.
    func choose(at index: Int) {
        let options = self.options
        guard power == .ready, options.indices.contains(index) else { return }
        apply(options[index], sound: .menuBlip)
    }

    /// Flèches ↑↓ : l'appareil voisin est pris tout de suite (le niveau et l'œil magique le suivent).
    func moveSelection(by delta: Int) {
        let options = self.options
        guard power == .ready, !options.isEmpty else { return }
        let current = options.firstIndex(where: \.isCurrent)
        let target = current.map { min(max($0 + delta, 0), options.count - 1) } ?? 0
        guard target != current else { return }
        apply(options[target], sound: .typewriterTick)
    }

    private func apply(_ option: SetupOption, sound: InterfaceSound) {
        if !option.isCurrent {
            // Le son d'essai visait l'appareil d'avant.
            stopTest()
            SetupContent.apply(option.choice, to: audio)
        }
        alertMessage = nil
        sounds.play(sound)
        syncWithHardware()
    }

    // MARK: - Réglages avancés

    /// « Réglages avancés » : le canal d'entrée (étape Micro) ou la latence (récapitulatif).
    func openAdvancedSettings() {
        guard power == .ready, advancedList == nil, let list = availableAdvancedList else { return }
        stopTest()
        alertMessage = nil
        advancedList = list
        sounds.play(.menuBlip)
    }

    func closeAdvancedSettings() {
        guard advancedList != nil else { return }
        advancedList = nil
        sounds.play(.menuBlip)
    }

    // MARK: - Sons d'essai

    /// Bouton « Essai » (ou Espace) des étapes Enceinte et Casque.
    func testCurrentOutput() {
        guard advancedList == nil, let target = step.testTarget else { return }
        test(target)
    }

    func test(_ target: TestTarget) {
        guard power == .ready else { return }
        guard let device = audio.selectedDevice(for: target.role) else {
            stopTest()
            if target == .monitorOutput, audio.selection.monitorOutputUID == nil {
                testMessage = String(localized: "» AUCUN CASQUE CHOISI")
            } else {
                testMessage = String(localized: "» SORTIE DÉBRANCHÉE : ESSAI IMPOSSIBLE")
            }
            return
        }
        let name = device.name.screenUppercased
        testingTarget = target
        testMessage = String(localized: "» ESSAI ENVOYÉ SUR \(name)")
        testTask?.cancel()
        let testSignals = self.testSignals
        testTask = Task { [weak self] in
            do {
                let duration = try await testSignals.play(target, onDeviceUID: device.uid)
                try? await Task.sleep(for: duration + .milliseconds(150))
            } catch {
                guard !Task.isCancelled else { return }
                self?.testMessage = String(localized: "» ESSAI IMPOSSIBLE SUR \(name)")
            }
            guard !Task.isCancelled, self?.testingTarget == target else { return }
            self?.testingTarget = nil
        }
    }

    /// Coupe le son d'essai en cours et efface son message.
    private func stopTest() {
        testTask?.cancel()
        testTask = nil
        if testingTarget != nil {
            testSignals.stop()
            testingTarget = nil
        }
        testMessage = nil
    }

    // MARK: - Validation

    /// « Paré à émettre » : mémorise la session et passe dans la cabine.
    func goLive() {
        guard power == .ready else { return }
        do {
            let session = try audio.confirmSession()
            advancedList = nil
            alertMessage = nil
            stopTest()
            testSignals.stop()
            sounds.play(.goLive)
            confirmedSession = session
            syncMeter()
        } catch {
            alertMessage = String(localized: "!! PAS ENCORE PARÉ : CORRIGE LES ALERTES")
            sounds.play(.menuBlip)
        }
    }

    /// Retour de la cabine : le secteur reste allumé, le moniteur rouvre le récapitulatif.
    func backToSetup() {
        guard confirmedSession != nil else { return }
        confirmedSession = nil
        step = .review
        furthestStep = .review
        syncWithHardware()
    }

    // MARK: - Clavier

    /// Touches : ↑↓ pour l'appareil, Entrée (ou →) pour avancer, Échap (ou ←) pour revenir,
    /// Espace pour l'essai de la sortie.
    @discardableResult
    func handle(_ key: SetupKey) -> Bool {
        switch power {
        case .off:
            guard key == .confirm || key == .space else { return false }
            powerOn()
            return true
        case .booting:
            guard key == .confirm || key == .space || key == .cancel else { return false }
            skipBoot()
            return true
        case .ready:
            return advancedList == nil ? handleStepKey(key) : handleAdvancedKey(key)
        }
    }

    private func handleStepKey(_ key: SetupKey) -> Bool {
        switch key {
        case .up, .down:
            guard step.list != nil else { return false }
            moveSelection(by: key == .up ? -1 : 1)
        case .confirm:
            next()
        case .right:
            // La flèche ne fait pas partir à l'antenne : seule Entrée valide le récapitulatif.
            guard step.next != nil else { return false }
            next()
        case .space:
            if step.testTarget != nil {
                testCurrentOutput()
            } else {
                next()
            }
        case .cancel, .left:
            return back()
        }
        return true
    }

    private func handleAdvancedKey(_ key: SetupKey) -> Bool {
        switch key {
        case .up:
            moveSelection(by: -1)
        case .down:
            moveSelection(by: 1)
        case .confirm, .space, .cancel, .left, .right:
            closeAdvancedSettings()
        }
        return true
    }

    // MARK: - Matériel

    /// À appeler quand le matériel ou la sélection change : les bruitages et l'œil magique suivent.
    func syncWithHardware() {
        sounds.route(toDeviceUID: InterfaceSoundRouting.deviceUID(
            outputs: audio.outputDevices,
            mainOutputUID: audio.selection.mainOutputUID,
            monitorOutputUID: audio.selection.monitorOutputUID
        ))
        syncMeter()
    }

    /// L'œil magique écoute le micro choisi tant que le secteur est allumé et qu'on est en préparation.
    private func syncMeter() {
        var wanted: MeterTarget?
        if isOn, confirmedSession == nil, let microphone = audio.selectedDevice(for: .microphone) {
            wanted = MeterTarget(uid: microphone.uid, name: microphone.name, channels: audio.selection.inputChannels)
        }
        guard wanted != meterTarget else { return }
        meterTarget = wanted
        if let wanted {
            meter.start(deviceUID: wanted.uid, deviceName: wanted.name, channels: wanted.channels)
        } else {
            meter.stop()
        }
    }
}
